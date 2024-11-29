#!/bin/sh

set -eux

echo "INFO: create paths"

mkdir -p "$IMMICH_INSTALL_DIR"
chown -R "$IMMICH_USER:$IMMICH_GROUP" "$IMMICH_INSTALL_DIR"
mkdir -p /var/log/immich
chown -R "$IMMICH_USER:$IMMICH_GROUP" /var/log/immich
