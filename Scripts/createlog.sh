#!/bin/sh

set -eux

install_logfile="$1"

echo >"$install_logfile"
chmod 644 "$install_logfile"
open "$install_logfile"
