desktopdir = $(datadir)/applications/
desktop_DATA = com.gexperts.Tilix.desktop
$(desktop_DATA): $(srcdir)/$(desktop_DATA).in $(top_srcdir)/po/*.po
	$(MSGFMT) --desktop -d $(top_srcdir)/po --template=$< -o $@

EXTRA_DIST = $(desktop_DATA).in
CLEANFILES = $(desktop_DATA)
