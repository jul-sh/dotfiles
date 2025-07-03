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

# Initialize completion system
autoload -Uz compinit
# Avoid recompiling .zcompdump too often, check if it's older than 1 day
if [[ ! -f ~/.zcompdump || -z $(find ~/.zcompdump -mtime -1) ]]; then
  compinit -d ~/.zcompdump # Specify dump file path
else
  compinit -i -d ~/.zcompdump # Use existing dump file without checks
fi

load_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e" "0.8.0"

load_plugin "https://github.com/marlonrichert/zsh-autocomplete.git" "8302f16393b9844b24365ba01fe47e18c102962c"
bindkey '^I' menu-select
bindkey -M menuselect '^I' menu-complete
zstyle ':autocomplete:tab:*' widget-style menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
zstyle ':autocomplete:*' min-input 3
# Esc to exit autocomplete menu
bindkey -M menuselect '^[' undo
# Restore default history binding, otherwise occupied by zsh autocomplete
bindkey -M emacs \
    "^[p"   .history-search-backward \
    "^[n"   .history-search-forward \
    "^P"    .up-line-or-history \
    "^[OA"  .up-line-or-history \
    "^[[A"  .up-line-or-history \
    "^N"    .down-line-or-history \
    "^[OB"  .down-line-or-history \
    "^[[B"  .down-line-or-history \
    "^R"    .history-incremental-search-backward \
    "^S"    .history-incremental-search-forward \
    #
bindkey -a \
    "^P"    .up-history \
    "^N"    .down-history \
    "k"     .up-line-or-history \
    "^[OA"  .up-line-or-history \
    "^[[A"  .up-line-or-history \
    "j"     .down-line-or-history \
    "^[OB"  .down-line-or-history \
    "^[[B"  .down-line-or-history \
    "/"     .vi-history-search-backward \
    "?"     .vi-history-search-forward \
    #

export ZSH_FZF_HISTORY_SEARCH_BIND="^[[A"
load_plugin "https://github.com/joshskidmore/zsh-fzf-history-search" "d5a9730b5b4cb0b39959f7f1044f9c52743832ba"


# Check for dotfile updates
if [ -f "${HOME}/.dotfiles_update.sh" ]; then
  source "${HOME}/.dotfiles_update.sh"
fi

if [ -f "${HOME}/.utils.sh" ]; then
  source "${HOME}/.utils.sh"
fi

# Confirm quittting
# Custom widget to confirm exit on Ctrl+D
confirm-exit() {
  # If the command buffer is empty...
  if [[ -z "$BUFFER" ]]; then
    # Ask for confirmation
    # -q reads one character, ? is the prompt
    read -q "choice?Are you sure you want to exit? [y/N] "

    # Add a newline so the next prompt is clean
    print -n "\n"

    # If the user typed 'y' or 'Y', exit the shell
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
      exit
    else
      # Otherwise, just redraw the prompt
      zle redisplay
    fi
  else
    # If the buffer is not empty, perform the default action
    # for Ctrl+D, which is to delete a character.
    zle delete-char
  fi
}

# Create a new ZLE widget named 'confirm-exit'
zle -N confirm-exit

# Bind Ctrl+D to our new custom widget
bindkey '^D' confirm-exit

# Initialize starship prompt
eval "$(starship init zsh)"
