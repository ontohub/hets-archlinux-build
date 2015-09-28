#! /bin/bash

base_dir="$(dirname \"$(realpath $0)\")/.."
hets_git="$base_dir/hets-git"
hets_pkg_files="$base_dir/hets-pkg-files"
hets_pkgbuild="$hets_pkg_files/PKGBUILD"
hets_testbuild="$base_dir/hets-testbuild"
hets_aur="$base_dir/hets_aur"

hets_version=master
hets_name_prefix="hets-"
hets_version_prefix="0.99_"

pkg_copy_target="server-address:/directory-path/hets/binaries"

cd "$hets_git"
git pull > /dev/null
git checkout "$hets_version" > /dev/null

hets_revision=`git rev-parse HEAD`
hets_date=`git log -1 --format='%ct'`
hets_pkg_name="${hets_name_prefix}${hets_version_prefix}${hets_date}"

echo "Working on: $hets_revision"
echo "Revision from: $hets_date"

rm -f rev.txt

make
make initialize_java

pkg_dir="$hets_pkg_dir/$hets_pkg_name"
mkdir -p "$pkg_dir"
mkdir -p "$pkg_dir/bin"
mkdir -p "$pkg_dir/lib/hets-owl-tools/lib"

cp "$hets_git/hets" "$pkg_dir/bin/hets-bin"
cp "$hets_git/OWL2/OWL2Parser.jar" "$pkg_dir/lib/hets-owl-tools"
cp "$hets_git/OWL2/OWLLocality.jar" "$pkg_dir/lib/hets-owl-tools"

cp "$hets_git/DMU/OntoDMU.jar" "$pkg_dir/lib/hets-owl-tools"

cp "$hets_git/CASL/Termination/AProVE.jar" "$pkg_dir/lib/hets-owl-tools"
cp "$hets_git/OWL2/lib/owl2api-bin.jar" "$pkg_dir/lib/hets-owl-tools/lib"

cp "$hets_git/magic/hets.magic" "$pkg_dir/lib"

cp "$hets_pkg_files/hets-wrapper-script" "$pkg_dir/bin/hets"
chmod +x "$pkg_dir/bin/hets"

rel_tarfile="${hets_pkg_name}.tar.gz"

pushd "$hets_pkg_dir"
  tar czf "${hets_pkg_name}.tar.gz" "$hets_pkg_name"
  rm -r "$pkg_dir"
  shasum=$(sha1sum "$rel_tarfile" | cut -d ' ' -f1)
popd

scp "${hets_pkg_dir}/${rel_tarfile}" "${pkg_copy_target}/${rel_tarfile}"

rm -rf "$hets_testbuild"
mkdir -p "$hets_testbuild"

pkgbuild="${hets_testbuild}/PKGBUILD"

cp "$hets_pkgbuild" "$pkgbuild"

pkgver="${hets_version_prefix}${hets_date}"
sed -i "s/^pkgver=.*$/pkgver=${pkgver}/" "$pkgbuild"
sed -i "s/^sha1sums=.*$/sha1sums=('${shasum}')/" "$pkgbuild"

pushd "$hets_testbuild"
  # will not try to compress the makepkg package
  PKGEXT='.pkg.tar' makepkg
  # mkaurball
popd

pushd "$hets_aur"
  cp "$pkgbuild" "$hets_aur/PKGBUILD"
  mksrcinfo
  git add PKGBUILD .SRCINFO
  git commit -m "Update to ${pkgver}."
popd
