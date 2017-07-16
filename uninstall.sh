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
if [ "${PREFIX}" = "/usr" ] || [ "$(id -u)" == "0" ]; then
    rm /usr/share/glib-2.0/schemas/com.gexperts.Tilix.gschema.xml
    glib-compile-schemas /usr/share/glib-2.0/schemas/
else
    echo
    echo "sudo privileges is required to remove the glib-2.0 schema (/usr/share/glib-2.0/schemas/com.gexperts.Tilix.gschema.xml) that was installed for Tilix"
    echo "Please remove the gschema manually and then re-compile the gschema by runnig"
    echo "sudo glib-compile-schemas /usr/share/glib-2.0/schemas/"
    echo "Comtinuing with the rest of the uninstall"
    echo
fi
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
