#! /bin/bash

real_dirname() {
  pushd $(dirname $1) > /dev/null
    local SCRIPTPATH=$(pwd -P)
  popd > /dev/null
  echo $SCRIPTPATH
}

script_dir=$(real_dirname $0)
source "$script_dir/functions.sh"

update_repository

build "hets-server"
create_package "hets-server"
build "hets"
create_package "hets"
