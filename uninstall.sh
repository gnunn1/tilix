#!/usr/bin/env sh

if [ -z  "$1" ]; then
    export PREFIX=/usr
    # Make sure only root can run our script
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
else
    export PREFIX=$1
fi

echo "Uninstalling from prefix ${PREFIX}"

rm ${PREFIX}/bin/terminix
rm ${PREFIX}/share/glib-2.0/schemas/com.gexperts.Terminix.gschema.xml
rm -rf ${PREFIX}/share/terminix

find ${PREFIX}/share/locale -type f -name "terminix.mo" -delete
rm ${PREFIX}/share/nautilus-python/extensions/open-terminix.py
rm ${PREFIX}/share/dbus-1/services/com.gexperts.Terminix.service
rm ${PREFIX}/share/applications/com.gexperts.Terminix.desktop
