#!/bin/sh

IMMICH_PATH=/opt/services/immich
REALUSER=$(whoami)

deleteUser() {
  echo "INFO: deleting user"
  dscl . -delete "/Users/immich" && \
  dscl . -delete "/Groups/immich"
}

uninstallDaemons() {
  echo "INFO: uninstalling daemons"
  launchctl unload -w /Library/LaunchDaemons/com.immich.machine.learning.plist
  launchctl unload -w /Library/LaunchDaemons/com.immich.plist
  rm -f /Library/LaunchDaemons/com.immich*plist
}

deletePostgresUser() {
  echo "INFO: deleting postgres user"
  sudo -u "$REALUSER" psql postgres << EOF
drop database immich;
drop user immich;
EOF
}


uninstallDaemons
deleteUser
deletePostgresUser
echo "INFO: deleting $IMMICH_PATH"
rm -rf $IMMICH_PATH
