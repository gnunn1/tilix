desktopdir = $(datadir)/applications/
desktop_DATA = com.gexperts.Terminix.desktop
$(desktop_DATA): $(srcdir)/$(desktop_DATA).in
	$(MSGFMT) --desktop -d $(top_srcdir)/po --template=$< -o $@

EXTRA_DIST = $(desktop_DATA).in
CLEANFILES = $(desktop_DATA)
