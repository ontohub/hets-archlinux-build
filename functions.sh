#!/usr/bin/env bash

real_dirname() {
  pushd $(dirname $1) > /dev/null
    local SCRIPTPATH=$(pwd -P)
  popd > /dev/null
  echo $SCRIPTPATH
}
base_dir=$(real_dirname $0)

# Where the packages are uploaded to
remote_aur_package_host="uni"
remote_aur_package_dir="/home/wwwuser/eugenk/aur-hets"
remote_aur_package_root_url="http://www.informatik.uni-bremen.de/~eugenk/aur-hets"

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

ghc_prefix=`ghc --print-libdir | sed -e 's+/lib.*/.*++g'`
cabal_options="--force-reinstalls -p --global --prefix=$ghc_prefix"

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

install_hets_dependencies() {
  if [ -z "$(ghc-pkg list | grep " gtk-")" ]
  then
    eval "declare -A package_info="${1#*=}
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:
    cabal update
    cabal install alex happy $cabal_options
    cabal install gtk2hs-buildtools $cabal_options
    cabal install glib $cabal_options
    cabal install gtk $cabal_options
    local gladedir="$(mktemp -d)"
    git clone https://github.com/cmaeder/glade.git "$gladedir/glade"
    cabal install "$gladedir/glade/glade.cabal" $cabal_options --with-gcc=gcc
    rm -rf "$gladedir"
    cabal install --only-dependencies "${package_info[cabal_flags]}" $cabal_options
  fi
}

compile_package() {
  eval "declare -A package_info="${1#*=}

	if [[ -n "${package_info[make_compile_target]}" ]]
	then
    make ${package_info[make_compile_target]}
    strip ${package_info[binary]}
	fi
}

install_package_to_prefix() {
  eval "declare -A package_info="${1#*=}
	local package_dir=$(versioned_package_dir "$(declare -p package_info)")

  mkdir -p "$local_package_dir/$package_dir"
  rm -rf "$local_package_dir/$package_dir/*"
  rm -rf "$local_package_dir/$package_dir/.*"
  mkdir -p "$local_package_dir/$package_dir/usr"
  make ${package_info[make_install_target]} PREFIX="$local_package_dir/$package_dir/usr"
}

post_process_installation() {
  eval "declare -A package_info="${1#*=}
	local package_dir=$(versioned_package_dir "$(declare -p package_info)")

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
  if [ ! -d "$repo_dir" ]; then
    mkdir -p "$repo_parent_dir"
    pushd "$repo_parent_dir" > /dev/null
      git clone "$upstream_url" "$repo_dir"
    popd > /dev/null
  fi
}

pull_repository() {
  local repo_dir="$1"
  pushd "$repo_dir" > /dev/null
    git fetch
    git reset --hard origin/master
  popd > /dev/null
}

checkout_ref() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"
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
  pushd "$repo_dir" > /dev/null
    echo $(git log -1 --format='%H')
  popd > /dev/null
}

# execute AFTER compiling
hets_version_no() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"
  pushd "$repo_dir" > /dev/null
    cat version_nr
  popd > /dev/null
}

# execute AFTER compiling
hets_version_unix_timestamp() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"
  pushd "$repo_dir" > /dev/null
		echo $(git log -1 --format='%ct')
  popd > /dev/null
}

# execute AFTER compiling
hets_version() {
  eval "declare -A package_info="${1#*=}
  local version="$(hets_version_no "$(declare -p package_info)")"
  local timestamp="$(hets_version_unix_timestamp "$(declare -p package_info)")"
	echo "${version}_${timestamp}"
}


# --------- #
# Packaging #
# --------- #

package_source_application() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"

  pushd "$repo_dir" > /dev/null
    make rev.txt
  popd > /dev/null
}
package_application() {
  eval "declare -A package_info="${1#*=}
  local repo_dir="$local_upstream_repo_dir/${package_info[package_name]}"

  pushd "$repo_dir" > /dev/null
    case "${package_info[package_name]}" in
      "hets-commons-bin")
        make rev.txt
        ;;
      "hets-desktop-bin"|"hets-server-bin")
        install_hets_dependencies "$(declare -p package_info)"
        ;;
      *)
        ;;
    esac
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
	echo "${package_info[package_name]}-${version}-$pkgrel"
}

tarball_name() {
  eval "declare -A package_info="${1#*=}
  echo "$(versioned_package_dir "$(declare -p package_info)").tar.gz"
}

create_tarball() {
  eval "declare -A package_info="${1#*=}
	local package_dir="$(versioned_package_dir "$(declare -p package_info)")"
  local tarball="$(tarball_name "$(declare -p package_info)")"

  pushd "$local_package_dir" > /dev/null
    pushd "$package_dir" > /dev/null
      tar czf "$tarball" usr
      mv "$tarball" "$local_package_dir/"
    popd > /dev/null

    local shasum=$(shasum -a 256 "$tarball" | cut -d ' ' -f1)
    echo -n "$shasum" > "${tarball}.sha256sum"
  popd > /dev/null
}

tarball_shasum() {
  eval "declare -A package_info="${1#*=}
  local tarball="$(tarball_name "$(declare -p package_info)")"

  pushd "$local_package_dir" > /dev/null
    cat "${tarball}.sha256sum"
  popd > /dev/null
}

upload_tarball() {
  eval "declare -A package_info="${1#*=}
	local package_dir="$(versioned_package_dir "$(declare -p package_info)")"
  local tarball="$(tarball_name "$(declare -p package_info)")"

  pushd "$local_package_dir" > /dev/null
    ssh "$remote_aur_package_host" mkdir -p "$remote_aur_package_dir"
    scp "$tarball" \
      "${remote_aur_package_host}:${remote_aur_package_dir}"
  popd > /dev/null
}



# --------------- #
# Update PKGBUILD #
# --------------- #

patch_source_pkgbuild() {
  eval "declare -A package_info="${1#*=}
  local pkgbuild_file="$local_aur_repo_dir/${package_info[package_name]}/PKGBUILD"
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
  pushd "$local_aur_repo_dir/${package_info[package_name]}" > /dev/null
    git push
  popd > /dev/null
}
