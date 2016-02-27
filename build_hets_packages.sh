#!/bin/bash

real_dirname() {
  pushd $(dirname $1) > /dev/null
    local SCRIPTPATH=$(pwd -P)
  popd > /dev/null
  echo $SCRIPTPATH
}
base_dir=$(real_dirname $0)
source "$base_dir/host_functions.sh"

docker_run "$(docker_build_script_path)/build_and_create_updated_package.sh"
