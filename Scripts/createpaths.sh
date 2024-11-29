#!/bin/sh

set -eux

echo "INFO: create paths"

mkdir -p "$IMMICH_PATH"
chown -R "$IMMICH_USER:$IMMICH_GROUP" "$IMMICH_PATH"
mkdir -p /var/log/immich
chown -R "$IMMICH_USER:$IMMICH_GROUP" /var/log/immich
