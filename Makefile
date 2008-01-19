
MODULES = prefix
DATA_built = prefix.sql
DOCS = README.txt

PGXS = $(shell pg_config --pgxs)
include $(PGXS)

html: $(DOCS)
	asciidoc -a toc $<

