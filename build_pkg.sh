#!/bin/sh

set -eu

if [ "${1:-}" = "-v" ]; then
  set -x
fi

clone_immich() {
  git_tag="$1"
  repo_dir="$2"
  conf_dir="$3"

  # Clone the repository
  if [ ! -d "$repo_dir" ]; then
    git clone --depth 1 --branch "$git_tag" https://github.com/immich-app/immich "$repo_dir"
  fi

  # Dump information about the build revision
  mkdir -p "$conf_dir"
  cat <<EOF > "$conf_dir/build_info.env"
# Build information
IMMICH_BUILD=""
IMMICH_BUILD_URL=""
IMMICH_BUILD_IMAGE=""
IMMICH_BUILD_IMAGE_URL=""
IMMICH_REPOSITORY="immich-app/immich"
IMMICH_REPOSITORY_URL="$(git -C "$repo_dir" remote get-url origin)"
IMMICH_SOURCE_REF=""
IMMICH_SOURCE_COMMIT="$(git -C "$repo_dir" rev-parse HEAD)"
IMMICH_SOURCE_URL=""

EOF
}

build_immich() {
  repo_dir="$1"
  dest_dir="$2"

  # Build server backend
  cp -R "$repo_dir/server/" "$dest_dir/"
  cd "$dest_dir"
  npm ci --foreground-scripts
  npm run build
  npm prune --omit=dev --omit=optional
  npm install --os=darwin --cpu=arm64 sharp
  cd -

  # Build web frontend
  mkdir -p "$dest_dir/open-api"
  cp -R "$repo_dir/open-api/typescript-sdk" "$dest_dir/open-api/"
  cp -R "$repo_dir/i18n" "$dest_dir"
  npm --prefix "$dest_dir/open-api/typescript-sdk" ci
  npm --prefix "$dest_dir/open-api/typescript-sdk" run build
  npm --prefix "$dest_dir/open-api/typescript-sdk" prune --omit=dev --omit=optional
  cp -R "$repo_dir/web" "$dest_dir/"
  rm "$dest_dir/web/package-lock.json"
  npm --prefix "$dest_dir/web" install --foreground-scripts
  npm --prefix "$dest_dir/web" install --os=darwin --cpu=arm64 sharp
  npm --prefix "$dest_dir/web" run build
  npm --prefix "$dest_dir/web" prune --omit=dev --omit=optional
  mkdir "$dest_dir/build"
  mv "$dest_dir/web/build" "$dest_dir/build/www"
  rm -rf "$dest_dir/open-api" "$dest_dir/i18n" "$dest_dir/web"

  # Generate empty build lockfile
  echo "{}" > "$dest_dir/build/build-lock.json"
}

build_immich_machine_learning() {
  repo_dir="$1"
  dest_dir="$2"

  # Build the machine learning backend
  cp -R "$repo_dir/machine-learning" "$dest_dir/"
  cd "$dest_dir/machine-learning"
  python3.11 -m venv "./venv"
  (
    # shellcheck disable=SC1091
    . "./venv/bin/activate"
    pip3.11 install poetry
    poetry install --no-root --with dev --with cpu
  )
  cd -
}

fetch_immich_geodata() {
  dest_dir="$1"

  # Download geodata
  mkdir -p "$dest_dir/build/geodata"
  curl -o "$dest_dir/build/geodata/cities500.zip" https://download.geonames.org/export/dump/cities500.zip
  unzip "$dest_dir/build/geodata/cities500.zip" -d "$dest_dir/build/geodata" && rm "$dest_dir/build/geodata/cities500.zip"
  curl -o "$dest_dir/build/geodata/admin1CodesASCII.txt" https://download.geonames.org/export/dump/admin1CodesASCII.txt
  curl -o "$dest_dir/build/geodata/admin2Codes.txt" https://download.geonames.org/export/dump/admin2Codes.txt
  curl -o "$dest_dir/build/geodata/ne_10m_admin_0_countries.geojson" https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_0_countries.geojson
  date -u +"%Y-%m-%dT%H:%M:%S%z" | tr -d "\n" > "$dest_dir/build/geodata/geodata-date.txt"
  chmod -R 444 "$dest_dir/build/geodata"/*
}

create_pkg() {
  root_dir="$1"
  out_pkg="$2"

  # Create PKG installer
  pkgbuild \
    --version "$IMMICH_TAG" \
    --root "$root_dir" \
    --identifier com.unofficial.immich.installer \
    --scripts ./Scripts \
    --install-location "/" \
    "$out_pkg"
}

# Load configuration environment
set -a
# shellcheck disable=SC1091
. ./Scripts/config.env
set +a
pkg_filename="Unofficial Immich Installer $IMMICH_TAG.pkg"

# Create staging directories
output_dir="./output"
staging_dir="$output_dir/staging"
root_dir="$staging_dir/root"
dist_dir="$root_dir/$IMMICH_APP_DIR"
conf_dir="$root_dir/$IMMICH_SETTINGS_DIR"
rm -rf "$staging_dir"
mkdir -p "$staging_dir" "$root_dir" "$dist_dir" "$output_dir"

# Build Immich from source
clone_immich "$IMMICH_TAG" "$staging_dir/immich" "$conf_dir"
build_immich "$staging_dir/immich" "$dist_dir"
build_immich_machine_learning "$staging_dir/immich" "$dist_dir"
fetch_immich_geodata "$dist_dir"

# Fix paths in generated root directory
grep -rlI --null "$root_dir" "$root_dir" | xargs -0 sed -i "" "s|$(realpath "$root_dir")||g"

# Copy PKG resources
mkdir -p "$root_dir/Library/LaunchDaemons"
find ./launchd -type f -name "*.plist" | while read -r f; do
  filename="$(basename "$f")"
  envsubst < "$f" > "$root_dir/Library/LaunchDaemons/$filename"
done

# Create PKG installer
create_pkg "$root_dir" "$output_dir/$pkg_filename"
echo "macOS installer created successfully in $output_dir/$pkg_filename"
