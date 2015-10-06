#! /bin/bash

script_dir="$(dirname $0)"
source "$script_dir/functions.sh"

update_repository

cd "$hets_git"
hets_revision="$(git rev-parse HEAD)"
hets_date="$(git log -1 --format='%ct')"
hets_pkg_name="${hets_name_prefix}${hets_version_prefix}${hets_date}"

build_hets
create_package
