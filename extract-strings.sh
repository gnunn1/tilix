#!/bin/sh
DOMAIN=terminix
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
  ${BASEDIR}/data/nautilus/open-terminix.py

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
  ${BASEDIR}/data/pkg/desktop/com.gexperts.Terminix.desktop.in

xgettext \
  --join-existing \
  --output $OUTPUT_FILE \
  --default-domain=$DOMAIN \
  --package-name=$DOMAIN \
  --directory=$BASEDIR \
  --foreign-user \
  --language=appdata \
  ${BASEDIR}/data/appdata/com.gexperts.Terminix.appdata.xml.in

# Merge the messages with existing po files
echo "Merging with existing translations... "
for file in ${BASEDIR}/po/*.po
do
  echo -n $file
  msgmerge --update $file $OUTPUT_FILE
done

# Update manpage translations
if type po4a-updatepo >/dev/null 2>&1; then
  MANDIR=${BASEDIR}/data/man
  po4a-gettextize -f man -m ${MANDIR}/terminix -p ${MANDIR}/po/terminix.man.pot
  po4a-updatepo -f man -m ${MANDIR}/terminix -p ${MANDIR}/po/*.man.po
fi
