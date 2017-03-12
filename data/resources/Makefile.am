resources = $(shell find $(srcdir)/css $(srcdir)/icons $(srcdir)/ui)

gresourcedir = $(datadir)/tilix/resources/
gresource_DATA = tilix.gresource
$(gresource_DATA): $(srcdir)/$(gresource_DATA).xml $(resources)
	$(GLIB_COMPILE_RES) --sourcedir=$(srcdir) --target=$@ $<

EXTRA_DIST = $(gresource_DATA).xml $(resources)
CLEANFILES = $(gresource_DATA)
