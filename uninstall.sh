#!/bin/sh

set -eux

# shellcheck disable=SC1091
. ./Scripts/config.sh

REALUSER="$(whoami)"

delete_user() {
  echo "INFO: deleting user"
  dscl . -delete "/Users/immich" && \
  dscl . -delete "/Groups/immich"
}

uninstall_daemons() {
  echo "INFO: uninstalling daemons"
  launchctl bootout system /Library/LaunchDaemons/com.immich.machine.learning.plist
  launchctl bootout system /Library/LaunchDaemons/com.immich.plist
  rm -f /Library/LaunchDaemons/com.immich*plist
}

delete_postgres_db() {
  echo "INFO: deleting PostgreSQL immich user and database"
  sudo -E -u "$REALUSER" psql-17 postgres << EOF
drop database immich;
drop user immich;
EOF
}


uninstall_daemons
delete_user
delete_postgres_db
echo "INFO: deleting $IMMICH_INSTALL_DIR"
rm -rf "$IMMICH_INSTALL_DIR"
