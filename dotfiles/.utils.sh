#!/usr/bin/env zsh

format_command_in_clipboard() {
  read -r -d '' instruction <<'END_OF_INSTRUCTION'
Format the clipboard's shell command for readability without changing its behavior.
Use line continuations and indentation for long argument lists, quote scalar values,
and pretty-print embedded JSON inside single quotes. Return only the raw command:
no explanation and no Markdown fence.
END_OF_INSTRUCTION

  echo "✨ started formatting"

  pbpaste | aichat "$instruction" | sed -e 's/^```bash[[:space:]]*//' -e 's/[[:space:]]*```$//' | pbcopy

  echo "✨ finished formatting"
}

cl() {
  if [ -n "$ZELLIJ" ]; then
    command claude "$@"
  else
    exec zellij --layout compact -- command claude "$@"
  fi
}

# attach [name] - Attach to or create a zellij session
#   No args: uses <dirname>_<hash> based on $PWD
#   --list:  show existing sessions
attach() {
    local target dir_name path_hash sessions fuzzy_match
    if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
        zellij list-sessions 2>/dev/null || echo "No sessions"
        return
    fi

    if [ -n "${1:-}" ]; then
        target="$1"
    else
        dir_name=$(basename "$PWD")
        path_hash=$(echo "$PWD" | md5sum | cut -c1-4)
        target="${dir_name}_${path_hash}"
    fi

    sessions=$(zellij list-sessions 2>/dev/null | perl -pe 's/\e\[\d*(;\d+)*m//g')
    fuzzy_match=$(echo "$sessions" | grep "^${target}_" | head -n 1 | awk '{print $1}')

    if [ -n "$fuzzy_match" ]; then
        echo "Attaching to: $fuzzy_match"
        zellij attach "$fuzzy_match"
    else
        zellij attach -c "$target"
    fi
}

# Completion for attach: offers --list flag and existing zellij session names
_attach() {
    _arguments '1:session:->session'
    case $state in
        session)
            local -a sessions
            sessions=(--list)
            if command -v zellij &> /dev/null; then
                sessions+=(${(f)"$(zellij list-sessions 2>/dev/null | perl -pe 's/\e\[\d*(;\d+)*m//g' | awk '{print $1}')"})
            fi
            compadd -a sessions
            ;;
    esac
}
if type compdef &> /dev/null; then
    compdef _attach attach
fi

# gh wrapper: strip Claude Code attribution from any --body argument
gh() {
  local args=() body_next=0

  for arg in "$@"; do
    if [ "$body_next" = 1 ]; then
      arg="$(_gh_strip_claude "$arg")"
      body_next=0
    elif [ "$arg" = "--body" ] || [ "$arg" = "-b" ]; then
      body_next=1
    elif [[ "$arg" == --body=* ]]; then
      arg="--body=$(_gh_strip_claude "${arg#--body=}")"
    elif [[ "$arg" == -b=* ]]; then
      arg="-b=$(_gh_strip_claude "${arg#-b=}")"
    fi
    args+=("$arg")
  done

  command gh "${args[@]}"
}

_gh_strip_claude() {
  printf '%s' "$1" | sed -E \
    -e 's/[[:space:]]*🤖[[:space:]]*Generated with \[Claude Code\]\([^)]*\)[[:space:]]*//g' \
    -e '/^Co-Authored-By: Claude .* <noreply@anthropic\.com>$/d'
}
