# Archlinux Build Files for Hets

This repository provides a docker instance to build Hets for Archlinux.
The built binary (plus a wrapper script) can be uploaded to the AUR by additional scripts brought to you here.

# Build Instructions

### Container Creation
At first run, create the docker container by executing
```
./create_container.sh
```
This script only creates the ready-to-build-Hets container with all the make-dependencies needed for hets.

### Consecutive Builds
##### Split Commands
Consecutive builds can be done by executing
```
./build_hets_packages.sh
```
which creates a new build in the shared directory.

Finally, the built tarballs are uploaded and the `PKGBUILD` files are updated and uploaded to the AUR by
```
./update_pkgbuild_and_aur.sh
```

This command optionally accepts a parameter for setting the `pkgrel` of the resulting `PKGBUILD`.
It defaults to `1` if not specified.
It is possible to pass it as command line argument or via environment variable:
```
./update_pkgbuild_and_aur.sh 2
PKGREL=2 ./update_pkgbuild_and_aur.sh
```
If both are specified, the command line argument takes precedence.

##### Single Command
The following script combines the last two scripts and can solely be used for consecutive builds instead:
```
./update_hets_packages.sh
```

# Build procedure and results explained
Building the Hets binaries is done inside the docker container.
The scripts used for building are made available to the container with the docker volume `./build_scripts`.
These scripts are not copied to the container - this directory gets bind-mounted into the container.
While building, docker accesses some resources for packaging located at the docker volume `./resources`.
The resulting tarballs are stored in a docker volume at `./packages`.
All this is done by the first script `.build_hets_packages.sh`.

The second script `./update_pkgbuild_and_aur.sh` executes almost everything on the host.
First, the latest tarballs from the `./package` directory are uploaded.
Second, the AUR repositories of the AUR-packages are fetched to the docker volume `./aur` and their `PKGBUILD` files are updated.
In this step, the docker instance is invoked once more to run `mksrcinfo` in each AUR repository (which is the only task in this script that is using docker).
Then the changes to the AUR repositories are committed and pushed to the AUR.
