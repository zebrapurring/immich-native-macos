#!/bin/sh

set -eux

echo "INFO: create user"

# shellcheck disable=SC1091
. ./config.sh
if [ -z "$TAG" ]; then
  echo "DEBUG: config not working"
  exit 1
fi

mkdir -p "$IMMICH_HOME"
echo "umask 077" > "$IMMICH_HOME/.bashrc"
chown -R "$IMMICH_USER:$IMMICH_GROUP" "$IMMICH_HOME"

if dscl . -list /Users/immich > /dev/null 2>&1; then
  # User already exists
  exit 0
fi

# Create group
dscl . -create "/Groups/$IMMICH_GROUP"
dscl . -create "/Groups/$IMMICH_GROUP" RealName "Immich headless user"
dscl . -create "/Groups/$IMMICH_GROUP" passwd "*"
dscl . -create "/Groups/$IMMICH_GROUP" gid 9999

# Create user
dscl . -create "/Users/$IMMICH_USER"
dscl . -create "/Users/$IMMICH_USER" UserShell /sbin/nologin
dscl . -create "/Users/$IMMICH_USER" RealName "Immich headless user"
dscl . -create "/Users/$IMMICH_USER" UniqueID 9999
dscl . -create "/Users/$IMMICH_USER" PrimaryGroupID 9999
dscl . -create "/Users/$IMMICH_USER" NFSHomeDirectory "$IMMICH_HOME"
dscl . -create "/Users/$IMMICH_USER" passwd "*"

# Add user to group
dscl . -create "/Groups/$IMMICH_GROUP" GroupMembership "$IMMICH_USER"
