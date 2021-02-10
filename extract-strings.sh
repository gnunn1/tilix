#!/bin/sh
set -e

DOMAIN=tilix
BASEDIR=$(dirname $0)
OUTPUT_FILE=${BASEDIR}/po/${DOMAIN}.pot

echo "Extracting translatable strings... "

# Extract the strings from D source code. Since xgettext does not support D
# as a language we use Vala, which works reasonable well.
find ${BASEDIR}/source -name '*.d' | xgettext \
  --output $OUTPUT_FILE \
  --files-from=- \
  --directory=$BASEDIR \
  --language=Vala \
  --keyword=C_:1c,2 \
  --from-code=utf-8 \
  --add-comments=TRANSLATORS

xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --directory=$BASEDIR \
  ${BASEDIR}/data/nautilus/open-tilix.py

# Glade UI Files
find ${BASEDIR}/data/resources/ui -name '*.ui' | xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --files-from=- \
  --directory=$BASEDIR \
  --language=Glade \
  --from-code=utf-8

xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --default-domain=$DOMAIN \
  --package-name=$DOMAIN \
  --directory=$BASEDIR \
  --foreign-user \
  --language=Desktop \
  ${BASEDIR}/data/pkg/desktop/com.gexperts.Tilix.desktop.in

TMP_METAINFO_FILE=${BASEDIR}/data/metainfo/com.gexperts.Tilix.appdata.xml.rel.in
appstreamcli news-to-metainfo ${BASEDIR}/NEWS \
  ${BASEDIR}/data/metainfo/com.gexperts.Tilix.appdata.xml.in \
  ${TMP_METAINFO_FILE}
xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --default-domain=$DOMAIN \
  --package-name=$DOMAIN \
  --directory=$BASEDIR \
  --foreign-user \
  --language=appdata \
  ${TMP_METAINFO_FILE}
rm -f ${TMP_METAINFO_FILE}

# Merge the messages with existing po files
echo "Merging with existing translations... "
for file in ${BASEDIR}/po/*.po
do
  echo -n $file
  msgmerge -F --update $file $OUTPUT_FILE
done

echo "Updating LINGUAS file..."
find ${BASEDIR}/po \
        -type f \
        -iname "*.po" \
        -printf '%f\n' \
        | grep -oP '.*(?=[.])' | sort \
        > ${BASEDIR}/po/LINGUAS

# Update manpage translations
echo "Updating manpage translations..."
if type po4a-updatepo >/dev/null 2>&1; then
  MANDIR=${BASEDIR}/data/man
  po4a-gettextize -f man -m ${MANDIR}/tilix.1 -p ${MANDIR}/po/tilix.1.man.pot
  for file in ${MANDIR}/po/*.man.po
  do
    echo -n $file
    po4a-updatepo -f man -m ${MANDIR}/tilix.1 -p $file
  done
fi
