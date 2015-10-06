#! /bin/bash

base_dir="$(realpath $(dirname $0)/..)"
hets_git="$base_dir/hets-git"
hets_pkg_files="$base_dir/hets-pkg-files"
hets_pkg_dir="$base_dir/hets-pkg"
hets_pkgbuild="$hets_pkg_files/PKGBUILD"
hets_testbuild="/tmp$base_dir/hets-testbuild"
hets_aur="$base_dir/hets-aur"

hets_version=master
hets_name_prefix="hets-"
hets_version_prefix="0.99_"

# This is copied with scp - one can use a remote host.
pkg_copy_target="$base_dir/hets-build"


function update_repository() {
  cd "$hets_git"
  git pull > /dev/null
  git checkout "$hets_version" > /dev/null
}

function build_hets() {
  cd "$hets_git"
  echo "Working on: $hets_revision"
  echo "Revision from: $hets_date"

  rm -f rev.txt

  cabal update
  cabal install
  make
  make initialize_java
}

function create_package() {
  cd "$hets_git"
  pkg_dir="$hets_pkg_dir/$hets_pkg_name"
  mkdir -p "$pkg_dir"
  mkdir -p "$pkg_dir/bin"
  mkdir -p "$pkg_dir/lib/hets-owl-tools/lib"

  cp "$hets_git/hets" "$pkg_dir/bin/hets-bin"
  cp "$hets_git/OWL2/OWL2Parser.jar" "$pkg_dir/lib/hets-owl-tools"
  cp "$hets_git/OWL2/OWLLocality.jar" "$pkg_dir/lib/hets-owl-tools"

  cp "$hets_git/DMU/OntoDMU.jar" "$pkg_dir/lib/hets-owl-tools"

  cp "$hets_git/CASL/Termination/AProVE.jar" "$pkg_dir/lib/hets-owl-tools"
  cp "$hets_git/OWL2/lib/owlapi-osgidistribution-3.5.2.jar" "$pkg_dir/lib/hets-owl-tools/lib"
  cp "$hets_git/OWL2/lib/guava-18.0.jar" "$pkg_dir/lib/hets-owl-tools/lib"
  cp "$hets_git/OWL2/lib/trove4j-3.0.3.jar" "$pkg_dir/lib/hets-owl-tools/lib"

  cp "$hets_git/magic/hets.magic" "$pkg_dir/lib"

  cp "$hets_pkg_files/hets-wrapper-script" "$pkg_dir/bin/hets"
  chmod +x "$pkg_dir/bin/hets"

  rel_tarfile="${hets_pkg_name}.tar.gz"

  pushd "$hets_pkg_dir"
    tar czf "${hets_pkg_name}.tar.gz" "$hets_pkg_name"
    rm -r "$pkg_dir"
    shasum=$(sha1sum "$rel_tarfile" | cut -d ' ' -f1)
  popd

  scp "${hets_pkg_dir}/${rel_tarfile}" "${pkg_copy_target}/${rel_tarfile}"
  echo $shasum > "${pkg_copy_target}/${rel_tarfile}.sha1sum"
}

function prepare_makepkg() {
  chgrp -R nobody .
  chmod -R g+ws .
  setfacl -R -m u::rwx,g::rwx .
  setfacl -R -d --set u::rwx,g::rwx,o::- .
}

# yet unused
function test_package() {
  cd "$hets_git"
  rm -rf "$hets_testbuild"
  mkdir -p "$hets_testbuild"

  pkgbuild="$hets_testbuild/PKGBUILD"

  cp "$hets_pkgbuild" "$pkgbuild"

  pkgver="${hets_version_prefix}${hets_date}"
  sed -i "s/^pkgver=.*$/pkgver=${pkgver}/" "$pkgbuild"
  sed -i "s/^sha1sums=.*$/sha1sums=('${shasum}')/" "$pkgbuild"

  pushd "$hets_testbuild"
    # will not try to compress the makepkg package
    prepare_makepkg
    PKGEXT='.pkg.tar' sudo -u nobody makepkg
    # mkaurball
  popd
}

# yet unused
function create_aur_package() {
  cd "$hets_git"
  mkdir -p "$hets_aur"
  cd "$hets_aur"
  cp "$pkgbuild" "$hets_aur/PKGBUILD"
  mksrcinfo
  git add PKGBUILD .SRCINFO
  git commit -m "Update to ${pkgver}."
  cd -
}
