#!/bin/sh

set -eux

echo "INFO: install dependencies"

# Install root dependencies
if [ "$(whoami)" = "root" ]; then
  mkdir -p "$IMMICH_BIN_DIR"

  # Install custom ffmpeg build jellyfin-ffmpeg
  curl -s -L -o - "https://github.com/jellyfin/jellyfin-ffmpeg/releases/download/v$FFMPEG_VERSION/jellyfin-ffmpeg_${FFMPEG_VERSION}_portable_macarm64-gpl.tar.xz" |
    tar xzvf - -C "$IMMICH_BIN_DIR"

  # Adjust permissions
  chown -R "$IMMICH_USER:$IMMICH_GROUP" "$IMMICH_BIN_DIR"
fi

# Re-run script as main user
if [ "$USER" != "$(whoami)" ]; then
  su -l "$USER" -c "$0"
  exit
fi

# Install Homebrew dependencies
export HOMEBREW_NO_AUTO_UPDATE=1
[ -z "$(which brew)" ] && echo "Homebrew is not installed" && exit 1
brew install \
  node \
  npm \
  postgresql@17 \
  redis \
  python@3.12 \
  rustup \
  vips \
  wget

# Initialise Rust environment
rustup-init --profile minimal --default-toolchain none -y
export PATH="$HOME/.cargo/bin:$PATH"

# Install PostgreSQL extension VectorChord
VECTORCHORD_VERSION="0.4.2" # Taken from https://github.com/immich-app/immich/blob/main/docker/docker-compose.yml
vectorchord_staging_dir="$(mktemp -d -t vectorchord)"
git clone --branch "$VECTORCHORD_VERSION" https://github.com/tensorchord/VectorChord "$vectorchord_staging_dir"
cd "$vectorchord_staging_dir"
PGRX_PG_CONFIG_PATH="$(brew --prefix postgresql@17)/bin/pg_config" \
  cargo pgrx install \
  -p vchord \
  --features pg17 \
  --release \
  --pg-config "$(brew --prefix postgresql@17)/bin/pg_config"
sed -E -i "" "s|^#?shared_preload_libraries .*$|shared_preload_libraries = 'vchord.dylib'|" "$(brew --prefix)/var/postgresql@17/postgresql.conf"
cd -
rm -rf "$vectorchord_staging_dir"

# Start services
brew services restart postgresql@17
brew services restart redis
