#! /bin/bash

# base_dir is supposed to be /root/hets
base_dir="$(realpath $(dirname $0)/..)"
packages_target_dir="$base_dir/packages"

git_working_copy="$base_dir/hets-git"
git_reference="master"
version_prefix="-0.99_"

git_head_commit() {
  pushd "$git_working_copy" > /dev/null
    local result="$(git rev-parse HEAD)"
  popd > /dev/null
  echo "$result"
}

git_timestamp() {
  pushd "$git_working_copy" > /dev/null
    local result="$(git log -1 --format='%ct')"
  popd > /dev/null
  echo "$result"
}

full_package_name() {
  local package_name="${1:-hets}"
  echo "${package_name}${version_prefix}$(git_timestamp)"
}

update_repository() {
  pushd "$git_working_copy" > /dev/null
    git checkout master > /dev/null
    git pull > /dev/null
    git checkout "$git_reference" > /dev/null
  popd > /dev/null
}


# build requires one parameter:
# package_name (one of: hets, hets-server)
build() {
  local package_name="${1:-hets}"
  echo $package_name

  pushd "$git_working_copy" > /dev/null
    git checkout "$git_reference" > /dev/null
    echo "Working on: $(git_head_commit)"
    echo "Revision from: $(git_timestamp)"

    rm -f rev.txt

    cabal update
    if [ "$package_name" == "hets-server" ]
    then
      cabal install --only-dependencies -f server -f -gtkglade -f -uniform
    else
      cabal install --only-dependencies
    fi
    make $package_name
    make initialize_java
  popd > /dev/null
}

# create_package requires one parameter:
# package_name (one of: hets, hets-server)
create_package() {
  local package_name="${1:-hets}"
  local temp_package_dir="$(mktemp -d -t 'pkg-XXXXXXXX')"

  create_package_directory_contents "$package_name" "$temp_package_dir"
  create_tarball "$package_name" "$temp_package_dir"
  rm -rf "$temp_package_dir"
}

# create_package_directory_contents requires two arguments:
# package_name (one of: hets, hets-server)
# package_dir (the directory to push the package files into)
create_package_directory_contents() {
  local package_name="$1"
  local base_package_dir="$2"
  local executable_name="$package_name"
  local package_dir="$base_package_dir/$(full_package_name "$package_name")"

  # create package directory structure
  mkdir -p "$package_dir/bin"
  mkdir -p "$package_dir/lib/hets-owl-tools/lib"

  # copy over the built files
  pushd $package_dir > /dev/null
    pushd "bin" > /dev/null
      cp "$git_working_copy/$executable_name" "./${executable_name}-bin"
      cp "$base_dir/resources/$package_name/wrapper-script" "./$executable_name"
      chmod +x "./${executable_name}-bin"
      chmod +x "./$executable_name"
    popd > /dev/null

    pushd "lib" > /dev/null
      pushd "hets-owl-tools" > /dev/null
        pushd "lib" > /dev/null
          cp "$git_working_copy/OWL2/lib/guava-18.0.jar" .
          cp "$git_working_copy/OWL2/lib/owlapi-osgidistribution-3.5.2.jar" .
          cp "$git_working_copy/OWL2/lib/trove4j-3.0.3.jar" .
        popd > /dev/null
        cp "$git_working_copy/CASL/Termination/AProVE.jar" .
        cp "$git_working_copy/DMU/OntoDMU.jar" .
        cp "$git_working_copy/OWL2/OWL2Parser.jar" .
        cp "$git_working_copy/OWL2/OWLLocality.jar" .
      popd > /dev/null

      cp "$git_working_copy/magic/hets.magic" .
    popd > /dev/null
  popd > /dev/null
}

create_tarball() {
  local package_name="$1"
  local package_dir="$2"
  local tarball="$(full_package_name "$package_name").tar.gz"
  local shasum=""

  pushd "$package_dir"
    tar czf "$tarball" *
    shasum=$(sha1sum "$tarball" | cut -d ' ' -f1)
  popd
  echo $tarball
  echo $shasum

  mv "$package_dir/$tarball" "$packages_target_dir/$tarball"
  echo $shasum > "$packages_target_dir/${tarball}.sha1sum"
}
