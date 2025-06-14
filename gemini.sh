#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2155,SC2086

# command line howto similar to https://github.com/antonmedv/howto
# requires curl, jq, fzf
#
# Create ~/.env file with your GEMINI_API_KEY or make sure that GEMINI_API_KEY is set for your environment
# You can also add key binding bindkey -s "\C-g" "\C-agemini \C-j"
#
# --- Shellcheck Directives and Global Settings ---
set -o errexit
set -o nounset
# set -o xtrace

# --- Configuration ---
if [[ -f ~/.env ]]; then
    # shellcheck disable=SC1091
    source ~/.env
fi

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    echo "Error: GEMINI_API_KEY is not set. Please set it in your environment or in a .env file." >&2
    exit 1
fi

declare -r -a AVAILABLE_MODELS=(
    "gemini-2.0-flash"
    "gemini-1.5-pro-latest"
)
declare -r DEFAULT_MODEL="${AVAILABLE_MODELS[0]}"
declare -r DEFAULT_TEMPERATURE="0.1"
declare -r DEFAULT_TOP_P="0.95"
declare -r DEFAULT_TOP_K="40"
declare -r ADDITIONAL_PROMPT="You are a highly specialized technical assistant. Based on the user's question, determine if the request is for an Elasticsearch operation or a general command-line task for Linux/macOS.

Respond *only* with the appropriate solution:

* **For Elasticsearch operations:** Provide a well-formatted Elasticsearch API call or code snippet. Ensure it uses spaces and tabs for indentation without any line wrapping enforced by the AI. If newlines are structurally necessary (e.g., for JSON objects within the code block), represent them as '\\n' characters instead of actual newline characters. Do not include markdown.
* **For command-line tasks:** Provide a single, executable command-line instruction suitable for Linux/macOS, as a single, continuous string if possible, with only necessary newlines for structure. Do not include markdown, quotes, backticks, or any extraneous text.

Provide the most direct and complete answer without any conversational filler or explanation."

# --- ANSI Color Codes ---
declare -r RESET="\033[0m"
declare -r BOLD="\033[1m"
declare -r YELLOW="\033[33m"
declare -r RED="\033[31m"

# --- Functions ---

# Function to check for required commands
function check_commands() {
    local -a missing_cmds=()
    for cmd in "curl" "jq"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing_cmds+=("${cmd}")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        echo -e "${RED}Error:${RESET} The following required commands are not installed: ${BOLD}${missing_cmds[*]}${RESET}" >&2
        echo "Please install them to use this script." >&2
        return 1
    fi
    return 0
}

function print_help() {
    echo "Usage: $(basename "${0}") [--select-model] [--list-models] [options] [prompt]"
    echo "Options:"
    echo "  --list-models           Show all available Gemini models."
    echo "  --select-model          Select a model from the list (requires fzf or interactive prompt)."
    echo "  --temperature <value>   Set the generation temperature (0.0-2.0). Default: ${DEFAULT_TEMPERATURE}"
    echo "  --top-p <value>         Set the Top-P value (0.0-1.0). Default: ${DEFAULT_TOP_P}"
    echo "  --top-k <value>         Set the Top-K value (integer > 0). Default: ${DEFAULT_TOP_K}"
    echo "  --help                  Show this help message."
    echo ""
    echo "Examples:"
    echo "  $(basename "${0}") \"How to find large files in /var/log?\""
    echo "  $(basename "${0}") \"Write a Python class for a linked list.\""
    echo "  $(basename "${0}") \"Just a regular question.\" "
}

function list_models() {
    echo "Available models:"
    for model in "${AVAILABLE_MODELS[@]}"; do
        echo "  - ${model}"
    done
}

function ai() {
    local model_name="${DEFAULT_MODEL}"
    local prompt_text=""
    local select_model=0
    local temperature="${DEFAULT_TEMPERATURE}"
    local top_p="${DEFAULT_TOP_P}"
    local top_k="${DEFAULT_TOP_K}"

    # Parse arguments
    local args=("$@")
    local i=0
    while [[ ${i} -lt ${#args[@]} ]]; do
        local arg="${args[i]}"
        case "${arg}" in
            --help)
                print_help
                return 0
                ;;
            --list-models)
                list_models
                return 0
                ;;
            --select-model)
                select_model=1
                ((i++))
                ;;
            --temperature)
                if [[ -n "${args[i+1]:-}" && "${args[i+1]}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    temperature="${args[i+1]}"
                    i+=2
                else
                    echo -e "${RED}Error:${RESET} --temperature requires a numeric value (e.g., 0.2)." >&2
                    print_help
                    return 1
                fi
                ;;
            --top-p)
                if [[ -n "${args[i+1]:-}" && "${args[i+1]}" =~ ^0(\.[0-9]+)?$|^1(\.0)?$ ]]; then
                    top_p="${args[i+1]}"
                    i+=2
                else
                    echo -e "${RED}Error:${RESET} --top-p requires a numeric value between 0.0 and 1.0 (e.g., 0.8)." >&2
                    print_help
                    return 1
                fi
                ;;
            --top-k)
                if [[ -n "${args[i+1]:-}" && "${args[i+1]}" =~ ^[0-9]+$ ]]; then
                    top_k="${args[i+1]}"
                    i+=2
                else
                    echo -e "${RED}Error:${RESET} --top-k requires an integer value (e.g., 40)." >&2
                    print_help
                    return 1
                fi
                ;;
            --) # End of options
                ((i++))
                prompt_text="${args[*]:${i}}"
                break
                ;;
            *) # Positional arguments (prompt)
                if [[ -z "${prompt_text}" ]]; then
                    prompt_text="${arg}"
                else
                    prompt_text+=" ${arg}"
                fi
                ((i++))
                ;;
        esac
    done

    if [[ ${select_model} -eq 1 ]]; then
        if command -v fzf >/dev/null 2>&1; then
            model_name=$(printf "%s\n" "${AVAILABLE_MODELS[@]}" | fzf --prompt="Select Gemini model: " --height 10 --layout=reverse --no-info)
            if [[ -z "${model_name}" ]]; then
                echo -e "${YELLOW}No model selected. Exiting.${RESET}" >&2
                return 1
            fi
        else
            echo -e "${YELLOW}fzf not found. Falling back to basic selector.${RESET}" >&2
            PS3="Select Gemini model: "
            select m in "${AVAILABLE_MODELS[@]}"; do
                if [[ -n "${m}" ]]; then
                    model_name="${m}"
                    break
                else
                    echo -e "${RED}Invalid selection. Please try again.${RESET}" >&2
                fi
            done
            if [[ -z "${model_name}" ]]; then
                echo -e "${YELLOW}No model selected. Exiting.${RESET}" >&2
                return 1
            fi
        fi
    fi

    if [[ -z "${prompt_text}" ]]; then
        echo -e "${RED}Error:${RESET} No prompt provided." >&2
        print_help
        return 1
    fi

    local full_prompt="${ADDITIONAL_PROMPT} ${prompt_text}"

    local json_payload
    json_payload=$(jq -n \
        --arg content "${full_prompt}" \
        --argjson temperature_val "${temperature}" \
        --argjson top_p_val "${top_p}" \
        --argjson top_k_val "${top_k}" \
        '{
          "contents": [
            {
              "role": "user",
              "parts": [
                {
                  "text": $content
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": $temperature_val,
            "topP": $top_p_val,
            "topK": $top_k_val,
            "responseMimeType": "text/plain"
          }
        }')

    if [[ $? -ne 0 || -z "${json_payload}" ]]; then
        echo -e "${RED}Error:${RESET} Failed to construct JSON payload. Check prompt content or parameter values." >&2
        return 1
    fi

    local raw_ai_output
    # The jq -r '...' part extracts the raw text. If the AI followed the prompt,
    # any newlines within strings in JSON will be represented as literal '\n'
    raw_ai_output=$(curl --silent --no-buffer \
        --header 'Content-Type: application/json' \
        --data "${json_payload}" \
        --request POST \
        "https://generativelanguage.googleapis.com/v1beta/models/${model_name}:streamGenerateContent?alt=sse&key=${GEMINI_API_KEY}" |
        sed -u 's/^data: //' |
        jq -r 'select(.candidates) | .candidates[].content.parts[].text' | tr -d '\n')

    # --- Post-processing logic for output formatting ---
    local final_output

    final_output="${raw_ai_output}"
    # Now, specifically replace any literal '\n' (backslash followed by n) with a real newline.
    # This acts on whatever 'final_output' is, be it pretty-printed JSON or a command.
    # We need to escape the backslash twice for sed to interpret it literally.
    echo "${final_output}" | sed 's/\\n/\n/g'

    echo "" # Add a final newline for good measure
}

# Main execution
check_commands || exit 1
ai "$@"
