#!/bin/sh
set -e

# This script is supposed to run inside the Tilix Docker container
# on the CI system.

#
# Read options for the current test build
#

build_type=debugoptimized
build_dir="cibuild"

export DC=ldc2
echo "D compiler: $DC"
set -x
$DC --version

#
# Configure build with all flags enabled
#

mkdir $build_dir && cd $build_dir
meson --buildtype=$build_type \
      ..

#
# Build & Install
#

ninja
DESTDIR=/tmp/install_root/ ninja install
rm -r /tmp/install_root/
