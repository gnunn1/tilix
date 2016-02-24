#!/bin/sh
DOMAIN=terminix
BASEDIR=$(dirname $0)
OUTPUT_FILE=${BASEDIR}/po/${DOMAIN}.pot

find ${BASEDIR}/source -name '*.d' | xgettext \
  --output $OUTPUT_FILE \
  --files-from=- \
  --default-domain=$DOMAIN \
  --package-name=$DOMAIN \
  --directory=$BASEDIR \
  --language=Vala \
  --from-code=utf-8

xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --default-domain=$DOMAIN \
  --package-name=$DOMAIN \
  --directory=$BASEDIR \
  ${BASEDIR}/data/nautilus/open-terminix.py

xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --default-domain=$DOMAIN \
  --package-name=$DOMAIN \
  --directory=$BASEDIR \
  --language=Desktop \
  ${BASEDIR}/data/pkg/desktop/com.gexperts.Terminix.desktop.in

# Attempt to extract the keyboard shortcut action names from the GSettings schema
sed -n '/<key name="\(app\|session\|terminal\|win\)-/p' \
  ${BASEDIR}/data/gsettings/com.gexperts.Terminix.gschema.xml \
  | sed 's/\s*<key name="\(app\|session\|terminal\|win\)-\([^"]*\).*/"\1"\;\n"\2";/' \
  | xgettext \
  --join-existing \
  --extract-all \
  --output $OUTPUT_FILE \
  --default-domain=$DOMAIN \
  --package-name=$DOMAIN \
  --directory=$BASEDIR \
  --language=C \
  -
# xgettext \
#   --join-existing \
#   --output ${DOMAIN}.pot \
#   --default-domain=$DOMAIN \
#   --package-name=$DOMAIN \
#   --directory=$BASEDIR \
#   --language=GSettings \
#   ${BASEDIR}/data/gsettings/com.gexperts.Terminix.gschema.xml
