# Gemini AI: Your Terminal Command Assistant

Gemini AI is a command-line tool that lets you quickly get answers and commands from the Gemini API right in your terminal. It's designed to be a fast, efficient helper for your daily tasks.  Gemini AI is geared toward linux/macOS systems administrator or elasticsearch related topics and outputs.

## Installation
To get Gemini AI up and running, you just need to download the script and make it executable:
```bash
# Download the script to your /usr/local/bin directory
sudo curl -L https://raw.githubusercontent.com/jlim0930/gemini-ai/main/gemini.sh -o /usr/local/bin/gemini

# Make the script executable
sudo chmod +x /usr/local/bin/gemini
```

You will need to set your GEMINI_API_KEY in your environment or set it in your ~/.env
```
GEMINI_API_KEY="xyz"
```

apikey can be collected from https://ai.google.dev/gemini-api/docs/api-key

## Setup Key Binding (optional)
For even quicker access, you can bind Gemini AI to a keyboard shortcut in your Zsh shell. This allows you to instantly send your current command or question to the Gemini API.

Add the following line to your ~/.zshrc file:
```bash
bindkey -s "\C-g" "\C-agemini \C-j"
```

## Usage
You have two main ways to use Gemini AI:

- With a Key Binding (if set up): Type your command or question directly in the terminal, then press Ctrl + g. This will send your input to the Gemini API, and the response will appear on the next line.
- Directly from the Command Line: Simply run gemini followed by your question or desired command:
```bash
~ gemini list use the container names of all containers
docker ps --format '{{.Names}}'

~ gemini create a logstash pipeline for syslog input and add a tag for environment to be PRODUCTION and output to stdout
input {
  syslog {
    port => 514
  }
}

filter {
  mutate {
    add_field => { "environment" => "PRODUCTION" }
  }
}

output {
  stdout {
    codec => rubydebug
  }
}
```
