TAG=v1.106.4
mkdir -p dist/$TAG
pkgbuild --version $TAG --root LaunchDaemons --identifier com.unofficial.immich.installer --scripts Scripts --install-location /Library dist/$TAG/Unofficial\ Immich\ Installer.pkg
