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
create database immich;
create user immich with encrypted password '$DB_PASSWORD';
grant all privileges on database immich to immich;
ALTER USER immich WITH SUPERUSER;
EOF
