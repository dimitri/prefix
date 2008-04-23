\timing

drop table if exists ranges_presort ;
create table ranges_presort as select prefix::prefix_range, name, shortname, state from prefixes ;
create index idx_prefix_presort on ranges_presort using gist(prefix gist_prefix_range_presort_ops);

drop table if exists ranges_jordan ;
create table ranges_jordan as select prefix::prefix_range, name, shortname, state from prefixes ;
create index idx_prefix_jordan on ranges_jordan using gist(prefix gist_prefix_range_jordan_ops);

drop table if exists ranges;
create table ranges as select prefix::prefix_range, name, shortname, state from prefixes ;
create index idx_prefix on ranges using gist(prefix gist_prefix_range_ops);

\echo
\echo select * from numbers n join ranges_presort r on r.prefix @> n.number;
explain analyze select * from numbers n join ranges_presort r on r.prefix @> n.number;
\echo

\echo select * from numbers n join ranges_jordan r on r.prefix @> n.number;
explain analyze select * from numbers n join ranges_jordan r on r.prefix @> n.number;
\echo

\echo select * from numbers n join ranges r on r.prefix @> n.number;
explain analyze select * from numbers n join ranges r on r.prefix @> n.number;
\echo
