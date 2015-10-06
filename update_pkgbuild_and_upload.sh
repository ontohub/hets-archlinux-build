#!/bin/bash

destination="${1:-uni:/home/wwwuser/eugenk/archlinux-aur/hets}"
base_dir="$(dirname $0)"
cd $base_dir

sync_to_remote() {
  rsync -avhP $(ls build/*.tar.gz) $destination
}

get_version() {
  ls -1 build/*.tar.gz | tail -1 | cut -d'-' -f2 | cut -d'.' -f1-2
}

get_shasum() {
  cat $(ls -1 build/*.tar.gz.sha1sum | tail -1)
}

edit_pkgbuild() {
  PKGBUILD="hets-pkg-files/PKGBUILD"
  ver=$1
  sha=$2
  if [ -z "$(which gsed)" ]; then
    sed -i "s/pkgver=.*/pkgver=$ver/g" $PKGBUILD
    sed -i "s/sha1sums=.*/sha1sums=('$sha')/g" $PKGBUILD
  else
    gsed -i "s/pkgver=.*/pkgver=$ver/g" $PKGBUILD
    gsed -i "s/sha1sums=.*/sha1sums=('$sha')/g" $PKGBUILD
  fi
}

version=$(get_version)
shasum=$(get_shasum)
edit_pkgbuild $version $shasum
sync_to_remote
