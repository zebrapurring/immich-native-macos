. ./Scripts/config.sh

# TAG=v1.117.0

if [ -z "$TAG" ]; then
  echo "DEBUG: config not working"
  exit 1
fi

mkdir -p dist/$TAG
pkgbuild --version $TAG --root LaunchDaemons --identifier com.unofficial.immich.installer --scripts Scripts --install-location /Library/LaunchDaemons dist/$TAG/Unofficial\ Immich\ Installer.pkg

# need to increase script timeouts
cd "dist/$TAG"
pkgutil --expand Unofficial\ Immich\ Installer.pkg contents
sed -i ".bak" -e 's/300/3600/g' contents/PackageInfo
rm contents/Bom
mkbom contents contents/Bom
pkgutil --flatten contents Unofficial\ Immich\ Installer.pkg
rm -rf contents
cd -
