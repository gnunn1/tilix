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

rm ${PREFIX}/bin/tilix
rm ${PREFIX}/share/glib-2.0/schemas/com.gexperts.Tilix.gschema.xml
glib-compile-schemas ${PREFIX}/share/glib-2.0/schemas/
rm -rf ${PREFIX}/share/tilix

find ${PREFIX}/share/locale -type f -name "tilix.mo" -delete
find ${PREFIX}/share/icons/hicolor -type f -name "com.gexperts.Tilix.png" -delete
find ${PREFIX}/share/icons/hicolor -type f -name "com.gexperts.Tilix*.svg" -delete
rm ${PREFIX}/share/nautilus-python/extensions/open-tilix.py
rm ${PREFIX}/share/dbus-1/services/com.gexperts.Tilix.service
rm ${PREFIX}/share/applications/com.gexperts.Tilix.desktop
rm ${PREFIX}/share/metainfo/com.gexperts.Tilix.appdata.xml
rm ${PREFIX}/share/man/man1/tilix.1.gz
rm ${PREFIX}/share/man/*/man1/tilix.1.gz
