#!/bin/sh
#
# Install Tilix build dependencies
#
set -e
set -x

export DEBIAN_FRONTEND=noninteractive

# update caches
apt-get update -qq

# install build essentials
apt-get install -yq \
        eatmydata \
        build-essential

# install build dependencies
eatmydata apt-get install -yq \
        meson \
        ninja-build \
        appstream \
        desktop-file-utils \
        dh-dlang \
        ldc \
        libgtkd-3-dev \
        librsvg2-dev \
        libsecret-1-dev \
        libunwind-dev \
        libvted-3-dev \
        libundead0 \
        po4a
