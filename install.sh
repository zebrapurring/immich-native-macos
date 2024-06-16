#!/bin/bash

set -xeuo pipefail

TAG=v1.106.4

UNAME=$(uname)
IMMICH_PATH=/opt/services/immich
APP=$IMMICH_PATH/app
REALUSER=$(who am i | cut -f 1 -d ' ')
PASSWD=$(date +%s)
BASEDIR=$(dirname "$0")

function createUser {
	echo "INFO: creating immich user"
  sudo -u immich echo 2> /dev/null || (
    dscl . -create "/Groups/immich" && \
    dscl . -create "/Groups/immich" RealName immich && \
    dscl . -create "/Groups/immich" passwd "*" && \
    dscl . -create "/Groups/immich" gid 9999 && \
    dscl . -create "/Users/immich" && \
    dscl . -create "/Users/immich" UserShell /sbin/nologin && \
    dscl . -create "/Users/immich" RealName immich && \
    dscl . -create "/Users/immich" UniqueID 9999 && \
    dscl . -create "/Users/immich" PrimaryGroupID 9999 && \
    dscl . -create "/Users/immich" NFSHomeDirectory "$HOME" && \
    dscl . -create "/Users/immich" passwd "*" && \
    dscl . -create "/Groups/immich" GroupMembership immich
  )
}

function uninstallDaemons {
  echo "INFO: uninstalling daemons"
  for i in com.immich*.plist; do
    [ -f /Library/LaunchDaemons/$i ] && \
      sudo launchctl unload -w /Library/LaunchDaemons/$i && \
      rm -f /Library/LaunchDaemons/$i
  done || true
}

function installDaemons {
  echo "INFO: installing daemons"
  cp com.immich*plist /Library/LaunchDaemons/ && \
    launchctl load -w /Library/LaunchDaemons/com.immich.plist && \
    launchctl load -w /Library/LaunchDaemons/com.immich.machine.learning.plist
}

function installDependencies {
  echo "INFO: installing dependencies"
  cd /tmp/
  brew install postgresql && \
    brew install pgvector node redis && \
    brew install ffmpeg vips wget npm
  brew services restart postgresql
  brew services restart redis
  cd -
}

function configurePostgresql {
  echo "INFO: configuring postgresql"
  psql postgres << EOF
create database immich;
create user immich with encrypted password '$PASSWD';
grant all privileges on database immich to immich;
ALTER USER immich WITH SUPERUSER;
EOF
}

function createImmichPaths {
	echo "INFO: creating immich paths"
  sudo mkdir -p $IMMICH_PATH
  sudo chown immich:immich $IMMICH_PATH
  sudo mkdir -p /var/log/immich
  sudo chown immich:immich /var/log/immich
}

if [[ "$USER" == "$REALUSER" ]]; then
  installDependencies
  configurePostgresql

  echo "INFO: Restarting the script as root"
  sudo -u root $0 $*
  exit
fi

if [[ "$USER" == "root" ]]; then
  uninstallDaemons
  createUser
  createImmichPaths

  echo "Restarting the script as user immich"
  sudo -u immich $0 $* 2> /dev/null && installDaemons
  exit 
fi

if [[ "$USER" == "immich" ]]; then
	cd /tmp/ 2> /dev/null
  umask 077

  rm -rf $APP
  mkdir -p $APP

  # Wipe npm, pypoetry, etc
  # This expects immich user's home directory to be on $IMMICH_PATH/home
  rm -rf $IMMICH_PATH/home
  mkdir -p $IMMICH_PATH/home
  echo 'umask 077' > $IMMICH_PATH/home/.bashrc

  export HOME=$IMMICH_PATH/home

  TMP="/tmp/immich-$(uuidgen)"
  git clone https://github.com/immich-app/immich $TMP
  cd $TMP
  git reset --hard $TAG

  # immich-server
  cd server
  npm ci
  npm run build
  npm prune --omit=dev --omit=optional
  cd -

  cd open-api/typescript-sdk
  npm ci
  npm run build
  cd -

  cd web
  npm ci
  npm run build
  cd -

  cp -a server/node_modules server/dist server/bin $APP/
  cp -a web/build $APP/www
  cp -a server/resources server/package.json server/package-lock.json $APP/
  cp -a server/start*.sh $APP/
  cp -a LICENSE $APP/
  cd $APP
  npm cache clean --force
  cd -

  # immich-machine-learning
  mkdir -p $APP/machine-learning
  python3 -m venv $APP/machine-learning/venv
  (
    # Initiate subshell to setup venv
    . $APP/machine-learning/venv/bin/activate
    pip3 install poetry
    cd machine-learning
    if python -c 'import sys; exit(0) if sys.version_info.major == 3 and sys.version_info.minor > 11 else exit(1)'; then
      echo "Python > 3.11 detected, forcing poetry update"
      # Allow Python 3.12 (e.g., Ubuntu 24.04)
      sed -i -e 's/<3.12/<4/g' pyproject.toml
      poetry update
    fi
    poetry install --no-root --with dev --with cpu
    cd ..
  )
  cp -a machine-learning/ann machine-learning/start.sh machine-learning/app $APP/machine-learning/

  # Replace /usr/src
  cd $APP
  grep -Rl /usr/src | xargs -n1 sed -i -e "s@/usr/src@$IMMICH_PATH@g"
  ln -sf $IMMICH_PATH/app/resources $IMMICH_PATH/
  mkdir -p $IMMICH_PATH/cache
  sed -i -e "s@\"/cache\"@\"$IMMICH_PATH/cache\"@g" $APP/machine-learning/app/config.py

  # Install GeoNames
  cd $IMMICH_PATH/app/resources
  wget -o - https://download.geonames.org/export/dump/admin1CodesASCII.txt &
  wget -o - https://download.geonames.org/export/dump/admin2Codes.txt &
  wget -o - https://download.geonames.org/export/dump/cities500.zip &
  wait
  unzip cities500.zip

  date -Iseconds | tr -d "\n" > geodata-date.txt

  rm cities500.zip

  # Install sharp
  cd $APP
  npm install sharp

  # Setup upload directory
  mkdir -p $IMMICH_PATH/upload
  ln -s $IMMICH_PATH/upload $APP/
  ln -s $IMMICH_PATH/upload $APP/machine-learning/

  # Use 127.0.0.1
  sed -i -e "s@app.listen(port)@app.listen(port, '127.0.0.1')@g" $APP/dist/main.js

  # Custom start.sh script
  cat <<EOF > $APP/start.sh
#!/bin/bash

export HOME=$IMMICH_PATH/home
export PATH=\$PATH:/usr/local/bin

set -a
. $IMMICH_PATH/env
set +a

cd $APP
exec node $APP/dist/main "\$@"
EOF

  cat <<EOF > $APP/machine-learning/start.sh
#!/bin/bash

export HOME=$IMMICH_PATH/home
export PATH=\$PATH:/usr/local/bin

set -a
. $IMMICH_PATH/env
set +a

cd $APP/machine-learning
. venv/bin/activate

: "\${MACHINE_LEARNING_HOST:=127.0.0.1}"
: "\${MACHINE_LEARNING_PORT:=3003}"
: "\${MACHINE_LEARNING_WORKERS:=1}"
: "\${MACHINE_LEARNING_WORKER_TIMEOUT:=120}"

exec gunicorn app.main:app \
        -k app.config.CustomUvicornWorker \
        -w "\$MACHINE_LEARNING_WORKERS" \
        -b "\$MACHINE_LEARNING_HOST":"\$MACHINE_LEARNING_PORT" \
        -t "\$MACHINE_LEARNING_WORKER_TIMEOUT" \
        --log-config-json log_conf.json \
        --graceful-timeout 0
EOF

  cat <<EOF > $IMMICH_PATH/env
# You can find documentation for all the supported env variables at https://immich.app/docs/install/environment-variables

# Connection secret for postgres. You should change it to a random password
DB_PASSWORD=$PASSWD

# The values below this line do not need to be changed
###################################################################################
NODE_ENV=production

DB_USERNAME=immich
DB_DATABASE_NAME=immich
DB_VECTOR_EXTENSION=pgvector

# The location where your uploaded files are stored
UPLOAD_LOCATION=./library

# The Immich version to use. You can pin this to a specific version like "v1.71.0"
IMMICH_VERSION=release

# Hosts & ports
DB_HOSTNAME=127.0.0.1
MACHINE_LEARNING_HOST=127.0.0.1
IMMICH_MACHINE_LEARNING_URL=http://127.0.0.1:3003
REDIS_HOSTNAME=127.0.0.1
EOF

  # Cleanup
  rm -rf $TMP
fi
