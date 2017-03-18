export TERMINIX_ARCHIVE_PATH="/tmp/terminix/archive";

rm -rf ${TERMINIX_ARCHIVE_PATH}

CURRENT_DIR=$(pwd)

echo "Building application..."
cd ../../..
dub build --build=release --compiler=ldc2
strip tilix

./install.sh ${TERMINIX_ARCHIVE_PATH}/usr

# Remove compiled schema
rm ${TERMINIX_ARCHIVE_PATH}/usr/share/glib-2.0/schemas/gschemas.compiled

echo "Creating archive"
cd ${TERMINIX_ARCHIVE_PATH}
zip -r terminix.zip *

cp terminix.zip ${CURRENT_DIR}/terminix.zip
cd ${CURRENT_DIR}
