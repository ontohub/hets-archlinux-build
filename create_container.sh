#!/bin/bash

real_dirname() {
  pushd $(dirname $1) > /dev/null
  local SCRIPTPATH=$(pwd -P)
  popd > /dev/null
  echo $SCRIPTPATH
}

base_dir=$(real_dirname $0)
repo=ontohub
image=hets-archlinux-build
tag="${1:-latest}"

docker build -t "${repo}/${image}:${tag}" $base_dir
