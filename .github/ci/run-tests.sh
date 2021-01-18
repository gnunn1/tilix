#!/bin/sh
set -e

# This script is supposed to run inside the Tilix Docker container
# on the CI system.

#
# Read options for the current test run
#

export DC=ldc2
build_dir="cibuild"

#
# Run tests
#

cd $build_dir
meson test --print-errorlogs
