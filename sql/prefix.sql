set client_min_messages = warning;

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

select setseed(0);
insert into numbers
  select '01' || to_char((random()*100)::int, 'FM09')
              || to_char((random()*100)::int, 'FM09')
              || to_char((random()*100)::int, 'FM09')
              || to_char((random()*100)::int, 'FM09')
   from generate_series(1, 5000);
analyze numbers;

select count(*) from numbers n join ranges r on r.prefix @> n.number;

reset client_min_messages;
