#!/bin/bash

base_dir="$(realpath $(dirname $0))"
repo=ontohub
image=hets-build
tag="${1:-latest}"

docker build -t "${repo}/${image}:${tag}" $base_dir
