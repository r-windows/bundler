#!/bin/sh
set -e

prepare_pacman(){
  cp -f pacman.conf /etc/pacman.conf
  pacman -Scc --noconfirm
  pacman -Syy --noconfirm
}

arch_prefix(){
  echo "$1" | sed "s/[^ ]* */mingw-w64-${arch}-&/g"
}

download_libs(){
  pkg=$(arch_prefix $package)
  version=$(pacman -Si $pkg  | grep -m 1 '^Version' | awk '/^Version/{print $3}' | cut -d '-' -f1)
  echo "Bundling: $pkg $version"

  # Find dependencies
  if [ "$deps" ]; then
    pkgdeps=$(arch_prefix $deps)
  else
    pkgdeps=$(pacman -Si $pkg | grep -m 1 'Depends On' | grep -o 'mingw-w64-[_.a-z0-9-]*' || true)
  fi

  # Prep output dir
  bundle="$package-$version-$arch"
  dist="$PWD/dist"
  rm -Rf $bundle
  mkdir -p $dist $bundle/lib

  # Tmp download dir
  OUTPUT=$(mktemp -d)
  URLS=$(pacman -Sp $pkg $pkgdeps --cache=$OUTPUT)
  for URL in $URLS; do
    curl -OLs $URL
    FILE=$(basename $URL)
    echo "Extracting: $FILE"
    echo " - $FILE" >> $bundle/files.md
    tar xf $FILE -C ${OUTPUT}
    unlink $FILE
  done

  # Extract files
  cp -Rv ${OUTPUT}/*/include $bundle/
  rm -f ${OUTPUT}/*/lib/*.dll.a
  cp -v ${OUTPUT}/*/lib/*.a $bundle/lib/
  cp -Rf ${OUTPUT}/*/lib/pkgconfig $bundle/lib/ || true
  tar cfJ "$dist/$bundle.tar.xz" $bundle
  rm -Rf $bundle
}

create_bundles() {
  prepare_pacman
  arch="ucrt-x86_64" download_libs
  arch="clang-aarch64" download_libs

  # Set success variables
  if [ "$GITHUB_OUTPUT" ]; then
    echo "version=$version" >> $GITHUB_OUTPUT
  fi
}
