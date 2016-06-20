#!/usr/bin/env sh

# Create/Update LINGUAS file
find po -name "*\.po" -printf "%f\\n" | sed "s/\.po//g" | sort > po/LINGUAS

autoreconf --install || exit 1
