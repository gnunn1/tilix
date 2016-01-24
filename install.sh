# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

function processPOFile {
    echo "Processing ${1}"
    LOCALE=$(basename "$1" .po)
    msgfmt $1 -o /usr/share/locale/${LOCALE}/LC_MESSAGES/terminix.mo
}

# Copy and compile schema
echo "Copying and compiling schema..."
cp data/gsettings/com.gexperts.Terminix.gschema.xml /usr/share/glib-2.0/schemas/
glib-compile-schemas /usr/share/glib-2.0/schemas/

export TERMINIX_SHARE=/usr/share/terminix

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

# Copy executable and desktop file
cp terminix /usr/bin/terminix
cp data/pkg/desktop/com.gexperts.Terminix.desktop /usr/share/applications
