
MODULES = prefix
DATA_built = prefix.sql
DOCS = $(patsubst %.txt,%.html,$(wildcard *.txt))

PGXS = $(shell pg_config --pgxs)
include $(PGXS)

html: $(DOCS)

%.html:%.txt
	asciidoc -a toc $<

site: html
	scp ${DOCS} cvs.pgfoundry.org:/home/pgfoundry.org/groups/prefix/htdocs