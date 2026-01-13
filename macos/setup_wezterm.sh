#!/usr/bin/env bash

# Remap System Keys for WezTerm only via macOS Defaults
# We map them to a "garbage" key combo (Shift+Ctrl+Opt+Cmd + Key)
# so the OS stops intercepting the clean Cmd+Q/W/H.
echo "Staging macOS system shortcut overrides for WezTerm..."

# The '20' bitmask represents Cmd+Opt+Ctrl+Shift
defaults write com.apple.universalaccess "com.apple.wezterm" -dict-add \
    "Quit WezTerm" "@^$~q" \
    "Close" "@^$~w" \
    "Hide WezTerm" "@^$~h"

# Apply the changes
killall cfprefsd || true

echo "macOS system shortcut overrides staged."
echo "Done! Please RESTART WezTerm for changes to take effect."
