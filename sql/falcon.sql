drop table if exists tst;
create table tst ( pref prefix_range );

insert into tst
     select trim(to_char(i, '00000'))
       from generate_series(1, 99999) as i;

select count(*) from tst where pref <@ '55';

create index tst_ix on tst using gist ( pref );

set enable_seqscan = off;

select count(*) from tst where pref <@ '55';

reset enable_seqscan;
