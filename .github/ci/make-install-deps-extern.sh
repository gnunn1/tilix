#!/bin/sh
#
# Compile & Install Tilix build dependencies
#
set -e
set -x
export LANG=C.UTF-8

mkdir -p _tilix-deps && cd _tilix-deps

# GtkD
git clone --depth 1 https://github.com/gtkd-developers/GtkD.git gtkd
cd gtkd/

make -j"$(nproc)" \
    shared \
		prefix=/usr

make -j"$(nproc)" \
		install-shared \
		install-headers \
		prefix=/usr

cd ../

# cleanup
cd .. && rm -rf _tilix-deps
