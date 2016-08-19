#!/usr/bin/env bash

real_dirname() {
  pushd $(dirname $1) > /dev/null
    local SCRIPTPATH=$(pwd -P)
  popd > /dev/null
  echo $SCRIPTPATH
}
base_dir=$(real_dirname $0)

source "$base_dir/functions.sh"

set -x

sync_aur_repository "$(declare -p hets_commons_bin)"
sync_upstream_repository "$(declare -p hets_commons_bin)"
docker_run bash -c "./in_docker_package_application.sh 'hets_commons_bin'"
docker_run bash -c "./in_docker_patch_bin_pkgbuild.sh 'hets_commons_bin'"
upload_tarball "$(declare -p hets_commons_bin)"
commit_pkgbuild "$(declare -p hets_commons_bin)"

sync_aur_repository "$(declare -p hets_commons)"
sync_upstream_repository "$(declare -p hets_commons)"
docker_run bash -c "./in_docker_package_source_application.sh 'hets_commons'"
docker_run bash -c "./in_docker_patch_source_pkgbuild.sh 'hets_commons'"
commit_pkgbuild "$(declare -p hets_commons)"

sync_aur_repository "$(declare -p hets_desktop_bin)"
sync_upstream_repository "$(declare -p hets_desktop_bin)"
docker_run bash -c "./in_docker_package_application.sh 'hets_desktop_bin'"
docker_run bash -c "./in_docker_patch_bin_pkgbuild.sh 'hets_desktop_bin'"
upload_tarball "$(declare -p hets_desktop_bin)"
commit_pkgbuild "$(declare -p hets_desktop_bin)"

sync_aur_repository "$(declare -p hets_desktop)"
sync_upstream_repository "$(declare -p hets_desktop)"
docker_run bash -c "./in_docker_package_source_application.sh 'hets_desktop'"
docker_run bash -c "./in_docker_patch_source_pkgbuild.sh 'hets_desktop'"
commit_pkgbuild "$(declare -p hets_desktop)"

sync_aur_repository "$(declare -p hets_server_bin)"
sync_upstream_repository "$(declare -p hets_server_bin)"
docker_run bash -c "./in_docker_package_application.sh 'hets_server_bin'"
docker_run bash -c "./in_docker_patch_bin_pkgbuild.sh 'hets_server_bin'"
upload_tarball "$(declare -p hets_server_bin)"
commit_pkgbuild "$(declare -p hets_server_bin)"

sync_aur_repository "$(declare -p hets_server)"
sync_upstream_repository "$(declare -p hets_server)"
docker_run bash -c "./in_docker_package_source_application.sh 'hets_server'"
docker_run bash -c "./in_docker_patch_source_pkgbuild.sh 'hets_server'"
commit_pkgbuild "$(declare -p hets_server)"
