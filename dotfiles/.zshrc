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

# Show hidden files in completions
setopt globdots

# Don't error on comments in shell
setopt interactivecomments

# Plugins
load_plugin() {
  local plugin_repo="$1"
  local plugin_commit="$2"
  local plugin_branch="$3"
  local plugin_name
  plugin_name=$(basename "$plugin_repo" .git)
  local plugin_dir="${HOME}/.zsh-plugins/${plugin_name}"

  if [ ! -d "${plugin_dir}" ]; then
    if [ -n "${plugin_branch}" ]; then
      git clone --depth 1 --branch "${plugin_branch}" "${plugin_repo}" "${plugin_dir}"
    else
      git clone --depth 1 "${plugin_repo}" "${plugin_dir}"
      git -C "${plugin_dir}" checkout "${plugin_commit}"
    fi

    local current_commit=$(git -C "${plugin_dir}" rev-parse HEAD)
    if [ "${current_commit}" != "${plugin_commit}" ]; then
      echo "⚠️  Security Warning: The ${plugin_name} plugin from ${plugin_repo}${plugin_branch:+ (branch ${plugin_branch})} has an unexpected commit (${current_commit}) that does not match the expected commit (${plugin_commit}). For your safety, this plugin was not loaded, and the directory was removed to prevent potential remote code execution vulnerabilities."
      rm -rf "${plugin_dir}"
      return
    fi
  fi

  source "${plugin_dir}/${plugin_name}.plugin.zsh"
}

autoload -U compinit
compinit
load_plugin "https://github.com/Aloxaf/fzf-tab.git" "01dad759c4466600b639b442ca24aebd5178e799" "v1.2.0"
load_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e" "0.8.0"
load_plugin "https://github.com/zsh-users/zsh-autosuggestions.git" "e52ee8ca55bcc56a17c828767a3f98f22a68d4eb" "v0.7.1"
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion)

export ZSH_FZF_HISTORY_SEARCH_BIND="^[[A"
load_plugin "https://github.com/joshskidmore/zsh-fzf-history-search" "d5a9730b5b4cb0b39959f7f1044f9c52743832ba"

# Initialize starship prompt
eval "$(starship init zsh)"
