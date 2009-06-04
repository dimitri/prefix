PKGNAME = prefix
PKGVERS = 0.4

DEBDIR = /tmp/$(PKGNAME)
EXPORT = $(DEBDIR)/export/$(PKGNAME)-$(PKGVERS)
ORIG   = $(DEBDIR)/export/$(PKGNAME)_$(PKGVERS).orig.tar.gz
ARCHIVE= $(DEBDIR)/export/$(PKGNAME)-$(PKGVERS).tar.gz
DEBEXTS= {gz,changes,build,dsc}

MODULES = prefix
DATA_built = prefix.sql
DOCS = $(wildcard *.txt)

# support for 8.1 which didn't expose PG_VERSION_NUM -- another trick from ip4r
PREFIX_PGVER = $(shell echo $(VERSION) | awk -F. '{ print $$1*100+$$2 }')
PG_CPPFLAGS  = -DPREFIX_PGVER=$(PREFIX_PGVER)

PGXS = $(shell pg_config --pgxs)
include $(PGXS)

.PHONY: html site deb

html: ${DOCS:.txt=.html}

%.html:%.txt
	asciidoc -a toc $<

site: html
	scp ${DOCS} cvs.pgfoundry.org:/home/pgfoundry.org/groups/prefix/htdocs

deb:
	# working copy from where to make the .orig archive
	rm -rf $(DEBDIR)	
	mkdir -p $(DEBDIR)/$(PKGNAME)-$(PKGVERS)
	mkdir -p $(EXPORT)
	cp -a . $(EXPORT)

	# get rid of temp and build files
	for n in ".#*" "*~" "build-stamp" "configure-stamp" "prefix.sql" "prefix.so"; do \
	  find $(EXPORT) -name "$$n" -print0|xargs -0 echo rm -f; \
	  find $(EXPORT) -name "$$n" -print0|xargs -0 rm -f; \
	done

	# get rid of CVS dirs
	for n in "CVS" "CVSROOT"; do \
	  find $(EXPORT) -type d -name "$$n" -print0|xargs -0 rm -rf; \
	  find $(EXPORT) -type d -name "$$n" -print0|xargs -0 rm -rf; \
	done

	# prepare the .orig without the debian/ packaging stuff
	cp -a $(EXPORT) $(DEBDIR)
	rm -rf $(DEBDIR)/$(PKGNAME)-$(PKGVERS)/debian
	(cd $(DEBDIR) && tar czf $(ORIG) $(PKGNAME)-$(PKGVERS))

	# have a copy of the $ORIG file named $ARCHIVE for non-debian packagers
	cp $(ORIG) $(ARCHIVE)

	# build the debian package and copy them to ..
	(cd $(EXPORT) && debuild)

	cp -a $(DEBDIR)/export/*.deb ..
	cp -a $(DEBDIR)/export/$(PKGNAME)[_-]$(PKGVERS)*.$(DEBEXTS) ..
	cp -a $(ARCHIVE) ..
	cp -a $(ORIG) ..
