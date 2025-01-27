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
load_plugin "zsh-autocomplete" "https://github.com/marlonrichert/zsh-autocomplete.git" "762afacbf227ecd173e899d10a28a478b4c84a3f" "24.09.04"

# Initialize starship prompt
eval "$(starship init zsh)"
