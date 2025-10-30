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
        ldc \
        libatk1.0-dev \
        libcairo2-dev \
        libglib2.0-dev \
        libgtk-3-dev \
        libpango1.0-dev \
        librsvg2-dev \
        libsecret-1-dev \
        libgtksourceview-3.0-dev \
        libpeas-dev \
        libvte-2.91-dev \
        po4a
