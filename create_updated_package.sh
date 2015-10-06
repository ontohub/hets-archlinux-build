#!/bin/bash

base_dir="$(realpath $(dirname $0))"
repo=ontohub
image=hets-build
tag="${1:-latest}"

docker run -v $base_dir/build:/root/hets/hets-build -t "${repo}/${image}:${tag}" /root/hets/scripts/build_and_create_updated_package.sh
