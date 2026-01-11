#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Current WezTerm Directory in Finder
# @raycast.mode silent
# @raycast.packageName Navigation
#
# Optional parameters:
# @raycast.icon 📇
#
# Documentation:
# @raycast.description Open current WezTerm directory in Finder
# @raycast.author Kirill Gorbachyonok (modified)
# @raycast.authorURL https://github.com/japanese-goblinn

# Get the cwd of the active WezTerm pane using wezterm cli
set paneInfo to do shell script "/bin/zsh -l -c 'wezterm cli list --format json'"
set cwd to do shell script "echo " & quoted form of paneInfo & " | /bin/zsh -l -c 'jq -r \".[0].cwd\"'"

# Open Finder at that path
do shell script "open " & quoted form of cwd
