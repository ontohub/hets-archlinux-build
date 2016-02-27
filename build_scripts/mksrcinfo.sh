#! /bin/bash

run_mksrcinfo() {
  local dir="$1"
  pushd "$dir" > /dev/null
    mksrcinfo
  popd > /dev/null
}

run_mksrcinfo "$@"
