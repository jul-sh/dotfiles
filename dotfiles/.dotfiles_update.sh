#!/usr/bin/env zsh

# --- Dotfiles Auto-Update Check ---
# This script checks if the directory containing the real .zshrc file (or its parent)
# is a Git repository. If it is, it periodically checks for remote updates in the background.
# If an update is found (specifically, a fast-forward update), it prompts the user
# in the *next* interactive shell session whether they want to pull the changes.

# Only run in interactive shells and only if there's git.
[[ -o interactive ]] || return 0
command -v git >/dev/null || return 1

local zshrc_path="${ZDOTDIR:-$HOME}/.zshrc"
local real_zshrc_path
# Try to resolve the real path of .zshrc, following symlinks
real_zshrc_path=$(readlink -f "$zshrc_path" 2>/dev/null)

# Check if .zshrc exists and readlink succeeded
[[ -z "$real_zshrc_path" || ! -e "$real_zshrc_path" ]] && return 1

# Get the directory containing the real .zshrc
local DOTFILES_DIR
DOTFILES_DIR=$(dirname "$real_zshrc_path")

# Check if the directory containing the real .zshrc or its parent is a git repository
[[ -d "$DOTFILES_DIR/.git" ]] || [[ -d "$(dirname "$DOTFILES_DIR")/.git" ]] || return 1

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
