. "$HOME/.cargo/env"


alias ai='aichat -e'
export PATH="/usr/local/bin:$PATH"

if command -v python3 &> /dev/null; then
  # Set these if python3 is available
  export PATH="$(python3 -m site --user-base)/bin:$PATH"
  alias python='python3'
fi


# A smart zellij attach/create function.
# Usage:
#   za          - Attaches to a session for the current directory, or creates one.
#   za <name>   - Attaches to or creates a session with a specific name.
za() {
  # If an argument is provided, use it as the session name directly.
  if [[ -n "$1" ]]; then
    zellij attach "$1" || zellij --session "$1"
    return
  fi

  # --- ZSH Version ---
  # Uses ZSH's built-in parameter expansion for conciseness.
  if [ -n "$ZSH_VERSION" ]; then
    local parent_dir=${PWD:h:t}   # Parent directory's name
    local current_dir=${PWD:t}   # Current directory's name
    local sanitized_path=$(echo "$PWD" | tr '/' '_') # Full path with '/' -> '_'

  # --- Bash Version ---
  # Uses standard commands for compatibility.
  elif [ -n "$BASH_VERSION" ]; then
    local current_dir=$(basename "$(pwd)")
    local parent_dir=$(basename "$(dirname "$(pwd)")")
    local sanitized_path=$(pwd | tr '/' '_') # Full path with '/' -> '_'

  else
    echo "Unsupported shell. This function works with ZSH or Bash."
    return 1
  fi

  # Combine them into a descriptive and unique session name.
  # Example: projects-my-app--_home_user_projects_my-app
  local session_name="${parent_dir}-${current_dir}--${sanitized_path}"

  # Attach to the session if it exists, otherwise create it with the new name.
  zellij attach "$session_name" || zellij --session "$session_name"
}

. "$HOME/.atuin/bin/env"
