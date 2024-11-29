#!/bin/sh

set -eu

install_logfile="/tmp/immich-install.log"
rm -f "$install_logfile"
touch "$install_logfile"
chmod 666 "$install_logfile"
open "$install_logfile"
