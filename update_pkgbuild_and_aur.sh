#!/bin/bash

real_dirname() {
  pushd $(dirname $1) > /dev/null
    local SCRIPTPATH=$(pwd -P)
  popd > /dev/null
  echo $SCRIPTPATH
}
base_dir=$(real_dirname $0)
source "$base_dir/host_functions.sh"

# PKGREL precedence:
# * first command line parameter
# * PKGREL environment variable
# * default value "1"
PKGREL="${1:-${PKGREL:-1}}"

for package_name in "${package_names[@]}"
do
  sync_to_remote "$package_name"
  sync_repository "$package_name"
  edit_pkgbuild "$package_name" "$PKGREL"
  commit "$package_name" "$PKGREL"
done
