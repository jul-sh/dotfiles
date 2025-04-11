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

load_plugin "https://github.com/Aloxaf/fzf-tab.git" "01dad759c4466600b639b442ca24aebd5178e799" "v1.2.0"
load_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e" "0.8.0"
load_plugin "https://github.com/zsh-users/zsh-autosuggestions.git" "e52ee8ca55bcc56a17c828767a3f98f22a68d4eb" "v0.7.1"
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion)

export ZSH_FZF_HISTORY_SEARCH_BIND="^[[A"
load_plugin "https://github.com/joshskidmore/zsh-fzf-history-search" "d5a9730b5b4cb0b39959f7f1044f9c52743832ba"


check_dotfiles_updates_on_startup() {
  # Only run in interactive shells and only if there's git.
  [[ -o interactive ]] || return 0
  command -v git >/dev/null || return 1

  local DOTFILES_DIR="$HOME/git/dotfiles"
  # Check if the specified directory is actually a git repository
  [[ -d "$DOTFILES_DIR/.git" ]] || return 1

  local FLAG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/.zsh_dotfiles_update_commit"

  # Ensure cache directory exists
  command mkdir -p "$(dirname "$FLAG_FILE")" &>/dev/null

  _prompt_for_update() {
    # Prompt user if an update was detected and flagged in a previous session
    if [[ -f "$FLAG_FILE" ]]; then
      local remote_hash
      remote_hash=$(<"$FLAG_FILE")
      command rm -f "$FLAG_FILE" # Consume the flag file immediately

      # Only prompt if we got a valid hash from the flag file
      if [[ -n "$remote_hash" ]]; then
        echo # Newline before prompt
        # Prompt user, wait 60s for a single key press (y/N)
        if read -k 1 -t 60 "REPLY? Dotfiles update available (${\remote_hash[1,8]}...). Pull now? (y/N): "; then
          echo # Newline after user presses a key
          if [[ "$REPLY" =~ ^[Yy]$ ]]; then
            echo "  Pulling dotfiles updates from $DOTFILES_DIR..."
            # Run pull in a subshell to avoid changing the current directory
            # Use --ff-only to ensure the update is a fast-forward
            if (cd "$DOTFILES_DIR" && command git pull --ff-only); then
              echo "  Update complete! Sourcing zshrc to apply changes..."
              # Source zshrc in the current shell to apply updates
              source "${ZDOTDIR:-$HOME}/.zshrc"
            else
              echo -e "  \e[31mUpdate failed.\e[0m Your branch might have diverged or another error occurred. Manual check recommended in $DOTFILES_DIR."
            fi
          else
            echo "  Okay, skipping update for now."
          fi
        else
          echo -e "\n  Prompt timed out or no input. Skipping update." # Handle timeout or non-y/Y input
        fi
      fi
    fi
  }

  _dotfiles_check_async() {
    # Runs in the background to check for updates and flag for the *next* session
    (
      cd "$DOTFILES_DIR" || exit 1
      # Fetch quietly, ignore terminal prompts, timeout after 30s
      if timeout 30s env GIT_TERMINAL_PROMPT=0 command git fetch --quiet; then
        local local_hash remote_hash base_hash
        # Use @ instead of HEAD for robustness if HEAD is detached
        local_hash=$(command git rev-parse @ 2>/dev/null)
        remote_hash=$(command git rev-parse "@{u}" 2>/dev/null) # Get upstream commit hash
        base_hash=$(command git merge-base @ "@{u}" 2>/dev/null)

        # Check if upstream exists, local != remote, and local is ancestor of remote (fast-forward possible)
        if [[ -n "$remote_hash" && "$local_hash" != "$remote_hash" && "$local_hash" == "$base_hash" ]]; then
          # Record the remote hash in the flag file for the next session's check
          echo "$remote_hash" > "$FLAG_FILE"
        else
          # Ensure flag file is removed if no update, diverged, or error
          command rm -f "$FLAG_FILE"
        fi
      else
        # Ensure flag file is removed on fetch error or timeout
        command rm -f "$FLAG_FILE"
      fi
    ) &> /dev/null # Run in subshell, redirect stdout/stderr to /dev/null
    disown %+ >/dev/null 2>&1 # Detach from shell
  }

  # --- Main Logic ---

  # 1. Check if flag file exists from a previous session's check and prompt if needed.
  #    This runs synchronously at the start of the shell.
  _prompt_for_update

  # 2. Start the asynchronous background check for updates for the *next* session.
  _dotfiles_check_async

}
# Call the check function directly on startup
check_dotfiles_updates_on_startup


# Initialize starship prompt
eval "$(starship init zsh)"
