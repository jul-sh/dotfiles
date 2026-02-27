#!/bin/bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
session_name=$(echo "$input" | jq -r '.session_name // empty')
context_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
context_remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')

dir_name=$(basename "$cwd")
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" -c gc.autodetach=false symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        if ! git -C "$cwd" diff-index --quiet HEAD -- 2>/dev/null; then
            git_info=" \033[2m(${branch}*)\033[0m"
        else
            git_info=" \033[2m(${branch})\033[0m"
        fi
    fi
fi

status="\033[2m${dir_name}\033[0m${git_info} \033[2m🌸\033[0m"

if [ -n "$context_used" ] && [ -n "$total_input" ] && [ -n "$total_output" ] && [ -n "$context_remaining" ]; then
    total_tokens=$((total_input + total_output))
    used_int=${context_used%.*}
    remaining_int=${context_remaining%.*}

    # Select kitten based on context usage
    if [ "$used_int" -lt 33 ]; then
        kitten="😺"
    elif [ "$used_int" -lt 66 ]; then
        kitten="😸"
    else
        kitten="😿"
    fi

    # Calculate tokens until limit
    tokens_until_limit=$((context_size - total_tokens))

    status="${status} \033[2m${kitten} ${context_used}% used | ${remaining_int}% remaining | ${tokens_until_limit} tokens to limit\033[0m"
fi

status="${status} \033[2m🌼 ${model}\033[0m"

if [ -n "$session_name" ]; then
    status="\033[2m${session_name}\033[0m ${status}"
fi

printf "$status"
