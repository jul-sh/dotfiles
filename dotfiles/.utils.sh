#!/usr/bin/env zsh

format_command_in_clipboard() {
  read -r -d '' instruction <<'END_OF_INSTRUCTION'
Format the following shell command to be more human-readable. Pay special attention to make sure that the formatted shell command still does the exact same thing as the unformatted one. Respond with only the formatted command, nothing else.

For example, if presented with this command

xtask run -- \
--tk_parent=project/resource/quota-name \
--experiment_name="Specific Experiment Name" \
--target_item.item_location=item/path/or/identifier \
--target_item.item_category=CATEGORY_A \
--target_item.processing_mode=MODE_X \
--target_item.use_client_side_processing=True \
--run_config.output_dir=/path/to/your/output \
--run_params=\{\"data_source.data_size\":100,\"data_source.tk_source.grl\":123456789,\"run_config.spec_name\":\"your_spec\",\"run_config.task_type\":\"your_task_type\",\"run_config.item_count\":500,\"run_config.bear_mechanism\":\"your_bear_mechanism\",\"run_config.bear_args\":\{\}\}

you would output:

xtask run -- \
  --tk_parent="project/resource/quota-name" \
  --experiment_name="Specific Experiment Name" \
  --target_item.item_location="item/path/or/identifier" \
  --target_item.item_category="CATEGORY_A" \
  --target_item.processing_mode="MODE_X" \
  --target_item.use_client_side_processing="True" \
  --run_config.output_dir="/path/to/your/output" \
  --run_params='{
    "data_source.data_size": 100,
    "data_source.tk_source.grl": 123456789,
    "run_config.spec_name": "your_spec",
    "run_config.task_type": "your_task_type",
    "run_config.item_count": 500,
    "run_config.bear_mechanism": "your_bear_mechanism",
    "run_config.bear_args": {}
  }'

Respond with only the raw formatted command, nothing else.
END_OF_INSTRUCTION

  echo "✨ started formatting"

  pbpaste | aichat "$instruction" | sed -e 's/^```bash[[:space:]]*//' -e 's/[[:space:]]*```$//' | pbcopy

  echo "✨ finished formatting"
}

claude() {
  if [ -n "$ZELLIJ" ]; then
    command claude "$@"
  else
    exec zellij --layout compact -- command claude "$@"
  fi
}
# ai <task> - Quick AI helper (auto-accepts, exits when done)
# ai -c     - Continue last conversation in interactive mode
# ai -n     - Start fresh session (don't continue previous)
# Use noglob to allow unquoted special chars: ai kill the process on port 6666
alias ai='noglob _ai'
_ai_spinner() {
    local -a spin=(· ✢ ✳ ✶ ✻ ✽ ✻ ✶ ✳ ✢)
    local -a colors=("\033[38;5;209m" "\033[38;5;208m" "\033[38;5;203m" "\033[38;5;204m" "\033[38;5;198m" "\033[38;5;199m" "\033[38;5;164m" "\033[38;5;135m" "\033[38;5;141m" "\033[38;5;147m" "\033[38;5;153m" "\033[38;5;159m")

    # Build hints array - resume info first if present (via env vars)
    local -a hints=()
    if [ -n "$_AI_RESUME_TURNS" ]; then
        hints+=("resuming ($_AI_RESUME_TURNS turns)")
    elif [ -n "$_AI_RESUME" ]; then
        hints+=("resuming session")
    fi
    hints+=("thinking..." "tip: run ai again to follow up" "tip: -c to enter CLI" "tip: -n for fresh")

    # Shuffle hints (keep resume first if present)
    local start_idx=1
    [ -n "$_AI_RESUME_TURNS" ] || [ -n "$_AI_RESUME" ] && start_idx=2
    local n=${#hints[@]}
    local i j tmp
    for ((i=n; i>start_idx; i--)); do
        j=$((RANDOM % (i - start_idx + 1) + start_idx))
        tmp=${hints[$i]}; hints[$i]=${hints[$j]}; hints[$j]=$tmp
    done

    local frame=1 hint_idx=1 frame_in_hint=0 frames_per_hint=18
    printf '\033[?25l' >&2
    while true; do
        local txt="${hints[$hint_idx]}"
        local spin_idx=$(( (frame - 1) % 10 + 1 ))
        local out="\r\033[K\033[36m${spin[$spin_idx]}\033[0m "
        local j=0
        while [ $j -lt ${#txt} ]; do
            local cidx=$(( (frame + j - 1) % 12 + 1 ))
            out+="${colors[$cidx]}${txt:$j:1}"
            j=$((j + 1))
        done
        printf "$out\033[0m" >&2
        sleep 0.15
        frame=$((frame + 1))
        frame_in_hint=$((frame_in_hint + 1))
        if [ $frame_in_hint -ge $frames_per_hint ]; then
            frame_in_hint=0
            hint_idx=$((hint_idx % n + 1))
        fi
    done
}
_ai_get_turn_count() {
    # Get turn count from most recent Claude session for current directory
    local proj_dir="$HOME/.claude/projects/-$(pwd | tr '/' '-' | cut -c2-)"
    [ -d "$proj_dir" ] || return
    local latest=$(ls -t "$proj_dir"/*.jsonl 2>/dev/null | grep -v agent- | head -1)
    [ -f "$latest" ] || return
    # Count user messages (turns)
    grep -c '"type":"user"' "$latest" 2>/dev/null
}
_ai() {
    if [ "$1" = "-c" ]; then
        if command -v claude &>/dev/null; then
            claude --dangerously-skip-permissions -c
        elif command -v gemini &>/dev/null; then
            gemini
        else
            echo "error: neither claude nor gemini CLI found" >&2
            return 1
        fi
        return
    fi

    local new_session=false
    if [ "$1" = "--new" ] || [ "$1" = "-n" ]; then
        new_session=true
        shift
    fi

    if [ -z "$*" ]; then
        echo "usage: ai <task>" >&2
        echo "       ai -c     (continue in interactive mode)" >&2
        echo "       ai -n     (start fresh session)" >&2
        return 1
    fi

    # Determine resume state and start spinner with env vars
    local spinner_pid result
    if command -v claude &>/dev/null; then
        local continue_flag=""
        if ! $new_session; then
            continue_flag="-c"
            local turns=$(_ai_get_turn_count)
            if [ -n "$turns" ] && [ "$turns" -gt 0 ]; then
                _AI_RESUME_TURNS="$turns" _ai_spinner &!
            else
                _ai_spinner &!
            fi
        else
            _ai_spinner &!
        fi
        spinner_pid=$!
        trap "kill $spinner_pid 2>/dev/null; wait $spinner_pid 2>/dev/null; printf '\033[?25h\r\033[K' >&2; trap - EXIT INT" EXIT INT
        result=$(claude $continue_flag -p --model haiku --dangerously-skip-permissions --max-turns 10 \
            --append-system-prompt "Be concise. Do the task, don't ask follow-up questions." "$*" 2>&1)
    elif command -v gemini &>/dev/null; then
        local resume_flag=""
        if ! $new_session; then
            resume_flag="--resume"
            local recent=$(find ~/.gemini/antigravity/conversations -name "*.pb" -mtime -1 2>/dev/null | head -1)
            if [ -n "$recent" ]; then
                _AI_RESUME=1 _ai_spinner &!
            else
                _ai_spinner &!
            fi
        else
            _ai_spinner &!
        fi
        spinner_pid=$!
        trap "kill $spinner_pid 2>/dev/null; wait $spinner_pid 2>/dev/null; printf '\033[?25h\r\033[K' >&2; trap - EXIT INT" EXIT INT
        result=$(gemini $resume_flag --yolo -p "$*" 2>&1)
    else
        echo "error: neither claude nor gemini CLI found" >&2
        return 1
    fi

    kill $spinner_pid 2>/dev/null
    wait $spinner_pid 2>/dev/null
    printf '\033[?25h\r\033[K' >&2
    echo "$result"
    trap - EXIT INT
}


# attach [name] - Attach to or create a zellij session
#   No args: uses <dirname>_<hash> based on $PWD
#   --list:  show existing sessions
attach() {
    if [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
        zellij list-sessions 2>/dev/null || echo "No sessions"
        return
    fi

    if [ -n "$1" ]; then
        TARGET="$1"
    else
        DIR_NAME=$(basename "$PWD")
        PATH_HASH=$(echo "$PWD" | md5sum | cut -c1-4)
        TARGET="${DIR_NAME}_${PATH_HASH}"
    fi

    SESSIONS=$(zellij list-sessions 2>/dev/null | perl -pe 's/\e\[\d*(;\d+)*m//g')
    FUZZY_MATCH=$(echo "$SESSIONS" | grep "^${TARGET}_" | head -n 1 | awk '{print $1}')

    if [ -n "$FUZZY_MATCH" ]; then
        echo "Attaching to: $FUZZY_MATCH"
        zellij attach "$FUZZY_MATCH"
    else
        zellij attach -c "$TARGET"
    fi
}

# Initialize Git LFS with absolute paths in hooks (fixes Homebrew subprocess issues)
if command -v git-lfs &> /dev/null; then
  git lfs install --skip-smudge >/dev/null 2>&1
  # Patch hooks to use absolute path since subprocesses (e.g., Homebrew) may not have nix in PATH
  GIT_LFS_PATH="$(command -v git-lfs)"
  HOOKS_DIR="$(git config --global core.hooksPath 2>/dev/null)"
  if [ -n "$HOOKS_DIR" ] && [ -d "$HOOKS_DIR" ]; then
    for hook in "$HOOKS_DIR"/{post-checkout,post-commit,post-merge,pre-push}; do
      [ -f "$hook" ] && sed -i '' "s|command -v git-lfs|command -v $GIT_LFS_PATH|g; s|git lfs |$GIT_LFS_PATH |g" "$hook" 2>/dev/null
    done
  fi
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
