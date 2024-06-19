#!/bin/sh

echo "INFO: configure postgresql"

ME=$(whoami)

if [ "$USER" != "$ME" ]; then
  sudo -u $USER "$0" $* || exit 1
else
  PASSWD=$1
  [ -z "$PASSWD" ] && exit 1

  export PATH=/usr/local/bin:$PATH

  psql postgres << EOF
create database immich;
create user immich with encrypted password '$1';
grant all privileges on database immich to immich;
ALTER USER immich WITH SUPERUSER;
EOF

fi
exit 0
