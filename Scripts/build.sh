#!/bin/sh

set -eux

TMP="$(mktemp -d -t immich -p /tmp)"
chmod 755 "$TMP"

if [ -z "${IMMICH_USER:-}" ]; then
  # Load configuration when running as immich user with `sudo`
  # shellcheck disable=SC1091
  . "$(dirname "$0")/config.sh"
  export HOME="$IMMICH_HOME_DIR"
fi

if [ "$USER" != "$IMMICH_USER" ]; then
  echo "DEBUG: going to switch to immich user"

  # move to a place were immich has permission
  echo "DEBUG: copying scripts to accessible location"
  script="$TMP/$(basename "$0")"
  cp "$0" "config.sh" "$TMP"
  chown -R "$IMMICH_USER:$IMMICH_GROUP" "$TMP"

  # Re-run as immich user
  sudo -u "$IMMICH_USER" -- "$script"
  exit
fi

echo "INFO: building immich"

# Clone the remote repository
echo "INFO: cloning immich repo"
git clone --depth 1 --branch "$TAG" https://github.com/immich-app/immich "$TMP"
cd "$TMP"

# Build the server backend
echo "INFO: building the server"
cd server
npm ci
npm run build
npm prune --omit=dev --omit=optional
cd -

echo "INFO: building open-api"
cd open-api/typescript-sdk
npm ci
npm run build
cd -

# Build the web frontend
echo "INFO: building web"
cd web
npm ci
npm run build
cd -

# Copy application to the installation directory
echo "INFO: copying to destination directory"
rm -rf "$IMMICH_APP_DIR"
mkdir -p "$IMMICH_APP_DIR"
echo "{}" > "$IMMICH_APP_DIR/build-lock.json"
cp -a server/node_modules server/dist server/bin "$IMMICH_APP_DIR/"
cp -a web/build "$IMMICH_APP_DIR/www"
cp -a server/resources server/package.json server/package-lock.json "$IMMICH_APP_DIR/"
cp -a server/start*.sh "$IMMICH_APP_DIR/"
cp -a LICENSE "$IMMICH_APP_DIR/"

cd "$IMMICH_APP_DIR"
# v1.108.0 and above now loads geodata using IMMICH_BUILD_DATA env var, which appears to also
# be used in other places
ln -sf resources/* .
npm cache clean --force
npm install --os=darwin --cpu=arm64 sharp
cd -

# Build the machine learning backend
echo "INFO building machine learning"
alias python3=python3.11
alias pip3=pip3.11
mkdir -p "$IMMICH_APP_DIR/machine-learning"
python3 -m venv "$IMMICH_APP_DIR/machine-learning/venv"
(
  # Set up venv inside subshell
  # shellcheck disable=SC1091
  . "$IMMICH_APP_DIR/machine-learning/venv/bin/activate"
  pip3 install poetry
  cd machine-learning
  poetry install --no-root --with dev --with cpu || python3 -m pip install onnxruntime
)
cp -a machine-learning/ann machine-learning/app "$IMMICH_APP_DIR/machine-learning/"

ln -sf "$IMMICH_INSTALL_DIR/app/resources" "$IMMICH_INSTALL_DIR/"
mkdir -p "$IMMICH_INSTALL_DIR/cache"
sed -i "" -e "s|\"/cache\"|\"$IMMICH_INSTALL_DIR/cache\"|g" "$IMMICH_APP_DIR/machine-learning/app/config.py"
npm install sharp

# Install GeoNames
cd "$IMMICH_INSTALL_DIR/app/resources"
wget -o - https://download.geonames.org/export/dump/admin1CodesASCII.txt &
wget -o - https://download.geonames.org/export/dump/admin2Codes.txt &
wget -o - https://download.geonames.org/export/dump/cities500.zip &
wget -o - https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_admin_0_countries.geojson &
wait
unzip cities500.zip
rm cities500.zip
date -Iseconds | tr -d "\n" > geodata-date.txt
ln -s "$IMMICH_INSTALL_DIR/app/resources" "$IMMICH_INSTALL_DIR/app/geodata"

# Set up upload directory
mkdir -p "$IMMICH_INSTALL_DIR/upload"
ln -s "$IMMICH_INSTALL_DIR/upload" "$IMMICH_APP_DIR/"
ln -s "$IMMICH_INSTALL_DIR/upload" "$IMMICH_APP_DIR/machine-learning/"

# Create custom start scripts
cat <<EOF > "$IMMICH_APP_DIR/start.sh"
#!/bin/sh

set -eu

set -a
IMMICH_PORT="3001"
. "$IMMICH_INSTALL_DIR/env"
set +a

cd "$IMMICH_APP_DIR"
exec node "$IMMICH_APP_DIR/dist/main" "\$@"
EOF

cat <<EOF > "$IMMICH_APP_DIR/machine-learning/start.sh"
#!/bin/sh

set -eu

set -a
. "$IMMICH_INSTALL_DIR/env"
set +a

cd "$IMMICH_APP_DIR/machine-learning"
. venv/bin/activate

: "\${MACHINE_LEARNING_HOST:=127.0.0.1}"
: "\${MACHINE_LEARNING_PORT:=3003}"
: "\${MACHINE_LEARNING_WORKERS:=1}"
: "\${MACHINE_LEARNING_WORKER_TIMEOUT:=120}"

exec gunicorn app.main:app \\
      -k app.config.CustomUvicornWorker \\
      -w "\$MACHINE_LEARNING_WORKERS" \\
      -b "\$MACHINE_LEARNING_HOST:\$MACHINE_LEARNING_PORT" \\
      -t "\$MACHINE_LEARNING_WORKER_TIMEOUT" \\
      --log-config-json log_conf.json \\
      --graceful-timeout 0
EOF

cat <<EOF > "$IMMICH_INSTALL_DIR/env"
# You can find documentation for all the supported env variables at https://immich.app/docs/install/environment-variables

# Connection secret for postgres. You should change it to a random password
DB_PASSWORD="$DB_PASSWORD"

# The values below this line do not need to be changed
###################################################################################
NODE_ENV="production"

DB_USERNAME="immich"
DB_DATABASE_NAME="immich"
DB_VECTOR_EXTENSION="pgvector"

IMMICH_BUILD_DATA="$IMMICH_INSTALL_DIR/app"

# The location where your uploaded files are stored
UPLOAD_LOCATION="./library"

# The Immich version to use. You can pin this to a specific version like "v1.71.0"
IMMICH_VERSION="release"

# Hosts & ports
DB_HOSTNAME="127.0.0.1"
MACHINE_LEARNING_HOST="127.0.0.1"
IMMICH_MACHINE_LEARNING_URL="http://127.0.0.1:3003"
REDIS_HOSTNAME="127.0.0.1"
EOF

chmod 700 "$IMMICH_APP_DIR/start.sh"
chmod 700 "$IMMICH_APP_DIR/machine-learning/start.sh"

# Cleanup
rm -rf "$TMP"
