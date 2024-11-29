#!/bin/sh

set -eux

echo "INFO: create paths"

# shellcheck disable=SC1091
. ./config.sh

if [ -z "$TAG" ]; then
  echo "DEBUG: config not working"
  exit 1
fi

mkdir -p "$IMMICH_PATH"
chown -R "$IMMICH_USER:$IMMICH_GROUP" "$IMMICH_PATH"
mkdir -p /var/log/immich
chown -R "$IMMICH_USER:$IMMICH_GROUP" /var/log/immich
