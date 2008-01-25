
MODULES = prefix
DATA_built = prefix.sql
DOCS = README.txt

PG_CPPFLAGS = -DPREFIX_PGVER=$(shell echo $(VERSION) | awk -F. '{ print ($$1*1000+$$2)*1000+$$3 }')
PGXS = $(shell pg_config --pgxs)
include $(PGXS)

html: $(DOCS)
	asciidoc -a toc $<

site: html
	scp ${DOCS:.txt=.html} cvs.pgfoundry.org:/home/pgfoundry.org/groups/prefix/htdocs