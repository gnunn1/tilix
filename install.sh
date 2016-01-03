# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Remove schema and compile to clean up old version
# dconf reset -f "/com/gexperts/Terminix/"

# Copy and compile schema
cp data/gsettings/com.gexperts.Terminix.gschema.xml /usr/share/glib-2.0/schemas/
glib-compile-schemas /usr/share/glib-2.0/schemas/

export TERMINIX_SHARE=/usr/share/terminix

mkdir -p ${TERMINIX_SHARE}/resources
mkdir -p ${TERMINIX_SHARE}/schemes

# Copy and compile icons
cd data/resources
glib-compile-resources terminix.gresource.xml
cp terminix.gresource ${TERMINIX_SHARE}/resources/terminix.gresource
cd ../..

# Copy color schemes
cp data/schemes/* ${TERMINIX_SHARE}/schemes

# Copy executable and desktop file
cp terminix /usr/bin/terminix
cp data/pkg/desktop/com.gexperts.Terminix.desktop /usr/share/applications
