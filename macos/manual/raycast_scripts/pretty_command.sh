#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Pretty print command
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 👸

# Documentation:
# @raycast.description Formats the command in clipboard to be more readable with AI.
  osascript -e 'tell application "Terminal"
      activate
      do script "format_command_in_clipboard && exit"
  end tell'
