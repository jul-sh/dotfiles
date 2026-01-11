#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Run Command in Finder Directory
# @raycast.mode silent
# @raycast.argument1 { "type": "text", "placeholder": "Command (e.g., zed .)", "default": "zed ." }
#
# Optional parameters:
# @raycast.icon 🦞
#
# Documentation:
# @raycast.description Runs the specified command in the current Finder directory or selected item's directory.
# @raycast.author chohner (modified)
# @raycast.authorURL https://github.com/chohner

on run argv
	if count of argv is 0 then
		error "No command provided."
	end if
	set theCommand to item 1 of argv

	tell application "Finder"
		# Check if there's a selection; works if there's a window open or not.
		if selection is not {} then
			set i to item 1 of (get selection)

			# If it's an alias, set the item to the original item.
			if class of i is alias file then
				set i to original item of i
			end if

			# If it's a folder, use its path.
			if class of i is folder then
				set p to i
			else
				# If it's an item, use its container's path.
				set p to container of i
			end if
		else if exists window 1 then
			# If a window exist, use its folder property as the path.
			set p to folder of window 1
		else
			# Fallback to the Desktop, as nothing is open or selected.
			set p to path to desktop folder
		end if
	end tell

	set posixPath to quoted form of POSIX path of (p as alias)
	# Construct the shell command to change directory and then execute the user's command
	set shellCmd to "cd " & posixPath & " && " & theCommand

	# Execute through a login shell to get the user's PATH
	do shell script "/bin/zsh -l -c " & quoted form of shellCmd
end run
