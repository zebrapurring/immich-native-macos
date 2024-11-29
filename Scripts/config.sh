#!/bin/sh

export TAG="v1.121.0"
export IMMICH_PATH="/opt/services/immich"
export IMMICH_HOME="$IMMICH_PATH/home"
export IMMICH_USER="immich"
export IMMICH_GROUP="immich"
export APP="$IMMICH_PATH/app"
BASEDIR="$(dirname "$0")"
export BASEDIR
export PATH="/usr/local/bin:$PATH"
