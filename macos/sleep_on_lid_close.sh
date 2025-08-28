#!/bin/bash

# Check if the output of ioreg indicates the clamshell (lid) is closed.
# The '-q' flag for grep makes it "quiet" – it just sets an exit code without printing.
if ioreg -r -k AppleClamshellState | grep -q '"AppleClamshellState" = Yes'; then
  # If the lid is closed, command the Mac to sleep immediately.
  pmset sleepnow
fi
