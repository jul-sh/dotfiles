#!/bin/bash
# Remap capslock to backspace via hidutil
# Src 0x700000039 = Caps Lock, Dst 0x70000002a = Backspace
hidutil property --set '{"UserKeyMapping":
    [{"HIDKeyboardModifierMappingSrc":0x700000039,
      "HIDKeyboardModifierMappingDst":0x70000002a}]
}'
