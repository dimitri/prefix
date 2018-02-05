PKGNAME = prefix
EXTENSION = prefix
MODULES = prefix
DATA = prefix--1.2.0.sql prefix--unpackaged--1.2.0.sql prefix--1.1--1.2.0.sql
DOCS = $(wildcard *.md)
# "explain (costs off)" needs 9.0+ (and 9.0 needs expected/explain_1.out)
EXPLAINSQL = $(shell $(PG_CONFIG) --version | grep -qE " 8\." || echo explain)
REGRESS = create_extension prefix falcon $(EXPLAINSQL) queries

PG_CONFIG ?= pg_config
PGXS = $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

deb: clean
	make -f debian/rules debian/control
	dh clean
	make -f debian/rules orig
	debuild -us -uc -sa
