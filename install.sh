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

if [ ! -f terminix ]; then
    echo "The terminix executable does not exist, please run 'dub build --build=release' before using this script"
    exit 1
fi

echo "Installing to prefix ${PREFIX}"

# Copy and compile schema
echo "Copying and compiling schema..."
mkdir -p ${PREFIX}/share/glib-2.0/schemas
cp data/gsettings/com.gexperts.Terminix.gschema.xml ${PREFIX}/share/glib-2.0/schemas/
glib-compile-schemas ${PREFIX}/share/glib-2.0/schemas/

export TERMINIX_SHARE=${PREFIX}/share/terminix

mkdir -p ${TERMINIX_SHARE}/resources
mkdir -p ${TERMINIX_SHARE}/schemes

# Copy and compile icons
echo "Building and copy resources..."
cd data/resources
glib-compile-resources terminix.gresource.xml
cp terminix.gresource ${TERMINIX_SHARE}/resources/terminix.gresource
cd ../..

# Copy color schemes
echo "Copying color schemes..."
cp data/schemes/* ${TERMINIX_SHARE}/schemes

# Create/Update LINGUAS file
find po -name "*\.po" -printf "%f\\n" | sed "s/\.po//g" | sort > po/LINGUAS

# Compile po files
echo "Copying and installing localization files"
for f in po/*.po; do
    echo "Processing $f"
    LOCALE=$(basename "$f" .po)
    mkdir -p ${PREFIX}/share/locale/${LOCALE}/LC_MESSAGES
    msgfmt $f -o ${PREFIX}/share/locale/${LOCALE}/LC_MESSAGES/terminix.mo
done

# Generate desktop file
msgfmt --desktop --template=data/pkg/desktop/com.gexperts.Terminix.desktop.in -d po -o data/pkg/desktop/com.gexperts.Terminix.desktop
if [ $? -ne 0 ]; then
    echo "Note that localizating appdata requires a newer version of xgettext, copying instead"
    cp data/pkg/desktop/com.gexperts.Terminix.desktop.in data/pkg/desktop/com.gexperts.Terminix.desktop
fi

# Generate appdata file, requires xgettext 0.19.7
msgfmt --xml --template=data/appdata/com.gexperts.Terminix.appdata.xml.in -d po -o data/appdata/com.gexperts.Terminix.appdata.xml
if [ $? -ne 0 ]; then
    echo "Note that localizating appdata requires xgettext 0.19.7 or later, copying instead"
    cp data/appdata/com.gexperts.Terminix.appdata.xml.in data/appdata/com.gexperts.Terminix.appdata.xml
fi

# Copying Nautilus extension
echo "Copying Nautilus extension"
mkdir -p ${PREFIX}/share/nautilus-python/extensions/
cp data/nautilus/open-terminix.py ${PREFIX}/share/nautilus-python/extensions/open-terminix.py

# Copy D-Bus service descriptor
mkdir -p ${PREFIX}/share/dbus-1/services
cp data/dbus/com.gexperts.Terminix.service ${PREFIX}/share/dbus-1/services

# Copy Icons
mkdir -p ${PREFIX}/share/icons/hicolor
cp -r data/icons/hicolor/. ${PREFIX}/share/icons/hicolor

# Copy executable, desktop and appdata file
mkdir -p ${PREFIX}/bin
cp terminix ${PREFIX}/bin/terminix
mkdir -p ${PREFIX}/share/applications
mkdir -p ${PREFIX}/share/appdata
cp data/pkg/desktop/com.gexperts.Terminix.desktop ${PREFIX}/share/applications
cp data/appdata/com.gexperts.Terminix.appdata.xml ${PREFIX}/share/appdata

desktop-file-validate ${PREFIX}/share/applications/com.gexperts.Terminix.desktop

# Update icon cache if Prefix is /usr
if [ "$PREFIX" = '/usr' ]; then
    echo "Updating icon cache"
    sudo gtk-update-icon-cache -f /usr/share/icons/hicolor/
fi
