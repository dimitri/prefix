PKGNAME = prefix
EXTENSION = prefix
MODULES = prefix
DATA = prefix--1.2.0.sql prefix--unpackaged--1.2.0.sql prefix--1.1--1.2.0.sql
DOCS = $(wildcard *.prefix.md)
# "explain (costs off)" needs 9.0+ (and 9.0 needs expected/explain_1.out)
EXPLAINSQL = $(shell $(PG_CONFIG) --version | grep -qE " 8\." || echo explain)
REGRESS = create_extension prefix falcon $(EXPLAINSQL) queries

PG_CONFIG ?= pg_config
PGXS = $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# PGXS installs DOCS to a flat shared directory without namespacing.
# Use extension-specific filenames to avoid collisions with other extensions.
README.prefix.md: README.md
	cp $< $@

TESTS.prefix.md: TESTS.md
	cp $< $@

all: README.prefix.md TESTS.prefix.md

clean: clean-docs
clean-docs:
	rm -f README.prefix.md TESTS.prefix.md

deb: clean
	make -f debian/rules debian/control
	dh clean
	make -f debian/rules orig
	debuild -us -uc -sa
