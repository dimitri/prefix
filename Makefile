
MODULES = prefix
DATA_built = prefix.sql
DOCS = README.txt

PGXS = $(shell pg_config --pgxs)
include $(PGXS)

html: $(DOCS)
	asciidoc -a toc $<

site: html
	scp ${DOCS:.txt=.html} cvs.pgfoundry.org:/home/pgfoundry.org/groups/prefix/htdocs