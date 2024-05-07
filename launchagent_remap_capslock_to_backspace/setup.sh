#!bin/bash
sudo cp ./capslock_to_backspace.sh /Library/Scripts/
sudo chmod +x /Library/Scripts/capslock_to_backspace.sh
sudo cp ./com.capslock_to_backspace.plist /Library/LaunchDaemons/
sudo launchctl load -w /Library/LaunchDaemons/com.capslock_to_backspace.plist
