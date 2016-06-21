appdatadir = $(datadir)/appdata/
appdata_DATA = com.gexperts.Terminix.appdata.xml
$(appdata_DATA): $(srcdir)/$(appdata_DATA).in $(top_srcdir)/po/*.po
	$(MSGFMT) --xml -d $(top_srcdir)/po --template=$< -o $@

EXTRA_DIST = $(appdata_DATA).in
CLEANFILES = $(appdata_DATA)
