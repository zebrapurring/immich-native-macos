#!/bin/sh

set -eux

# shellcheck disable=SC1091
. ./Scripts/config.sh

delete_user() {
  echo "INFO: deleting user"
  sudo dscl . -delete "/Groups/$IMMICH_GROUP"
  sudo dscl . -delete "/Users/$IMMICH_USER"
}

uninstall_daemons() {
  echo "INFO: uninstalling daemons"
  sudo launchctl bootout system /Library/LaunchDaemons/com.immich.machine.learning.plist
  sudo launchctl bootout system /Library/LaunchDaemons/com.immich.plist
  sudo rm -f /Library/LaunchDaemons/com.immich*plist
}

delete_postgres_db() {
  echo "INFO: deleting PostgreSQL immich user and database"
  psql-17 postgres << EOF
drop database immich;
drop user immich;
EOF
}

echo "WARNING: this will remove the Immich database and the complete installation directory, including the uploads directory"
echo "Continue? (y/n) "
read -r yn
case "$yn" in
  [Yy]*) ;;
  *) exit;;
esac

uninstall_daemons
delete_postgres_db
delete_user

echo "INFO: deleting $IMMICH_INSTALL_DIR"
sudo rm -rf "$IMMICH_INSTALL_DIR"
