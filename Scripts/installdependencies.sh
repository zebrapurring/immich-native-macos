#!/bin/sh

set -eux

echo "INFO: install dependencies"

# Install root dependencies
if [ "$(whoami)" = "root" ]; then
  mkdir -p "$IMMICH_BIN_DIR"

  # Install custom ffmpeg build jellyfin-ffmpeg
  curl -s -L -o - "https://github.com/jellyfin/jellyfin-ffmpeg/releases/download/v$FFMPEG_VERSION/jellyfin-ffmpeg_${FFMPEG_VERSION}_portable_macarm64-gpl.tar.xz" | \
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

# Install VectorChord PostgreSQL extension
VECTORCHORD_VERSION="0.4.0-fixapplesilicon"
vectorchord_staging_dir="$(mktemp -d -t vectorchord)"
git clone --branch "$VECTORCHORD_VERSION" https://github.com/zebrapurring/VectorChord "$vectorchord_staging_dir"
cd "$vectorchord_staging_dir"
rustup-init --profile minimal --default-toolchain none -y
export PATH="$HOME/.cargo/bin:$PATH"
cargo install cargo-pgrx@"$(sed -n 's/.*pgrx = { version = "\(=.*\)",.*/\1/p' Cargo.toml)" --locked
cargo pgrx init --pg17 pg_config-17
cargo pgrx install --release --pg-config pg_config-17 || true
vectorchord_lib="$(pg_config-17 --libdir)/vchord.dylib"
test -f "$vectorchord_lib"
sed -E -i "" "s|^#?shared_preload_libraries .*$|shared_preload_libraries = '$vectorchord_lib'|" "$(brew --prefix)/var/postgresql@17/postgresql.conf"
cp -a ./sql/upgrade/. "$(pg_config-17 --sharedir)/extension"
cd -
rm -rf "$vectorchord_staging_dir"

# Start services
brew services restart postgresql@17
brew services restart redis
