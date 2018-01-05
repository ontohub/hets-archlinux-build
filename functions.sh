#!/usr/bin/env bash

real_dirname() {
  pushd $(dirname $1) > /dev/null
    local SCRIPTPATH=$(pwd -P)
  popd > /dev/null
  echo $SCRIPTPATH
}
base_dir=$(real_dirname $0)

debug_level=""
debug() {
  if [ -n $debug_level ]
  then
    # awk " BEGIN { print \"$@\" > \"/dev/fd/2\" }"
    echo "DEBUG: $@" >&2
  fi
}

# Where the packages are uploaded to
remote_aur_package_host="uni"
remote_aur_package_dir="/web/03_theo/sites/theo.iks.cs.ovgu.de/htdocs/downloads/hets/archlinux/x86_64"
remote_aur_package_root_url="http://hets.eu/downloads/hets/archlinux/x86_64"

# This file makes heavy use of passing associative arrays to functions.
#
# Usage in caller:
# my_function "$(declare -p my_associative_array)"
#
# Usage in function:
# eval "declare -A my_local_associative_array="${1#*=}
#
# See http://stackoverflow.com/a/8879444/2068056

# Declare associative arrays
declare -A hets_commons hets_desktop hets_server hets_commons_bin hets_desktop_bin hets_server_bin

hets_commons_bin[package_name]="hets-commons-bin"
hets_commons_bin[upstream_repository]="https://github.com/spechub/Hets.git"
hets_commons_bin[ref]="${REF_HETS_COMMONS_BIN:-origin/master}"
hets_commons_bin[pkgrel]="${REVISION_HETS_COMMONS_BIN:-1}"
hets_commons_bin[make_install_target]="install-common"

hets_desktop_bin[package_name]="hets-desktop-bin"
hets_desktop_bin[upstream_repository]="https://github.com/spechub/Hets.git"
hets_desktop_bin[ref]="${REF_HETS_DESKTOP_BIN:-origin/master}"
hets_desktop_bin[pkgrel]="${REVISION_HETS_DESKTOP_BIN:-1}"
hets_desktop_bin[make_compile_target]="hets.bin"
hets_desktop_bin[make_install_target]="install-hets"
hets_desktop_bin[executable]="hets"
hets_desktop_bin[binary]="hets.bin"
hets_desktop_bin[cabal_flags]=""

hets_server_bin[package_name]="hets-server-bin"
hets_server_bin[upstream_repository]="https://github.com/spechub/Hets.git"
hets_server_bin[ref]="${REF_HETS_SERVER_BIN:-origin/master}"
hets_server_bin[pkgrel]="${REVISION_HETS_SERVER_BIN:-1}"
hets_server_bin[make_compile_target]="hets_server.bin"
hets_server_bin[make_install_target]="install-hets_server"
hets_server_bin[executable]="hets-server"
hets_server_bin[binary]="hets_server.bin"
hets_server_bin[cabal_flags]="-f server -f -gtkglade -f -uniform"

hets_commons[package_name]="hets-commons"
hets_commons[upstream_repository]="https://github.com/spechub/Hets.git"
hets_commons[ref]="${REF_HETS_COMMONS:-origin/master}"
hets_commons[pkgrel]="${REVISION_HETS_COMMONS:-1}"

hets_desktop[package_name]="hets-desktop"
hets_desktop[upstream_repository]="https://github.com/spechub/Hets.git"
hets_desktop[ref]="${REF_HETS_DESKTOP:-origin/master}"
hets_desktop[pkgrel]="${REVISION_HETS_DESKTOP:-1}"

hets_server[package_name]="hets-server"
hets_server[upstream_repository]="https://github.com/spechub/Hets.git"
hets_server[ref]="${REF_HETS_SERVER-origin/master}"
hets_server[pkgrel]="${REVISION_HETS_SERVER:-1}"

local_upstream_repo_dir="$base_dir/upstream-repositories"
local_aur_repo_dir="$base_dir/aur-repositories"
local_package_dir="$base_dir/packages"

install_prefix="/usr"


# --------------------- #
# Docker host functions #
# --------------------- #

docker_container_base_dir="/root/hets/host"
docker_repo="ontohub"
docker_image="hets-archlinux-build"
docker_tag="latest"

# Run the docker instance with a given command.
# It sets up the volumes.
docker_run() {
  docker run -v ${base_dir}:$docker_container_base_dir -t "$docker_repo/${docker_image}:${docker_tag}" "$@"
}

docker_run_interactive() {
  docker run -i -v ${base_dir}:$docker_container_base_dir -t "$docker_repo/${docker_image}:${docker_tag}" "$@"
}



# ------------ #
# Build System #
# ------------ #

compile_package() {
  eval "declare -A package_info="${1#*=}

  case "${package_info[package_name]}" in
    "hets-desktop-bin"|"hets-server-bin")
      debug "make stack"
			make stack
			;;
    *)
      ;;
  esac

  debug "compile_package ${package_info[package_name]}"
	if [[ -n "${package_info[make_compile_target]}" ]]
	then
    debug "make ${package_info[make_compile_target]}"
    make ${package_info[make_compile_target]}
    strip ${package_info[binary]}
	fi
}

install_package_to_prefix() {
  eval "declare -A package_info="${1#*=}
	local package_dir=$(versioned_package_dir "$(declare -p package_info)")
  debug "install_package_to_prefix ${package_info[package_name]}"
  debug "install_package_to_prefix.package_dir: $package_dir"

  mkdir -p "$local_package_dir/$package_dir"
  rm -rf "$local_package_dir/$package_dir/*"
  rm -rf "$local_package_dir/$package_dir/.*"
  mkdir -p "$local_package_dir/$package_dir/usr"
  debug "install_package_to_prefix: make ${package_info[make_install_target]} PREFIX=$local_package_dir/$package_dir/usr"
  make ${package_info[make_install_target]} PREFIX="$local_package_dir/$package_dir/usr"
}

post_process_installation() {
  eval "declare -A package_info="${1#*=}
	local package_dir=$(versioned_package_dir "$(declare -p package_info)")
  debug "post_process_installation ${package_info[package_name]}"
  debug "post_process_installation.package_dir: $package_dir"

  case "${package_info[package_name]}" in
    "hets-desktop-bin"|"hets-server-bin")
			post_process_hets "$(declare -p package_info)" "$package_dir"
			;;
    *)
      ;;
  esac
}

# Patch the header of the wrapper script to include the (only working) locale,
# to use a shell that is certainly installed and to set the correct basedir.
post_process_hets() {
  eval "declare -A package_info="${1#*=}
  local package_dir="$2"
	local wrapper_script="bin/${package_info[executable]}"
  debug "post_process_installation ${package_info[package_name]}"
  debug "post_process_installation.package_dir: $package_dir"
  debug "post_process_installation.wrapper_script: $wrapper_script"

  pushd "$local_package_dir/$package_dir/usr" > /dev/null
    # Remove useless files that were added by the makefile's sed invocation
    rm -f "share/man/man1/hets.1e"
    rm -f "share/man/man1/hets.1-e"

    echo "#!/bin/bash"                            > "$wrapper_script.tmp"
    echo ""                                      >> "$wrapper_script.tmp"
    echo "export LANG=en_US.UTF-8"               >> "$wrapper_script.tmp"
    echo "export LANGUAGE=en_US.UTF-8"           >> "$wrapper_script.tmp"
    echo "export LC_ALL=en_US.UTF-8"             >> "$wrapper_script.tmp"
    echo ""                                      >> "$wrapper_script.tmp"
    echo "BASEDIR=\"/usr\""                      >> "$wrapper_script.tmp"
    echo "PROG=\"${package_info[executable]}\""  >> "$wrapper_script.tmp"

    # replace the script header with the above one
		sed -ie "/\/bin\/ksh93/,/PROG=/ d" "$wrapper_script"
		cat "$wrapper_script" >> "$wrapper_script.tmp"
		cat "$wrapper_script.tmp" > "$wrapper_script"
    rm -f "${wrapper_script}.tmp"
    rm -f "${wrapper_script}e"
    rm -f "${wrapper_script}-e"
  popd > /dev/null
}

# ---------------------- #
# Version Control System #
# ---------------------- #

aur_git_url() {
  eval "declare -A package_info="${1#*=}
  echo "ssh+git://aur@aur.archlinux.org/${package_info[package_name]}.git"
}

sync_upstream_repository() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"
  debug "sync_upstream_repository ${package_info[package_name]}"
  if [ ! -d "$repo_dir" ]
  then
    clone_repository "$repo_dir" "${package_info[upstream_repository]}"
  else
    pull_repository "$repo_dir"
  fi
  checkout_ref "$(declare -p package_info)"
}

sync_aur_repository() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_aur_repo_dir/${package_info[package_name]}"
  debug "sync_aur_repository ${package_info[package_name]}"
  debug "sync_aur_repository.repo_dir: $repo_dir"
  if [ ! -d "$repo_dir" ]
  then
    clone_repository "$repo_dir" "$(aur_git_url "$(declare -p package_info)")"
  else
    pull_repository "$repo_dir"
  fi
}

clone_repository() {
  local repo_dir="$1"
  local upstream_url="$2"
  local repo_parent_dir="$(dirname "$repo_path")"
  debug "clone_repository ${package_info[package_name]}"
  debug "clone_repository.repo_dir: $repo_dir"
  debug "clone_repository.upstream_url: $upstream_url"
  debug "clone_repository.repo_parent_dir: $repo_parent_dir"
  if [ ! -d "$repo_dir" ]; then
    mkdir -p "$repo_parent_dir"
    pushd "$repo_parent_dir" > /dev/null
      git clone "$upstream_url" "$repo_dir"
      git submodule update --init --recursive
    popd > /dev/null
  fi
}

pull_repository() {
  local repo_dir="$1"
  debug "pull_repository ${package_info[package_name]}"
  debug "pull_repository.repo_dir: $repo_dir"
  pushd "$repo_dir" > /dev/null
    git fetch
    git submodule update --recursive
    git reset --hard origin/master
  popd > /dev/null
}

checkout_ref() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"
  debug "checkout_ref ${package_info[package_name]}"
  debug "checkout_ref.repo_dir: $repo_dir"
  debug "checkout_ref.ref: ${package_info[ref]}"
  pushd "$repo_dir" > /dev/null
    git reset --hard ${package_info[ref]}
  popd > /dev/null
}


# --------------- #
# Version Numbers #
# --------------- #

# execute AFTER compiling
hets_version_commit_oid() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"
  debug "hets_version_commit_oid ${package_info[package_name]}"
  debug "hets_version_commit_oid.repo_dir: $repo_dir"
  pushd "$repo_dir" > /dev/null
    local result=$(git log -1 --format='%H')
    debug "hets_version_commit_oid.result: $result"
    echo $result
  popd > /dev/null
}

# execute AFTER compiling
hets_version() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"
  debug "hets_version ${package_info[package_name]}"
  debug "hets_version.repo_dir: $repo_dir"
  pushd "$repo_dir" > /dev/null
    local result="$(sed -n -e '/^hetsVersionNumeric =/ { s/.*"\([^"]*\)".*/\1/; p; q; }' Driver/Version.hs)"
    debug "hets_version.result: $result"
    echo $result
  popd > /dev/null
}


# --------- #
# Packaging #
# --------- #

package_source_application() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"
  debug "package_source_application ${package_info[package_name]}"
  debug "package_source_application.repo_dir: $repo_dir"
}

package_application() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"
  debug "package_application ${package_info[package_name]}"
  debug "package_application.repo_dir: $repo_dir"

  pushd "$repo_dir" > /dev/null
   make distclean
   compile_package "$(declare -p package_info)"
   install_package_to_prefix "$(declare -p package_info)"
   post_process_installation "$(declare -p package_info)"
    create_tarball "$(declare -p package_info)"
  popd > /dev/null
}

versioned_package_dir() {
  eval "declare -A package_info="${1#*=}
  local version="$(hets_version "$(declare -p package_info)")"
  local pkgrel="${package_info[pkgrel]}"
	local result="${package_info[package_name]}-${version}-$pkgrel"
  debug "versioned_package_dir ${package_info[package_name]}"
  debug "versioned_package_dir.version: $version"
  debug "versioned_package_dir.pkgrel: $pkgrel"
  debug "versioned_package_dir.result: $result"
  echo $result
}

tarball_name() {
  eval "declare -A package_info="${1#*=}
  local result="$(versioned_package_dir "$(declare -p package_info)").tar.gz"
  debug "tarball_name ${package_info[package_name]}"
  debug "tarball_name.result: $result"
  echo $result
}

create_tarball() {
  eval "declare -A package_info="${1#*=}
	local package_dir="$(versioned_package_dir "$(declare -p package_info)")"
  local tarball="$(tarball_name "$(declare -p package_info)")"
  debug "create_tarball ${package_info[package_name]}"
  debug "create_tarball.local_package_dir: $local_package_dir"
  debug "create_tarball.package_dir: $package_dir"
  debug "create_tarball.tarball: $tarball"

  pushd "$local_package_dir" > /dev/null
    pushd "$package_dir" > /dev/null
      tar czf "$tarball" usr
      mv "$tarball" "$local_package_dir/"
    popd > /dev/null

    local shasum=$(shasum -a 256 "$tarball" | cut -d ' ' -f1)
    debug "create_tarball.shasum: $shasum"
    echo -n "$shasum" > "${tarball}.sha256sum"
  popd > /dev/null
}

tarball_shasum() {
  eval "declare -A package_info="${1#*=}
  local tarball="$(tarball_name "$(declare -p package_info)")"
  debug "tarball_shasum ${package_info[package_name]}"
  debug "tarball_shasum.tarball: $tarball"

  pushd "$local_package_dir" > /dev/null
    local result="$(cat "${tarball}.sha256sum")"
    debug "tarball_shasum.result: $result"
    echo $result
  popd > /dev/null
}

upload_tarball() {
  eval "declare -A package_info="${1#*=}
	local package_dir="$(versioned_package_dir "$(declare -p package_info)")"
  local tarball="$(tarball_name "$(declare -p package_info)")"
  debug "upload_tarball ${package_info[package_name]}"
  debug "upload_tarball.package_dir: $package_dir"
  debug "upload_tarball.tarball: $tarball"

  pushd "$local_package_dir" > /dev/null
    debug "ssh $remote_aur_package_host mkdir -p $remote_aur_package_dir"
    ssh "$remote_aur_package_host" mkdir -p "$remote_aur_package_dir"
    debug "scp $tarball ${remote_aur_package_host}:${remote_aur_package_dir}"
    scp "$tarball" "${remote_aur_package_host}:${remote_aur_package_dir}"
  popd > /dev/null
}



# --------------- #
# Update PKGBUILD #
# --------------- #

patch_source_pkgbuild() {
  eval "declare -A package_info="${1#*=}
  local pkgbuild_file="$local_aur_repo_dir/${package_info[package_name]}/PKGBUILD"
  debug "patch_source_pkgbuild ${package_info[package_name]}"
  debug "patch_source_pkgbuild.pkgbuild_file: $pkgbuild_file"
  pushd "$(dirname "$pkgbuild_file")" > /dev/null
    sed -i "s/pkgver=.*/pkgver=$(hets_version "$(declare -p package_info)")/" "$pkgbuild_file"
    sed -i "s/pkgrel=.*/pkgrel=${package_info[pkgrel]}/" "$pkgbuild_file"
    sed -i "s/_commit=.*/_commit='$(hets_version_commit_oid "$(declare -p package_info)")'/" "$pkgbuild_file"
    mksrcinfo
  popd > /dev/null
}

patch_bin_pkgbuild() {
  eval "declare -A package_info="${1#*=}
  local pkgbuild_file="$local_aur_repo_dir/${package_info[package_name]}/PKGBUILD"
  local tarball="$(tarball_name "$(declare -p package_info)")"
  debug "patch_bin_pkgbuild ${package_info[package_name]}"
  debug "patch_bin_pkgbuild.pkgbuild_file: $pkgbuild_file"
  debug "patch_bin_pkgbuild.tarball: $tarball"
  pushd "$(dirname "$pkgbuild_file")" > /dev/null
    sed -i "s/pkgver=.*/pkgver=$(hets_version "$(declare -p package_info)")/" "$pkgbuild_file"
    sed -i "s/pkgrel=.*/pkgrel=${package_info[pkgrel]}/" "$pkgbuild_file"
    sed -i "s#source=.*#source=('$remote_aur_package_root_url/$tarball')#" "$pkgbuild_file"
    sed -i "s/sha256sums=.*/sha256sums=('$(tarball_shasum "$(declare -p package_info)")')/" "$pkgbuild_file"
    mksrcinfo
  popd > /dev/null
}

commit_pkgbuild() {
  eval "declare -A package_info="${1#*=}
  local pkgbuild_file="$local_aur_repo_dir/${package_info[package_name]}/PKGBUILD"
  local srcinfo_file="$local_aur_repo_dir/${package_info[package_name]}/.SRCINFO"
  debug "commit_pkgbuild ${package_info[package_name]}"
  debug "commit_pkgbuild.pkgbuild_file: $pkgbuild_file"
  debug "commit_pkgbuild.srcinfo_file: $srcinfo_file"
  pushd "$(dirname "$pkgbuild_file")" > /dev/null
    git add $pkgbuild_file $srcinfo_file
    git commit -m "Update ${package_info[package_name]} to $(hets_version "$(declare -p package_info)")-${package_info[pkgrel]}"
  popd > /dev/null
}



# ---------- #
# Publishing #
# ---------- #

push_formula_changes() {
  eval "declare -A package_info="${1#*=}
  debug "push_formula_changes ${package_info[package_name]}"
  pushd "$local_aur_repo_dir/${package_info[package_name]}" > /dev/null
    git push
  popd > /dev/null
}
