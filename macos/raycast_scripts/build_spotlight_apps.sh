#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/Applications/Spotlight Scripts"

escape_applescript_string() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

sanitize_app_name() {
  local s="$1"
  s="${s//\//-}"
  s="${s//:/-}"
  s="${s//\"/}"
  printf '%s' "$s"
}

mkdir -p "$TARGET_DIR"

shopt -s nullglob
for script_path in "$SOURCE_DIR"/*.applescript; do
  title="$(rg -m1 '^# @raycast.title' "$script_path" | sed -E 's/^# @raycast.title[[:space:]]*//' || true)"
  if [[ -z "$title" ]]; then
    title="$(basename "$script_path" .applescript)"
  fi

  app_name="$(sanitize_app_name "$title")"
  app_path="$TARGET_DIR/$app_name.app"

  if [[ -e "$app_path" ]]; then
    echo "Skipping (exists): $app_path"
    continue
  fi

  placeholder="$(rg -m1 '^# @raycast.argument1' "$script_path" | sed -nE 's/.*"placeholder":[[:space:]]*"([^"]+)".*/\1/p' || true)"
  default_value="$(rg -m1 '^# @raycast.argument1' "$script_path" | sed -nE 's/.*"default":[[:space:]]*"([^"]+)".*/\1/p' || true)"
  if rg -q '^# @raycast.argument1' "$script_path"; then
    prompt_text="${placeholder:-Enter argument}"
    default_answer="${default_value:-}"
    script_path_escaped="$(escape_applescript_string "$script_path")"
    prompt_escaped="$(escape_applescript_string "$prompt_text")"
    default_escaped="$(escape_applescript_string "$default_answer")"
    applescript="$(cat <<APPLESCRIPT
on run
    set scriptPath to "$script_path_escaped"
    set promptText to "$prompt_escaped"
    try
        set userArg to text returned of (display dialog promptText default answer "$default_escaped")
    on error number -128
        return
    end try
    if userArg is "" then return
    do shell script "/usr/bin/osascript " & quoted form of scriptPath & " " & quoted form of userArg
end run
APPLESCRIPT
)"
  else
    script_path_escaped="$(escape_applescript_string "$script_path")"
    applescript="$(cat <<APPLESCRIPT
on run
    set scriptPath to "$script_path_escaped"
    do shell script "/usr/bin/osascript " & quoted form of scriptPath
end run
APPLESCRIPT
)"
  fi

  printf '%s\n' "$applescript" | osacompile -o "$app_path"
  echo "Created: $app_path"
done
