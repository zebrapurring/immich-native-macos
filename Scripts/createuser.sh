#!/bin/sh

set -eux

echo "INFO: create user"

# shellcheck disable=SC1091
. ./config.sh
if [ -z "$TAG" ]; then
  echo "DEBUG: config not working"
  exit 1
fi

IMMICH_HOME="${IMMICH_PATH:?}/home"
mkdir -p "$IMMICH_HOME"
echo "umask 077" > "$IMMICH_HOME/.bashrc"
chown -R immich:immich "$IMMICH_HOME"

sudo -u immich echo 2> /dev/null || (
dscl . -create "/Groups/immich" && \
  dscl . -create "/Groups/immich" RealName immich && \
  dscl . -create "/Groups/immich" passwd "*" && \
  dscl . -create "/Groups/immich" gid 9999 && \
  dscl . -create "/Users/immich" && \
  dscl . -create "/Users/immich" UserShell /sbin/nologin && \
  dscl . -create "/Users/immich" RealName immich && \
  dscl . -create "/Users/immich" UniqueID 9999 && \
  dscl . -create "/Users/immich" PrimaryGroupID 9999 && \
  dscl . -create "/Users/immich" NFSHomeDirectory "$IMMICH_HOME" && \
  dscl . -create "/Users/immich" passwd "*" && \
  dscl . -create "/Groups/immich" GroupMembership immich
)
