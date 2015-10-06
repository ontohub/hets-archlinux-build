#!/bin/bash

base_dir="/tmp/hets"
deps_dir="$base_dir/hets-dependencies"

function set_permissions() {
  group_name="$1"
  dir="$2"
  chgrp -R $group_name $dir
  chmod -R g+ws $dir
  setfacl -R -m u::rwx,g::rwx $dir
  setfacl -R -d --set u::rwx,g::rwx,o::- $dir
}

function make_pkg() {
  name="$1"
  pkgbuild_url="$2"
  dir="$deps_dir/$name"

  mkdir -p $dir
  cd $dir
  curl -L $pkgbuild_url > "PKGBUILD"

  set_permissions "nobody" "."
  sudo -u nobody makepkg -s --noconfirm
  pacman -U --noconfirm $(ls *.pkg.tar.xz | tail -1)
  cd -
}

function create_dependencies_dir() {
  mkdir -p $deps_dir
  set_permissions "nobody" $deps_dir
}

create_dependencies_dir

# AUR package manager
make_pkg "aura-bin" "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=aura-bin"

# Actual Hets dependencies
make_pkg "hets-lib" "https://raw.githubusercontent.com/ontohub/hets-build/master/hets-lib/PKGBUILD"
make_pkg "pellet" "https://github.com/aur-archive/pellet/raw/master/PKGBUILD"
make_pkg "spass" "https://github.com/aur-archive/spass/raw/master/PKGBUILD"
make_pkg "darwin" "https://raw.githubusercontent.com/aur-archive/darwin/master/PKGBUILD"
sudo -u nobody sudo aura -A --noconfirm udrawgraph eprover
