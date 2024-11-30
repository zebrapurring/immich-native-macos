#!/bin/sh

set -eux

echo "INFO: configure postgresql"

# Re-run script as appropriate user
if [ "$USER" != "$(whoami)" ]; then
  su -l "$USER" -c "$0 $*"
  exit
fi

DB_PASSWORD="$1"

psql-17 postgres << EOF
CREATE DATABASE immich;
CREATE USER immich WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE immich TO immich;
ALTER USER immich WITH SUPERUSER;
EOF
