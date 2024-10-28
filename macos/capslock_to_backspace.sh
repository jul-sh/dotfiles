#!/bin/bash
# Remap capslock to backspace
# This script uses the 'hidutil' command to modify keyboard mappings
# The 'property' option sets a new property for the Human Interface Device (HID)
# 'UserKeyMapping' defines a custom key mapping
# The 'HIDKeyboardModifierMappingSrc' (0x700000039) represents the source key (Caps Lock)
# The 'HIDKeyboardModifierMappingDst' (0x70000002a) represents the destination key (Backspace)
hidutil property --set '{"UserKeyMapping":
    [{"HIDKeyboardModifierMappingSrc":0x700000039,
      "HIDKeyboardModifierMappingDst":0x70000002a}]
}'
