#!/bin/sh

set -eux

# Re-run script as appropriate user
if [ "$USER" != "$(whoami)" ]; then
  su -l "$USER" -c "$0"
  exit
fi

echo "INFO:  install dependencies"

[ -z "$(which brew)" ] && echo "Homebrew is not installed" && exit 1

brew install \
  ffmpeg \
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
