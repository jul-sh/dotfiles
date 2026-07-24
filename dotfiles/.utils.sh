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

# ai <task> - Quick AI helper, continuing the previous session
# ai -c     - Continue interactively
# ai -n     - Run in a new session
alias ai='noglob _ai'
_ai_spinner() {
    local frame
    printf '\033[?25l' >&2
    while true; do
        for frame in · ✢ ✳ ✶ ✻ ✽; do
            printf '\r\033[K\033[36m%s\033[0m thinking...' "$frame" >&2
            sleep 0.15
        done
    done
}

_ai_stop_spinner() {
    [ -n "${1:-}" ] || return
    kill "$1" 2>/dev/null
    wait "$1" 2>/dev/null
    printf '\033[?25h\r\033[K' >&2
}

_ai() {
    local mode=continue backend spinner_pid result exit_code
    local -a args

    case "${1:-}" in
        -c) mode=interactive; shift ;;
        -n|--new) mode=new; shift ;;
    esac

    if [ "$mode" != interactive ] && [ -z "$*" ]; then
        printf '%s\n' "usage: ai <task>" \
            "       ai -c     (continue interactively)" \
            "       ai -n     (start a fresh session)" >&2
        return 1
    fi

    if command -v claude &>/dev/null; then
        backend=claude
    elif command -v gemini &>/dev/null; then
        backend=gemini
    else
        echo "error: neither claude nor gemini CLI found" >&2
        return 1
    fi

    case "$backend:$mode" in
        claude:interactive)
            command claude --dangerously-skip-permissions -c
            return
            ;;
        gemini:interactive)
            command gemini
            return
            ;;
        claude:new)
            args=(-p --model haiku --dangerously-skip-permissions --max-turns 10)
            ;;
        claude:continue)
            args=(-c -p --model haiku --dangerously-skip-permissions --max-turns 10)
            ;;
        gemini:new)
            args=(--yolo -p)
            ;;
        gemini:continue)
            args=(--resume --yolo -p)
            ;;
    esac

    _ai_spinner &
    spinner_pid=$!
    trap "_ai_stop_spinner $spinner_pid" EXIT INT TERM
    case "$backend" in
        claude)
            if result=$(command claude "${args[@]}" \
                    --append-system-prompt "Be concise. Do the task, don't ask follow-up questions." \
                    "$*" 2>&1); then
                exit_code=0
            else
                exit_code=$?
            fi
            ;;
        gemini)
            if result=$(command gemini "${args[@]}" "$*" 2>&1); then
                exit_code=0
            else
                exit_code=$?
            fi
            ;;
    esac
    _ai_stop_spinner "$spinner_pid"
    trap - EXIT INT TERM
    printf '%s\n' "$result"
    return "$exit_code"
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
