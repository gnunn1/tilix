#! /bin/sh

CURRENT_DIR=$(pwd)

./clean.sh

flatpak build-init terminix com.gexperts.Terminix org.gnome.Sdk org.gnome.Platform 3.22

cd ../../..

dub build --build=release
./install.sh ${CURRENT_DIR}/terminix/files

cd ${CURRENT_DIR}

flatpak build-finish --socket=x11 --socket=wayland --socket=pulseaudio --device=dri --filesystem=host --filesystem=home --filesystem=~/.config/dconf:ro --filesystem=xdg-run/dconf --talk-name=org.freedesktop.Flatpak --talk-name=ca.desrt.dconf --env=DCONF_USER_CONFIG_DIR=.config/dconf --allow=devel terminix

flatpak build-export repo terminix

flatpak --user remote-add --no-gpg-verify terminix-repo repo
flatpak --user install terminix-repo com.gexperts.Terminix
