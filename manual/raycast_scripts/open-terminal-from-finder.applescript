#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open Current Finder Directory in Terminal
# @raycast.mode silent
# @raycast.packageName Navigation
#
# Optional parameters:
# @raycast.icon 📟
#
# Documentation:
# @raycast.description Open current Finder directory in Terminal
# @raycast.author Kirill Gorbachyonok
# @raycast.authorURL https://github.com/japanese-goblinn

tell application "Finder"
    set myWin to window 1
    set thePath to (quoted form of POSIX path of (target of myWin as alias))
    tell application "Terminal"
        activate
        tell window 1
            do script "cd " & thePath
        end tell
    end tell
end tell
