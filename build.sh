TAG=v1.113.0
mkdir -p dist/$TAG
pkgbuild --version $TAG --root LaunchDaemons --identifier com.unofficial.immich.installer --scripts Scripts --install-location /Library/LaunchDaemons dist/$TAG/Unofficial\ Immich\ Installer.pkg
