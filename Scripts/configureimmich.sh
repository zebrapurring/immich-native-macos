#!/bin/sh

set -eux

# Create logs directory
mkdir -p /var/log/immich
chown -R "$IMMICH_USER:$IMMICH_GROUP" /var/log/immich

# Create media directory
mkdir -p "$IMMICH_MEDIA_DIR"

# Create custom start scripts
mkdir -p "$IMMICH_SETTINGS_DIR"
cat <<EOF > "$IMMICH_APP_DIR/start.sh"
#!/bin/sh
set -eu
set -a
. "$IMMICH_SETTINGS_DIR/immich_server.env"
set +a
cd "$IMMICH_APP_DIR"
exec node ./dist/main "\$@"
EOF
chmod 755 "$IMMICH_APP_DIR/start.sh"

cat <<EOF > "$IMMICH_APP_DIR/machine-learning/start.sh"
#!/bin/sh
set -eu
set -a
. "$IMMICH_SETTINGS_DIR/immich_server.env"
set +a
cd "$IMMICH_APP_DIR/machine-learning"
. ./.venv/bin/activate
: "\${MACHINE_LEARNING_HOST:=127.0.0.1}"
: "\${MACHINE_LEARNING_PORT:=3003}"
: "\${MACHINE_LEARNING_WORKERS:=1}"
: "\${MACHINE_LEARNING_WORKER_TIMEOUT:=120}"
exec gunicorn immich_ml.main:app \\
  -k immich_ml.config.CustomUvicornWorker \\
  -w "\$MACHINE_LEARNING_WORKERS" \\
  -b "\$MACHINE_LEARNING_HOST:\$MACHINE_LEARNING_PORT" \\
  -t "\$MACHINE_LEARNING_WORKER_TIMEOUT" \\
  --log-config-json log_conf.json \\
  --graceful-timeout 0
EOF
chmod 755 "$IMMICH_APP_DIR/machine-learning/start.sh"

if [ ! -f "$IMMICH_SETTINGS_DIR/immich_server.env" ]; then
  cp "$IMMICH_SETTINGS_DIR/build_info.env" "$IMMICH_SETTINGS_DIR/immich_server.env"
  cat <<EOF >> "$IMMICH_SETTINGS_DIR/immich_server.env"
# Network binding
IMMICH_HOST="127.0.0.1"
IMMICH_PORT="2283"
MACHINE_LEARNING_HOST="127.0.0.1"
MACHINE_LEARNING_PORT="3003"

# Production settings
NO_COLOR="false"
NODE_ENV="production"
IMMICH_ENV="production"

# Paths configuration
IMMICH_MEDIA_LOCATION="$IMMICH_MEDIA_DIR"
IMMICH_BUILD_DATA="$IMMICH_APP_DIR/build"
MACHINE_LEARNING_CACHE_FOLDER="$IMMICH_HOME_DIR/.immich-model-cache"

# Database connection
DB_HOSTNAME="localhost"
DB_USERNAME="immich"
DB_DATABASE_NAME="immich"
DB_PASSWORD="$POSTGRES_PASSWORD"
DB_VECTOR_EXTENSION="pgvector"

# Redis connection
REDIS_HOSTNAME="localhost"
EOF
fi

# Adjust permissions
chown -R "$IMMICH_USER:$IMMICH_GROUP" "$IMMICH_APP_DIR" "$IMMICH_SETTINGS_DIR"
