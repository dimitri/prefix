PKGNAME = prefix
PKGVERS = $(shell dpkg-parsechangelog | awk -F '[:-]' '/^Version:/ { print substr($$2, 2) }')
EXTVERS = $(shell awk -F "[= ']" '/default_version/ {print $$5}' prefix.control)

DEBDIR = /tmp/$(PKGNAME)
EXPORT = $(DEBDIR)/export/$(PKGNAME)-$(PKGVERS)
ORIG   = $(DEBDIR)/export/$(PKGNAME)_$(PKGVERS).orig.tar.gz
ARCHIVE= $(DEBDIR)/export/$(PKGNAME)-$(PKGVERS).tar.gz
DEBEXTS= {gz,changes,build,dsc}

EXTENSION = prefix
MODULES = prefix
DATA = prefix--1.2.0.sql
DOCS = $(wildcard *.txt)

# support for 8.1 which didn't expose PG_VERSION_NUM -- another trick from ip4r
PREFIX_PGVER = $(shell echo $(VERSION) | awk -F. '{ print $$1*100+$$2 }')
PG_CPPFLAGS  = -DPREFIX_PGVER=$(PREFIX_PGVER)

PG_CONFIG ?= pg_config
PGXS = $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

.PHONY: html site deb

html: ${DOCS:.txt=.html}

%.html:%.txt
	asciidoc -a toc $<

site: html
	scp ${DOCS:.txt=.html} cvs.pgfoundry.org:/home/pgfoundry.org/groups/prefix/htdocs

deb:
	# working copy from where to make the .orig archive
	rm -rf $(DEBDIR)	
	mkdir -p $(DEBDIR)/$(PKGNAME)-$(PKGVERS)
	mkdir -p $(EXPORT)
	rsync -Ca . $(EXPORT)

	# get rid of temp and build files
	for n in ".#*" "*~" "build-stamp" "configure-stamp" "prefix.so"; do \
	  find $(EXPORT) -name "$$n" -print0|xargs -0 rm -f; \
	done

	# prepare the .orig without the debian/ packaging stuff
	rsync -Ca $(EXPORT) $(DEBDIR)
	rm -rf $(DEBDIR)/$(PKGNAME)-$(PKGVERS)/debian
	(cd $(DEBDIR) && tar czf $(ORIG) $(PKGNAME)-$(PKGVERS))

	# have a copy of the $$ORIG file named $$ARCHIVE for non-debian packagers
	cp $(ORIG) $(ARCHIVE)

	# build the debian package and copy them to ..
	(cd $(EXPORT) && touch debian/control.in && debuild)

	cp $(EXPORT)/debian/control debian
	cp -a $(DEBDIR)/export/*.deb ..
	find $(DEBDIR)/export -name "*.$(DEBEXTS)" -print0| xargs -0 -I% cp -a % ..
	cp -a $(ARCHIVE) ..
	cp -a $(ORIG) ..
