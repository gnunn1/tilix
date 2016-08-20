#!/bin/sh

cat <<EOF >Makefile
all:
	echo "2.070" > VERSION
	make -f posix.mak VERSION=VERSION DMD=/app/bin/dmd DRUNTIME_PATH=/app DMDEXTRAFLAGS=-I/app/src/druntime/import DRUNTIME=/app/linux/release/64/libdruntime.a ROOT_OF_THEM_ALL=/app CUSTOM_DRUNTIME=1

install:
	make -f posix.mak install VERSION=VERSION DMD=/app/bin/dmd INSTALL_DIR=/app DRUNTIME_PATH=/app DRUNTIME=/app/linux/release/64/libdruntime.a DMDEXTRAFLAGS=-I/app/src/druntime/import CUSTOM_DRUNTIME=1

EOF
