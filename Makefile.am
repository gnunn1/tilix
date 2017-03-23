bin_PROGRAMS = tilix
tilix_SOURCES = $(shell find $(srcdir)/source -name '*\.d' | LC_ALL=C sort)
tilix.o: $(tilix_SOURCES)
	$(DC) $(DCFLAGS) $(GTKD_CFLAGS) $(GTKD_LIBS) -c $^ -of$@
# libx11 is a C library, so we need to precede with -L
tilix$(EXEEXT): tilix.o
	$(DC) $(GTKD_LIBS) -L$(X11_LIBS) $^ -of$@

gschemasdir = $(datadir)/glib-2.0/schemas/
dist_gschemas_DATA = $(srcdir)/data/gsettings/com.gexperts.Tilix.gschema.xml

colorschemesdir = $(datadir)/tilix/schemes/
dist_colorschemes_DATA = $(shell find $(srcdir)/data/schemes/ -name '*\.json')

dbusservicesdir = $(datadir)/dbus-1/services/
dist_dbusservices_DATA = $(srcdir)/data/dbus/com.gexperts.Tilix.service

nautilusextdir = $(datadir)/nautilus-python/extensions/
dist_nautilusext_DATA = $(srcdir)/data/nautilus/open-tilix.py

scriptsdir = $(datadir)/tilix/scripts/
dist_scripts_DATA = $(srcdir)/data/scripts/tilix_int.sh

EXTRA_DIST = LICENSE README.md
CLEANFILES = tilix.o

SUBDIRS = data/appdata data/icons data/pkg/desktop data/resources data/man po
ACLOCAL_AMFLAGS = -I m4
