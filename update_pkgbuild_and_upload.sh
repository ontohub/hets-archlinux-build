#!/bin/bash

destination="${1:-uni:/home/wwwuser/eugenk/archlinux-aur/hets}"
PKGREL="${PKGREL:-1}"
base_dir="$(dirname $0)"
cd $base_dir
PKGBUILD="$base_dir/hets-pkg-files/PKGBUILD"

REPOSITORY_URL="https://aur.archlinux.org/hets.git"
PACKAGE_REPOSITORY="$base_dir/hets-package-repository"

sync_to_remote() {
  rsync -avhP $PKGBUILD $(ls build/*.tar.gz) $destination
}

get_version() {
  ls -1 build/*.tar.gz | tail -1 | cut -d'-' -f2 | cut -d'.' -f1-2
}

get_shasum() {
  cat $(ls -1 build/*.tar.gz.sha1sum | tail -1)
}

edit_pkgbuild() {
  ver=$1
  sha=$2
  if hash gsed 2>/dev/null
  then
    gsed -i "s/pkgver=.*/pkgver=$ver/g" $PKGBUILD
    gsed -i "s/sha1sums=.*/sha1sums=('$sha')/g" $PKGBUILD
  else
    sed -i "s/pkgver=.*/pkgver=$ver/g" $PKGBUILD
    sed -i "s/sha1sums=.*/sha1sums=('$sha')/g" $PKGBUILD
  fi
}

sync_repository() {
  if [ -d "$PACKAGE_REPOSITORY" ]
  then
    cd $PACKAGE_REPOSITORY
    git fetch
    git reset --hard origin/master
    cd -
  else
    git clone $REPOSITORY_URL $PACKAGE_REPOSITORY
  fi
}

install_mksrcinfo() {
  if !(hash mksrcinfo 2>/dev/null)
  then
    echo ""
    echo "mksrcinfo not installed."
    echo "Installing pkgbuild-introspection for mksrcinfo."
    sudo pacman -S pkgbuild-introspection
  fi
}

commit() {
  pkgver=$1
  pkgrel="${2:-1}"

  cd $PACKAGE_REPOSITORY
  mksrcinfo
  git add PKGBUILD .SRCINFO
  git commit -m "Update to $pkgver-$pkgrel"
  git push
  cd -
}

manage_package_repository() {
  pkgver=$1
  sync_repository
  cp $PKGBUILD $PACKAGE_REPOSITORY
  install_mksrcinfo
  commit $pkgver
}

version=$(get_version)
shasum=$(get_shasum)
edit_pkgbuild $version $shasum
sync_to_remote
manage_package_repository $version $PKGREL
