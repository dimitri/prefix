-- operators
select a, b,
   a <= b as "<=", a < b as "<", a = b as "=", a <> b as "<>", a >= b as ">=", a > b as ">",
   a @> b as "@>", a <@ b as "<@", a && b as "&&"
from  (select a::prefix_range, b::prefix_range
         from (values('123', '123'),
                     ('123', '124'),
                     ('123', '123[4-5]'),
                     ('123[4-5]', '123[2-7]'),
                     ('123', '[2-3]')) as t(a, b)
      ) as x;

-- transitivity
select a, b, c, a <= b as "a <= b", b <= c as "b <= c", a <= c as "a <= c"
from  (select a::prefix_range, b::prefix_range, c::prefix_range
         from (values('123', '123', '123'),
                     ('123', '124', '125'),
                     ('123', '123[4-5]', '123[4-6]'),
                     ('123[4-5]', '123[2-7]', '123[1-8]'),
                     ('123', '[2-3]', '4')) as t(a, b, c)
      ) as x;

-- set operations
select a, b, a | b as union, a & b as intersect
  from  (select a::prefix_range, b::prefix_range
           from (values('123', '123'),
                       ('123', '124'),
                       ('123', '123[4-5]'),
                       ('123[4-5]', '123[2-7]'),
                       ('123', '[2-3]')) as t(a, b)
        ) as x;

-- casting to and from text
select prefix_range('123');
select prefix_range('123[4-5]');
select prefix_range('[2-3]');
select prefix_range('123', '4', '5');
select length('12345'::prefix_range);
select length('12345[]'::prefix_range);
select length('123[4-5]'::prefix_range);
select length('1234'::prefix_range);
\dC *prefix*
