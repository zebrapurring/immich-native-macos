# Native Immich installer for macOS

This repository provides a set of scripts that can be used to generate an unofficial package containing the prebuilt native Immich release for macOS.

The following steps are performed by the installer:

* Install dependencies with Homebrew (see [installdependencies.sh](./Scripts/installdependencies.sh))
* Create headless user `immich`
* Create PostgreSQL database `immich` and user `immich`
* Copy the Immich installation to `/opt/immich/share`
* Create Immich configuration in `/opt/immich/etc/immich_server.env`
* Create Launchd job configurations for Immich and the Machine Learning microservice in `/Library/LaunchDaemons`

## Notes

* Tested on macOS Sequoia with Apple Silicon
* Uses `pgvector` is used instead of `pgvecto.rs` to remove an additional Rust build dependency
* By default Immich listens to `0.0.0.0:2283` and the Machine Learning microservice listens to `0.0.0.0:3001`
* JPEG XL support may differ official Immich due to base-image's dependency differences

## Building the installer from source

1. Install [Homebrew](https://brew.sh)
    ```sh
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```
2. Install build dependencies
    ```sh
    brew install \
        node \
        npm \
        uv \
        vips
    ```
3. Build the package
    ```sh
    ./build_pkg.sh
    ```

## Uninstallation

The installation can be removed by running the [uninstall.sh](./uninstall.sh) script as a regular user.

Note that this will remove:

* The Launchd jobs
* The local `immich` user and group
* The Immich database and the PostgreSQL `immich` user
* The Immich installation directory, including the media directory

## References

For running Immich natively on other platforms, you can check out:

* Linux - [arter97's repo](https://github.com/arter97/immich-native)
* FreeBSD - [zebrapurring's IOCage plugin repo](https://github.com/zebrapurring/iocage-plugin-immich)
