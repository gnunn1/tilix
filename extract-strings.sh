#!/bin/sh
DOMAIN=terminix
BASEDIR=$(dirname $0)
OUTPUT_FILE=${BASEDIR}/po/${DOMAIN}.pot

echo "Extracting translatable strings... "

# Attempt to extract the keyboard shortcut action names from the GSettings schema
sed -n '/<key name="\(app\|session\|terminal\|win\)-/p' \
  ${BASEDIR}/data/gsettings/com.gexperts.Terminix.gschema.xml \
  | sed 's/\s*<key name="\(app\|session\|terminal\|win\)-\([^"]*\).*/"\1"\;\n"\2";/' \
  | xgettext \
  --extract-all \
  --no-location \
  --force-po \
  --output $OUTPUT_FILE \
  --language=C \
  -

# Extract the strings from D source code. Since xgettext does not support D
# as a language we use Vala, which works reasonable well.
find ${BASEDIR}/source -name '*.d' | xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --files-from=- \
  --directory=$BASEDIR \
  --language=Vala \
  --from-code=utf-8

xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --directory=$BASEDIR \
  ${BASEDIR}/data/nautilus/open-terminix.py

xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --default-domain=$DOMAIN \
  --package-name=$DOMAIN \
  --directory=$BASEDIR \
  --foreign-user \
  --language=Desktop \
  ${BASEDIR}/data/pkg/desktop/com.gexperts.Terminix.desktop.in
  
# Glade UI Files
find ${BASEDIR}/data/resources/ui -name '*.ui' | xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --files-from=- \
  --directory=$BASEDIR \
  --language=Glade \
  --from-code=utf-8

# Merge the messages with existing po files
echo "Merging with existing translations... "
for file in ${BASEDIR}/po/*.po
do
  echo -n $file
  msgmerge --update $file $OUTPUT_FILE
done
