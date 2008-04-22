= Prefix Opclass

This module is written by Dimitri Fontaine with a great amount of help
from RhodiumToad (formely known as AndrewSN), who was the one advising
for a 'GiST opclass' to solve the prefix matching problem.

== Presentation

Prefix matching is both very common and important in telephony
applications, where call routing and costs depend on matching
caller/callee phone number to an operator prefix.

Let's say the prefixes table is called +prefixes+, a typical query
will try to match a phone number to the greater prefix in the table:

    SELECT * 
      FROM prefixes
     WHERE prefix @> '0123456789'
  ORDER BY length(prefix)
     LIMIT 1;

== Installation

Check +$PATH+, then

  make
  make install
  psql <connection string> -f prefix.sql <database>

The +make install+ step might have to be done as +root+, and the
psql one has to be done as a PostgreSQL 'superuser'.

== Usage

=== Table and index creation

  create table prefixes (
         prefix    prefix_range primary key,
         name      text not null,
         shortname text,
         status    char default 'S',

         check( status in ('S', 'R') )
  );
  comment on column prefixes.status is 'S:   - R: reserved';
  
  \copy prefixes from 'prefixes.fr.csv' with delimiter ; csv quote '"'

  create index idx_prefix on prefixes using gist(prefix gist_prefix_range_ops);

=== Simple tests:

  dim=# select '123'::prefix_range @> '123456';
   ?column?
  ----------
   t
  (1 row)

==== set enable_seqscan to on;

  dim=# select * from ranges where prefix @> '0146640123';
   prefix |      name      | shortname | state
  --------+----------------+-----------+-------
   0146[] | FRANCE TELECOM | FRTE      | S
  (1 row)
  
  Time: 4,071 ms

  dim=# select * from ranges where prefix @> '0100091234';
    prefix  |    name    | shortname | state
  ----------+------------+-----------+-------
   010009[] | LONG PHONE | LGPH      | S
  (1 row)
  
  Time: 4,110 ms

=== set enable_seqscan to off;

  dim=# select * from ranges where prefix @> '0146640123';
   prefix |      name      | shortname | state
  --------+----------------+-----------+-------
   0146[] | FRANCE TELECOM | FRTE      | S
  (1 row)
  
  Time: 1,036 ms

  dim=# select * from ranges where prefix @> '0100091234';
    prefix  |    name    | shortname | state
  ----------+------------+-----------+-------
   010009[] | LONG PHONE | LGPH      | S
  (1 row)
  
  Time: 0,771 ms

== See also

This link:TESTS.html[Tests] page is more developper oriented material,
but still of interest.
