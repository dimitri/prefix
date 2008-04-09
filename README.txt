= Prefix Opclass

This module is written by Dimitri Fontaine with a great amount of help
from AndrewSN, who was the one advising for a 'GiST opclass' to solve
the prefix matching problem.

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

== Tests

=== Preparing

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

=== Creating the prefix_range table

We create the +ranges+ table from the previous +prefixes+ one,
allowing to quickly have data again after reinstalling the
+prefix.sql+ module.

  drop table ranges;
  create table ranges as select prefix::prefix_range, name, shortname, state from prefixes ;
  create index idx_prefix on ranges using gist(prefix gist_prefix_range_ops);

=== Using Gevel to inspect the index

For information about the Gevel project, see
http://www.sai.msu.su/~megera/oddmuse/index.cgi/Gevel[] and
http://www.sigaev.ru/cvsweb/cvsweb.cgi/gevel/[].

  select gist_stat('idx_prefix');
  select * from gist_print('idx_prefix') as t(level int, valid bool, a prefix_range) where level =1;
  select * from gist_print('idx_prefix') as t(level int, valid bool, a prefix_range) order by level;

=== Testing the index content

Those queries should return the same line, but it fails with
+enable_seqscan to off+ when the index is not properly build.

  \set enable_seqscan to on;
  select * from ranges where prefix @> '0146640123';
  select * from ranges where prefix @> '0100091234';

  \set enable_seqscan to off;
  select * from ranges where prefix @> '0146640123';
  select * from ranges where prefix @> '0100091234';

=== Testing prefix_range GiST penalty code

We want +gpr_penalty+ result to be the lower when its second argument
is the nearest of the first.

  select a, b, gpr_penalty(a::prefix_range, b::prefix_range)
    from (values('095[4-5]', '0[8-9]'),
                ('095[4-5]', '0[0-9]'),
		('095[4-5]', '[0-3]'), 
		('095[4-5]', '0'), 
		('095[4-5]', '[0-9]'), 
		('095[4-5]', '0[1-5]'), 
		('095[4-5]', '32'), 
		('095[4-5]', '[1-3]')) as t(a, b) 
  order by 3 asc;

      a     |   b    | gpr_penalty
  ----------+--------+-------------
   095[4-5] | 0[8-9] | 1.52588e-05
   095[4-5] | 0[0-9] | 1.52588e-05
   095[4-5] | [0-3]  |  0.00390625
   095[4-5] | 0      |  0.00390625
   095[4-5] | [0-9]  |  0.00390625
   095[4-5] | 0[1-5] |   0.0078125
   095[4-5] | 32     |           1
   095[4-5] | [1-3]  |           1
  (8 rows)

== Usage

=== Usage with only text data

  postgres=# select '123' @> '123456';
   ?column?
  ----------
   t
  (1 row)


  CREATE INDEX idx_prefix ON prefixes USING GIST(prefix gist_prefix_ops);

  dim=# \timing
  Timing is on.
  dim=# select * from prefixes where prefix @> '0218751234';
   prefix |                name                 | shortname | state
  --------+-------------------------------------+-----------+-------
   021875 | SOCIETE FRANCAISE DU RADIOTELEPHONE | SFR       | S
  (1 row)
  
  Time: 10,564 ms

  dim=# set enable_seqscan to off;
  SET
  dim=# select * from prefixes where prefix @> '0218751234';
   prefix |                name                 | shortname | state
  --------+-------------------------------------+-----------+-------
   021875 | SOCIETE FRANCAISE DU RADIOTELEPHONE | SFR       | S
  (1 row)
  
  Time: 5,826 ms

=== Usage with prefix_range data

See tests above...
