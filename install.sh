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

echo "Installing to prefix ${PREFIX}"

function processPOFile {
    echo "Processing ${1}"
    LOCALE=$(basename "$1" .po)
    mkdir -p ${PREFIX}/share/locale/${LOCALE}/LC_MESSAGES
    msgfmt $1 -o ${PREFIX}/share/locale/${LOCALE}/LC_MESSAGES/terminix.mo
}

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

# Compile po files
echo "Copying and installing localization files"
export -f processPOFile
ls po/*.po | xargs -n 1 -P 10 -I {} bash -c 'processPOFile "$@"' _ {}

# Copying Nautilus extension
echo "Copying Nautilus extension"
mkdir -p ${PREFIX}/share/nautilus-python/extensions/
cp data/nautilus/open-terminix.py ${PREFIX}/share/nautilus-python/extensions/open-terminix.py

# Copy D-Bus service descriptor
mkdir -p ${PREFIX}/share/dbus-1/services
cp data/dbus/com.gexperts.Terminix.service ${PREFIX}/share/dbus-1/services

# Copy executable and desktop file
mkdir -p ${PREFIX}/bin
cp terminix ${PREFIX}/bin/terminix
mkdir -p ${PREFIX}/share/applications
cp data/pkg/desktop/com.gexperts.Terminix.desktop ${PREFIX}/share/applications
