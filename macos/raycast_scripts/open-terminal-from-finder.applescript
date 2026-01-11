#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Current Finder Directory in WezTerm
# @raycast.mode silent
# @raycast.packageName Navigation
#
# Optional parameters:
# @raycast.icon 📟
#
# Documentation:
# @raycast.description Open current Finder directory in WezTerm
# @raycast.author Kirill Gorbachyonok (modified)
# @raycast.authorURL https://github.com/japanese-goblinn

tell application "Finder"
    set myWin to window 1
    set thePath to POSIX path of (target of myWin as alias)
end tell

do shell script "/bin/zsh -l -c 'wezterm start --cwd " & quoted form of thePath & "'"
