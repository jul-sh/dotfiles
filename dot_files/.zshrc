# Source .profile if it exists
if [ -f "${HOME}/.profile" ]; then
    source "${HOME}/.profile"
fi

# Source .local_profile if it exists
if [ -f "${HOME}/.local_profile" ]; then
    source "${HOME}/.local_profile"
fi

# Print a greeting message
echo -e "\e[3mHi girl, you're doing great this $(date +"%A"). —ฅ/ᐠ. ̫.ᐟ\ฅ—\e[0m"

persist() {
  if [[ "$1" == "-h" ]]; then
    echo "Usage: persist [options] command [arguments]"
    echo ""
    echo "Options:"
    echo "  -h        Display this help message"
    echo "  ls        List persisted commands and their status"
    echo "  view <timestamp>_<command_prefix>  View the output of a persisted command"
    echo ""
    echo "Examples:"
    echo "  persist sleep 60"
    echo "  persist ls"
    echo "  persist view 2023-10-27_10-30-00_sleep"
    return
  fi

  if [[ "$1" == "ls" ]]; then
    local history_file="$HOME/.persist_history"
    if [[ ! -f "$history_file" ]]; then
      echo "No persisted commands found."
      return
    fi
    while IFS= read -r line; do
      local timestamp=$(echo "$line" | cut -d ':' -f 1)
      local command_with_args=$(echo "$line" | cut -d ':' -f 2-)
      local command=$(echo "$command_with_args" | awk '{print $1}')
      local pid=$(pgrep -f "$command_with_args")
      if [[ -n "$pid" ]]; then
        echo "$timestamp: $command_with_args (Running, PID: $pid)"
      else
        echo "$timestamp: $command_with_args (Stopped)"
      fi
    done < "$history_file"
    return
  elif [[ "$1" == "view" ]]; then
      if [[ -z "$2" ]]; then
          echo "Usage: persist view <timestamp>_<command_prefix>"
          return
      fi
      local logfile="persist_$2.log"
      if [[ -f "$logfile" ]]; then
          cat "$logfile"
      else
          echo "Log file '$logfile' not found."
      fi
      return
  fi

  local command="$1"
  shift
  local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  local command_prefix=$(echo "$command" | cut -c 1-5) # Get first 5 chars
  local logfile="persist_${timestamp}_${command_prefix}.log"
  local history_file="$HOME/.persist_history"

  nohup "$command" "$@" > "$logfile" 2>&1 &

  echo "$timestamp: $command $@" >> "$history_file"

  echo "Command '$command $@' persisted in background. Output saved to '$logfile'."
  echo "History updated in '$history_file'."
}

alias persist="persist"

# Plugins
load_plugin() {
    local plugin_name="$1"
    local plugin_repo="$2"
    local plugin_commit="$3"
    local plugin_branch="$4"
    local plugin_dir="${HOME}/.zsh-plugins/${plugin_name}"

    if [ ! -d "${plugin_dir}" ]; then
        git clone --depth 1 --branch "${plugin_branch}" "${plugin_repo}" "${plugin_dir}"
        local current_commit=$(git -C "${plugin_dir}" rev-parse HEAD)
        if [ "${current_commit}" != "${plugin_commit}" ]; then
            echo "⚠️  Security Warning: The ${plugin_name} plugin from ${plugin_repo} (branch ${plugin_branch}) has an unexpected commit (${current_commit}) that does not match the expected commit (${plugin_commit}). For your safety, this plugin was not loaded, and the directory was removed to prevent potential remote code execution vulnerabilities."
            rm -rf "${plugin_dir}"
            return
        fi
    fi

    source "${plugin_dir}/${plugin_name}.plugin.zsh"
}

load_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git" "db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e" "0.8.0"
load_plugin "zshautosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git" "e52ee8ca55bcc56a17c828767a3f98f22a68d4eb" "v0.7.1"
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion)

load_plugin "zsh-autocomplete" "https://github.com/marlonrichert/zsh-autocomplete.git" "762afacbf227ecd173e899d10a28a478b4c84a3f" "24.09.04"

bindkey '^I' menu-select
bindkey -M menuselect '^I' menu-complete
zstyle ':autocomplete:tab:*' widget-style menu-complete
zstyle ':autocomplete:*' min-input 3
bindkey '^R' .history-incremental-search-backward
bindkey '^S' .history-incremental-search-forward

# Initialize starship prompt
eval "$(starship init zsh)"
