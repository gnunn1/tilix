#! /bin/sh

flatpak --user uninstall com.gexperts.Terminix
flatpak --user remote-delete terminix-repo

rm -rf terminix
rm -rf repo
