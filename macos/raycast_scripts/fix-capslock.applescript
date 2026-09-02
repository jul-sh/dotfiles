#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Fix Caps Lock
# @raycast.mode silent
#
# Optional parameters:
# @raycast.icon ⌫
#
# Documentation:
# @raycast.description Reapplies the Caps Lock → Backspace remap. Use it when the remap stops working after a wake or reboot.

# Same mapping as macos/capslock_remap.swift:
# Src 0x700000039 = Caps Lock, Dst 0x70000002a = Backspace
set mapping to "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":0x700000039,\"HIDKeyboardModifierMappingDst\":0x70000002a}]}"
do shell script "/usr/bin/hidutil property --set " & quoted form of mapping

# hidutil prints the Src key code in decimal (0x700000039 = 30064771129)
set current to do shell script "/usr/bin/hidutil property --get UserKeyMapping"
if current contains "30064771129" then
	display notification "Caps Lock → Backspace is active" with title "Fix Caps Lock"
else
	display notification "hidutil did not apply the mapping" with title "Fix Caps Lock"
end if
