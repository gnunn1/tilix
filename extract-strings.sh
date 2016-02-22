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
  --language=Vala

xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --default-domain=$DOMAIN \
  --package-name=$DOMAIN \
  --directory=$BASEDIR \
  ${BASEDIR}/data/nautilus/open-terminix.py

# xgettext \
#   --join-existing \
#   --output ${DOMAIN}.pot \
#   --default-domain=$DOMAIN \
#   --package-name=$DOMAIN \
#   --directory=$BASEDIR \
#   --language=GSettings \
#   ${BASEDIR}/data/gsettings/com.gexperts.Terminix.gschema.xml
