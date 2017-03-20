export TILIX_ARCHIVE_PATH="/tmp/tilix/archive";

rm -rf ${TILIX_ARCHIVE_PATH}

CURRENT_DIR=$(pwd)

echo "Building application..."
cd ../../..
dub build --build=release --compiler=ldc2
strip tilix

./install.sh ${TILIX_ARCHIVE_PATH}/usr

# Remove compiled schema
rm ${TILIX_ARCHIVE_PATH}/usr/share/glib-2.0/schemas/gschemas.compiled

echo "Creating archive"
cd ${TILIX_ARCHIVE_PATH}
zip -r tilix.zip *

cp tilix.zip ${CURRENT_DIR}/tilix.zip
cd ${CURRENT_DIR}
