#! /bin/sh

BUILD_DIR=$PWD/builddir
JSON=com.gexperts.Tilix.json
REPO=$PWD/repo

echo "Uninstalling Tilix..."
flatpak --user uninstall com.gexperts.Tilix

echo "Removing repo..."
flatpak --user remote-delete tilix-repo

echo "Removing repo..."
rm -rf $REPO

echo "Removing build dir..."
rm -rf $BUILD_DIR