#! /bin/sh

BUILD_DIR=$PWD/builddir
JSON=com.gexperts.Tilix.json
REPO=$PWD/repo

./clean.sh

echo "Building with flatpak-builder..."
flatpak-builder --repo=$REPO $BUILD_DIR $JSON

echo "Adding repo..."
flatpak --user remote-add --no-gpg-verify tilix-repo $REPO

echo "Installing Tilix..."
flatpak --user install tilix-repo com.gexperts.Tilix