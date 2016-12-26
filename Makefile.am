bin_PROGRAMS = terminix
terminix_SOURCES = $(shell find $(srcdir)/source -name '*\.d' | LC_ALL=C sort)
terminix.o: $(terminix_SOURCES)
	$(DC) $(DCFLAGS) $(GTKD_CFLAGS) $(GTKD_LIBS) -c $^ -of$@
# libx11 is a C library, so we need to precede with -L
terminix$(EXEEXT): terminix.o
	$(DC) $(GTKD_LIBS) -L$(X11_LIBS) $^ -of$@

gschemasdir = $(datadir)/glib-2.0/schemas/
dist_gschemas_DATA = $(srcdir)/data/gsettings/com.gexperts.Terminix.gschema.xml

colorschemesdir = $(datadir)/terminix/schemes/
dist_colorschemes_DATA = $(shell find $(srcdir)/data/schemes/ -name '*\.json')

dbusservicesdir = $(datadir)/dbus-1/services/
dist_dbusservices_DATA = $(srcdir)/data/dbus/com.gexperts.Terminix.service

nautilusextdir = $(datadir)/nautilus-python/extensions/
dist_nautilusext_DATA = $(srcdir)/data/nautilus/open-terminix.py

scriptsdir = $(datadir)/terminix/scripts/
dist_scripts_DATA = $(srcdir)/data/scripts/terminix_int.sh

EXTRA_DIST = LICENSE README.md
CLEANFILES = terminix.o

SUBDIRS = data/appdata data/icons data/pkg/desktop data/resources po
ACLOCAL_AMFLAGS = -I m4
