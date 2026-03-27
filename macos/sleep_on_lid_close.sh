#!/bin/bash

# Check if the output of ioreg indicates the clamshell (lid) is closed.
# The '-q' flag for grep makes it "quiet" – it just sets an exit code without printing.
if ioreg -r -k AppleClamshellState | grep -q '"AppleClamshellState" = Yes'; then
  # 1. Enforce the security settings, ensuring mac locks on screensaver
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0

  # 2. Trigger the screensaver
  open -b com.apple.ScreenSaver.Engine

  # 3. Give macOS a brief moment to process the state change
  sleep 2

  # 4. Query the system registry to check the lock status
  IS_LOCKED=$(/usr/libexec/PlistBuddy -c "print :IOConsoleUsers:0:CGSSessionScreenIsLocked" /dev/stdin 2>/dev/null <<< "$(ioreg -n Root -d1 -a)")

  # 5. Confirm and Fallback
  if [ "$IS_LOCKED" = "true" ]; then
      echo "✅ Confirmed: Mac is securely locked with the screensaver running."
  else
      echo "⚠️ Warning: Mac did not lock automatically. Forcing explicit lock..."
      pmset displaysleepnow
  fi
fi
