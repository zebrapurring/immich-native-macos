#!/bin/sh

set -eux

# Re-run script as appropriate user
if [ "$USER" != "$(whoami)" ]; then
  su -l "$USER" -c "$0"
  exit
fi

echo "INFO:  install dependencies"

mkdir -p "$IMMICH_BIN_DIR"

# Install Homebrew dependencies
[ -z "$(which brew)" ] && echo "Homebrew is not installed" && exit 1
brew install \
  node \
  npm \
  pgvector \
  postgresql@17 \
  python@3.11 \
  redis \
  vips \
  wget
brew services restart postgresql@17
brew services restart redis

# Install custom ffmpeg build jellyfin-ffmpeg
curl -s -L -o - "https://github.com/jellyfin/jellyfin-ffmpeg/releases/download/v$IMMICH_FFMPEG_VERSION/jellyfin-ffmpeg_${IMMICH_FFMPEG_VERSION}_portable_macarm64-gpl.tar.xz" | \
  tar xzvf - -C "$IMMICH_BIN_DIR"

# Adjust permissions
chown -R "$IMMICH_USER:$IMMICH_GROUP" "$IMMICH_BIN_DIR"
