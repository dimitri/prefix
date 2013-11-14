explain (costs off) select * from ranges where prefix @> '0146640123';
explain (costs off) select * from ranges where prefix @> '0146640123' order by length(prefix) desc limit 1;
explain (costs off) select * from ranges where prefix @> '0100091234';
explain (costs off) select * from ranges where prefix @> '0100091234' order by length(prefix) desc limit 1;

explain (costs off) select * from numbers n join ranges r on r.prefix @> n.number;

explain (costs off) select count(*) from tst where pref <@ '55';
