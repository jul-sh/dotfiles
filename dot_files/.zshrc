# Print a greeting message
echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

# Plugins
source "${HOME}/.zsh-plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
source "${HOME}/.zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# graceful dependency enforcement
# Usage: needs <executable> [provided by <packagename>]
# only redefines it here if it's not already defined
# >/dev/null declare -F needs || \
needs() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local bin=$1
  shift
  command -v "$bin" >/dev/null 2>&1 || { echo >&2 "I require $bin but it's not installed or in PATH; $*"; return 1; }
}

platform() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  local unameOut
  local machine
  unameOut="$(uname -s)"
  case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=macOS;;
    CYGWIN*)    machine=Cygwin;;
    MINGW*)     machine=MinGW;;
    *)          machine="${unameOut}"
  esac
  printf "%s" "$machine"
}

_generate_curl_api_request_for_please() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs jq
  local request args timeout model curl api_key
  curl=${CURL:-curl}
  model=${OPENAI_MODEL:-gpt-4-1106-preview}
  timeout=${OPENAI_TIMEOUT:-30}
  args="$@"
  args=$(printf "%b" "$args" | sed "s/'/'\\\\''/g")
  # This is just a narsty sed to escape single quotes.
  # (Piping to "jq -sRr '@json'" was not working correctly, so I had to take control of the escaping myself.)
  # printf "escaped args: %b\n" "$args" >&2

  # Check if API key file exists, if not ask for it and save it
  if [ -f "${HOME}/.openai_api_key" ]; then
    api_key=$(cat "${HOME}/.openai_api_key")
  else
    echo "OpenAI API key not found. Do you want to enter it? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Please enter your API key:"
        read -r api_key
        echo "$api_key" > "${HOME}/.openai_api_key"
    else
        echo "API key not entered. Some features may not work without it."
        return 1
    fi
  fi

  read -r -d '' request <<EOF
  $curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  --silent \
  --max-time $timeout \
  -d '{"model": "$model", "messages": [{"role": "user", "content": "$args"}], "temperature": 0.7}'
EOF
  printf "%b" "$request"
}

please() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs curl
  needs jq
  needs gum from https://github.com/charmbracelet/gum
  local request response response_parsed response_parsed_cleaned args
  local plat=$(platform)
  request=$(_generate_curl_api_request_for_please "What is the $plat bash command to $@? Only return the command to run itself, do not describe anything. Only use commands and executables that are common on most $plat systems. Do not quote the response and do not use markdown.")
# printf "request: %s\n" "$request" >&2
  response=$(eval "gum spin --show-output -s line --title \"Figuring out how to do this...\" -- $request")
# printf "response: %s\n" "$response" >&2
  response_parsed=$(printf "%s" "$response" | jq --raw-output '.choices[0].message.content')
# printf "response_parsed: %s\n" "$response_parsed" >&2
  if [[ "$response_parsed" == "null" || "$?" != "0" ]]; then
    printf "Error:\n" >&2
    printf "%b\n" "$response" >&2
    printf "%b\n" "$response_parsed"
  else
    response_parsed_cleaned=$(printf "%s" "$response_parsed" | sed -e 's/^[\\n]\+//' -e 's/^[\n]\+//')
    if gum confirm --affirmative="Run it" --negative="GTFO" "$response_parsed_cleaned"; then
      printf "\e[0;33m%s\n\e[m" "$response_parsed_cleaned" >&2
      printf "%s" "$response_parsed_cleaned" | bash
    else
      printf "%s" "Aborted."
      return 1
    fi
  fi
}

# Initialize starship prompt
eval "$(starship init zsh)"
