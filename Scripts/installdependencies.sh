#!/bin/sh

ME=$(whoami)

. ./config.sh || exit 1

if [ -z "$TAG" ]; then
  echo "DEBUG: config not working"
  exit 1
fi

if [ "$USER" != "$ME" ]; then
  su -l $USER -c "$0" $* || exit 1
else
  echo "INFO:  install dependencies"

  [ -z "$(which brew)" ] && echo "Brew is not installed" && exit 1

  cd /tmp/
  brew install postgresql pgvector node redis ffmpeg vips wget npm python@3.11
  brew services restart postgresql
  brew services restart redis
  cd -
fi
