#!/bin/bash

CURRENT_TIMESTAMP=$(date +%s)
PREV_BACKUP_TIMESTAMP=$(cat /Users/julsh/scripts/.backup_to_purple_if_available.lastbackuptimestamp 2>&- || echo 0)
DIFFERENCE=$((CURRENT_TIMESTAMP - PREV_BACKUP_TIMESTAMP))
ONE_DAY_DURATION='86400'
if [ "$DIFFERENCE" -lt "$ONE_DAY_DURATION" ]; then
  exit 1
fi

POWER_SOURCE=$(pmset -g batt | head -n 1 | cut -d \' -f2)
if [ "$POWER_SOURCE" != 'AC Power' ]; then
  exit 1
fi

NETWORK_NAME=$(/Sy*/L*/Priv*/Apple8*/V*/C*/R*/airport -I | awk '/ SSID:/ {print $2}')
if [ "$NETWORK_NAME" != '_trans_rights' ]; then
  exit 1
fi

SERVER_AT_IP=$(smbutil status 192.168.69.101 | awk '/Server:/{print $2}')
if [ "$SERVER_AT_IP" != 'PURPLE' ]; then
  exit 1
fi

osascript <<EOF
mount volume "smb://192.168.69.101/PurpleHost"
EOF
hdiutil attach /Volumes/PurpleHost/PurpleTimeMachine.dmg &&
  tmutil startbackup --auto --block
hdiutil unmount /Volumes/PurpleTimeMachine
diskutil unmount force /Volumes/PurpleHost

echo $CURRENT_TIMESTAMP >/Users/julsh/scripts/.backup_to_purple_if_available.lastbackuptimestamp

exit 0
