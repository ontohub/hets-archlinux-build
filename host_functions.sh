#!/bin/bash

real_dirname() {
  pushd $(dirname $1) > /dev/null
    local SCRIPTPATH=$(pwd -P)
  popd > /dev/null
  echo $SCRIPTPATH
}
base_dir=$(real_dirname $0)

version_prefix="-0.99_"
package_names=('hets-server' 'hets')
packages_target_dir="$base_dir/packages"
aur_base_dir="$base_dir/aur"
destination="uni:/home/wwwuser/eugenk/archlinux-aur"
container_base_dir="/root/hets"


docker_build_script_path() {
  echo "$container_base_dir/build_scripts"
}

docker_mksrcinfo_script_path() {
  echo "$(docker_build_script_path)/mksrcinfo.sh"
}

docker_map_host_to_container_path() {
  local host_path="$1"
  echo "$host_path" | sed "s#$base_dir#$container_base_dir#g"
}

# Run the docker instance with a given command.
# It sets up the volumes.
docker_run() {
  local command=$@
  local docker_repo="ontohub"
  local docker_image="hets-archlinux-build"
  local docker_tag="latest"

  docker run -v $base_dir/aur:$container_base_dir/aur -v $base_dir/build_scripts:$(docker_build_script_path) -v $base_dir/packages:$container_base_dir/packages -v $base_dir/resources:$container_base_dir/resources -t "$docker_repo/${docker_image}:${docker_tag}" $command
}


latest_tarball() {
  local package_name="$1"
  echo $(ls -1 $packages_target_dir/${package_name}${version_prefix}*.tar.gz | tail -1)
}

version() {
  local package_name="$1"
  local filepath="$(latest_tarball "$package_name")"
  local filename="$(basename "$filepath")"
  echo "${filename##*-}" | cut -d'.' -f1-2
}

shasum() {
  local package_name="$1"
  cat "$(latest_tarball "$package_name").sha1sum"
}

remote_url() {
  local package_name="$1"
  echo "$destination/$package_name/"
}

sync_to_remote() {
  local package_name="$1"
  scp "$PKGBUILD" "$(latest_tarball "$package_name")" "$(remote_url "$package_name")"
}

aur_git_url() {
  local package_name="$1"
  echo "ssh+git://aur@aur.archlinux.org/${package_name}.git"
}

local_aur_repository() {
  local package_name="$1"
  echo "$aur_base_dir/$package_name"
}

sync_repository() {
  local package_name="$1"
  local local_aur_repository_dir="$(local_aur_repository "$package_name")"
  if [ ! -d "$local_aur_repository_dir" ]
  then
    clone_repository "$package_name" "$local_aur_repository_dir"
  else
    pull_repository "$package_name"
  fi
}

clone_repository() {
  local package_name="$1"
  local local_aur_repository_dir="$2"
  local parent_dir="$(dirname "$local_aur_repository_dir")"

  if [ ! -d "$local_aur_repository_dir" ]; then
    mkdir -p "$parent_dir"
    pushd "$parent_dir" > /dev/null
      git clone "$(aur_git_url "$package_name")"
    popd > /dev/null
  fi
}

pull_repository() {
  local package_name="$1"
  pushd "$(local_aur_repository "$package_name")" > /dev/null
    git fetch
    git reset --hard origin/master
  popd > /dev/null
}

edit_pkgbuild() {
  local package_name="$1"
  local pkgrel="${2:-1}"

  local version="$(version "$package_name")"
  local shasum="$(shasum "$package_name")"
  local pkgbuild="$(local_aur_repository "$package_name")/PKGBUILD"

  if hash gsed 2>/dev/null
  then
    local sed=gsed
  else
    local sed=sed
  fi
  $sed -i "s/pkgver=.*/pkgver=$version/g" $pkgbuild
  $sed -i "s/pkgrel=.*/pkgrel=$pkgrel/g" $pkgbuild
  $sed -i "s/sha1sums=.*/sha1sums=('$shasum')/g" $pkgbuild
}

docker_mksricinfo() {
  local package_name="$1"

  local mksrcinfo_script_path="$(docker_mksrcinfo_script_path)"
  local dir="$(docker_map_host_to_container_path "$(local_aur_repository "$package_name")")"

  docker_run "$mksrcinfo_script_path" "$dir"
}

commit() {
  local package_name="$1"
  local pkgrel="${2:-1}"
  local version="$(version "$package_name")"

  pushd "$(local_aur_repository "$package_name")" > /dev/null
    docker_mksricinfo "$package_name"
    git add PKGBUILD .SRCINFO
    git commit -m "Update to ${version}-$pkgrel"
    git push
  popd > /dev/null
}
