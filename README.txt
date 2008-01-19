= Prefix Opclass

== Presentation

== Installation

Check $PATH, then

  make
  make install
  psql <connection string> -f prefix.sql <database>

The +make install+ step might have to be done as +root+, and the
psql one has to be done as a PostgreSQL 'superuser'.

== Tests

The +prefixes.sql+ creates a table which fits +prefixes.fr.csv+
content. This file contains all the official French Telephony prefixes
used as of early 2008, as found on the
http://www.art-telecom.fr/[French telecom regulation authority]
website (see http://www.art-telecom.fr/fileadmin/wopnum.rtf[]).

  create table prefixes (
         prefix    text primary key,
         name      text not null,
         shortname text,
         state     char default 'S',

         check( state in ('S', 'R') )
  );
  comment on column prefixes.state is 'S:   - R: reserved';
  
  \copy prefixes from 'prefixes.fr.csv' with delimiter ; csv quote '"'

== Usage

  postgres=# select '123' @> '123456';
   ?column?
  ----------
   t
  (1 row)


  CREATE INDEX idx_prefix ON prefixes USING GIST(prefix gist_prefix_ops);
