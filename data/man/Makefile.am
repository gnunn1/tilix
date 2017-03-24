mansdir = $(datadir)
manfile = $(builddir)/man/man1/tilix.1.gz
mansfiles = $(shell find $(srcdir)/po -name '*.man.po' | sed "s_$(srcdir)/po/\(.*\)\.man\.po_$(builddir)/man/\1/man1/tilix.1.gz_g")
nobase_dist_mans_DATA = $(manfile) $(mansfiles)

$(manfile): $(srcdir)/tilix
	$(INSTALL) -d $(@D); \
	$(INSTALL) $< $(@D)/tilix.1; \
	gzip -f $(@D)/tilix.1

$(builddir)/man/%/man1/tilix.1.gz: $(srcdir)/po/%.man.po
	$(INSTALL) -d "$(builddir)"/man/$(*F)/man1; \
	$(PO4A_TRANS) -k 0 -f man -m "$(srcdir)"/tilix -p $< -l "$(builddir)"/man/$(*F)/man1/tilix.1; \
	gzip -f "$(builddir)"/man/$(*F)/man1/tilix.1; 

EXTRA_DIST = $(srcdir)/tilix $(srcdir)/po/*.man.po 
CLEANFILES = $(manfile) $(mansfiles)
