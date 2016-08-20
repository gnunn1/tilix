#!/bin/sh

cat <<EOF >Makefile
all:
	make -f posix.mak DMD=/app/bin/dmd ROOT_OF_THEM_ALL=/app

install:
	make -f posix.mak install DMD=/app/bin/dmd INSTALL_DIR=/app

EOF
