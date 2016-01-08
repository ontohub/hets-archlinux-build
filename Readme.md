# Archlinux Build Files for Hets

This repository provides a docker instance to build Hets for Archlinux.
The built binary (plus a wrapper script) can be uploaded to the AUR by additional scripts brought to you here.

# Build Instructions

### First Build
At first run, create the docker container by executing
```
./build_container.sh
```
This script initially builds Hets in the container and moves the built files to the shared directory `build`.

### Consecutive Builds
##### Split Commands
Consecutive builds can be done by executing
```
./create_updated_package.sh
```
which creates a new build in the shared directory.

Finally, the `hets-pkg-files/PKGBUILD` can be updated and uploaded to an external host and the AUR by
```
./update_pkgbuild_and_upload.sh
```

##### Single Command
The following script combines the last two scripts and can solely be used for consecutive builds instead:
```
./update_aur.sh
```
