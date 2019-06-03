set client_min_messages = warning;
/* reset e_f_d to 0 in PG12+ */
set extra_float_digits = 0;

create table prefixes (
       prefix    text primary key,
       name      text not null,
       shortname text,
       state     char default 'S',

       check( state in ('S', 'R') )
);
comment on column prefixes.state is 'S: assigned - R: reserved';

\copy prefixes from 'prefixes.fr.csv' with delimiter ';' csv quote '"'

create table ranges as select prefix::prefix_range, name, shortname, state from prefixes ;
create index idx_prefix on ranges using gist(prefix gist_prefix_range_ops);
analyze ranges;

set enable_seqscan to off;
select * from ranges where prefix @> '0146640123';
select * from ranges where prefix @> '0100091234';

set enable_seqscan to on;
select * from ranges where prefix @> '0146640123';
select * from ranges where prefix @> '0100091234';

select a, b, pr_penalty(a::prefix_range, b::prefix_range)
  from (values('095[4-5]', '0[8-9]'),
              ('095[4-5]', '0[0-9]'),
              ('095[4-5]', '[0-3]'),
              ('095[4-5]', '0'),
              ('095[4-5]', '[0-9]'),
              ('095[4-5]', '0[1-5]'),
              ('095[4-5]', '32'),
              ('095[4-5]', '[1-3]')) as t(a, b)
order by 3 asc;

create table numbers(number text primary key);

insert into numbers
  select '01' || substr(regexp_replace(md5(i::text), '[a-f]', '', 'g'), 1, 8)
   from generate_series(1, 5000) i;
analyze numbers;

select count(*) from numbers n join ranges r on r.prefix @> n.number;

reset client_min_messages;

-- Debian Bug 690160 regarding the symetry of <@ and @>
SELECT count(*) FROM ranges WHERE prefix <@ '01000';
SELECT count(*) FROM ranges WHERE prefix @> '01000';
SELECT count(*) FROM ranges WHERE '01000' <@ prefix;
SELECT count(*) FROM ranges WHERE '01000' @> prefix;
SELECT count(*) FROM ranges WHERE '010009888' @> prefix;
SELECT count(*) FROM ranges WHERE '010009888' <@ prefix;
SELECT count(*) FROM ranges WHERE prefix @> '010009888';
SELECT count(*) FROM ranges WHERE prefix <@ '010009888';
