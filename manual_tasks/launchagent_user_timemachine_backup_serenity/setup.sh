#!/bin/bash
mkdir -p ~/scripts
cp ./com.julsh.backuptm.plist ~/Library/LaunchAgents/
cp ./backup_to_purple_if_available.sh ~/scripts
chmod +x ~/scripts/backup_to_purple_if_available.sh
launchctl load ~/Library/LaunchAgents/com.julsh.backuptm.plist
