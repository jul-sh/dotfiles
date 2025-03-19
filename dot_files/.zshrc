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


persist() {
    # 1. Save current environment variables to a temporary file using export -p.
    tmp_env_file=$(mktemp)
    export -p > "$tmp_env_file" || { echo "Error: Failed to save environment variables to $tmp_env_file" >&2; return 1; }

    # 2. Generate a random name for the shpool shell.
    word1=$(shuf -n 1 /usr/share/dict/words 2>/dev/null | tr -d "[:punct:]'")
    word2=$(shuf -n 1 /usr/share/dict/words 2>/dev/null | tr -d "[:punct:]'")
    shpool_name="${word1}_${word2}"
    shpool_name=$(echo "$shpool_name" | tr '[:upper:]' '[:lower:]')

    # Check if /usr/share/dict/words exists.
    if [ ! -f "/usr/share/dict/words" ]; then
        if [ -f "/usr/share/dict/web2" ]; then
            word1=$(shuf -n 1 /usr/share/dict/web2 2>/dev/null | tr -d "[:punct:]'")
            word2=$(shuf -n 1 /usr/share/dict/web2 2>/dev/null | tr -d "[:punct:]'")
            shpool_name="${word1}_${word2}"
            shpool_name=$(echo "$shpool_name" | tr '[:upper:]' '[:lower:]')
        else
            if command -v getent &> /dev/null; then
                word1=$(getent hosts | awk "{print \$2}" | shuf -n 1 | tr -d "[:punct:]")
                word2=$(getent services | awk "{print \$1}" | shuf -n 1 | tr -d "[:punct:]")
                shpool_name="${word1}_${word2}"
                shpool_name=$(echo "$shpool_name" | tr '[:upper:]' '[:lower:]')
            else
                shpool_name="default_fallback"
                echo "Warning: Using default shpool name 'default_fallback'. No word list found." >&2
            fi
        fi
    fi

    # 3. Prefix the current date and time to the name.
    formatted_time=$(date "+%m-%dT%I:%M%p")
    shpool_name="${formatted_time}_${shpool_name}"

    # 4. Construct the command to restore environment variables, delete the temp file, AND start an interactive shell.
    if [ -n "$SHELL" ] && command -v "$SHELL" &> /dev/null; then
        echo "Entering new shpool session with name $shpool_name !"
        restore_cmd="source \"$tmp_env_file\" && rm -f \"$tmp_env_file\" && $SHELL"
        shpool attach "$shpool_name" --ttl "3d" --cmd "$SHELL -c '$restore_cmd'"
    else
        echo "Error: \$SHELL is not set or invalid."
    fi
}

# Initialize starship prompt
eval "$(starship init zsh)"
