# Archlinux Build Files for Hets

This repository provides a docker instance to build Hets for Archlinux.
The built binary (plus a wrapper script) can be uploaded to the AUR by additional scripts brought to you here.

# Build Instructions

### Container Creation
At first run, create the docker container by executing
```
./create_container.sh
```
This script only creates the ready-to-build-Hets container with all the make-dependencies needed for Hets.

### Build and Update the PKGBUILD
##### Split Commands
The Hets packages are built and their PKGBUILD files are updated by the command
```
./update_hets_packages.sh
```
The commits/refs that shall be checked out can be set via environment variables as can the releases (`pkgrel`).
Setting, e.g., these environment variables
```
REF_HETS_COMMONS_BIN=0123456789abcdefabcd0123456789abcdefabcd
REVISION_HETS_COMMONS_BIN=2
```
the script will check out the commit `0123456789abcdefabcd0123456789abcdefabcd` of the Hets upstream repository and write `pkgrel=2` to the PKGBUILD.
Instead of `HETS_COMMONS_BIN`, you can also specify `HETS_DESKTOP_BIN` and `HETS_SERVER_BIN`, as well as the same ones without the `_BIN` suffix.

What happens there is:
* The AUR-repository of the package is retrieved to `aur-repositories/$package_name` on the host system.
* The upstream repository of the package is retrieved to `upstream-repositories/$package_name` and the given reference is checked out (defaults to `origin/master`) on the host system.
* If it is a `*-bin` package, the application is built and its tarball is packed inside the docker instance.
If it is not a `*-bin` package, the version info file is created inside the docker instance.
* The PKGBUILD and .SRCINFO are patched inside the docker instance.
* The changes of the PKGBUILD and the .SRCINFO are committed on the host system.

The committed changes are *not* pushed to the AUR. This must be done manually to allow verifying the results.
