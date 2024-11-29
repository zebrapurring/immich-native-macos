#!/bin/sh

set -eux

echo "INFO:  install daemons"

launchctl bootout system /Library/LaunchDaemons/com.immich.plist || true
launchctl bootout system /Library/LaunchDaemons/com.immich.machine.learning.plist || true

launchctl bootstrap system /Library/LaunchDaemons/com.immich.plist
launchctl bootstrap system /Library/LaunchDaemons/com.immich.machine.learning.plist
