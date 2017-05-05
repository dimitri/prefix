/*
 * These tests rely on the pgtap framework from http://pgtap.org
 *
 * Run with: pg_prove -U postgres -d test_prefix unit-test.sql
 *
 * The first colum of every SELECT that uses one of the test functions is
 * scanned for a string like "ok 42" so using more than one "is()" does
 * not work. The columns have to be converted to rows using unnest(array[...]).
 *
 */

-- Prepare environment
DROP SCHEMA IF EXISTS pgtap CASCADE;
DROP SCHEMA IF EXISTS prefix CASCADE;
DROP SCHEMA IF EXISTS unit_test CASCADE;
DROP EXTENSION IF EXISTS gevel CASCADE;
DROP EXTENSION IF EXISTS pgtap CASCADE;
DROP EXTENSION IF EXISTS prefix CASCADE;
CREATE SCHEMA pgtap;
CREATE SCHEMA prefix;
CREATE SCHEMA unit_test;
CREATE EXTENSION pgtap WITH SCHEMA pgtap;
SET search_path = unit_test, prefix, pgtap, public; -- public for gevel

-- Small helper function
CREATE OR REPLACE FUNCTION expl_ana(query text) RETURNS text AS $$
DECLARE
  x text;
BEGIN
  EXECUTE 'EXPLAIN (FORMAT XML, ANALYZE) ' || query INTO x;
  return x;
END
$$ LANGUAGE plpgsql;

-- Start Tests
SELECT plan(150);


-- Ensure (esp. during development) that the old code is really unloaded.
SELECT hasnt_type('prefix_range');
CREATE EXTENSION prefix WITH SCHEMA prefix;
SELECT has_type('prefix_range');
SELECT is('1.2.0', extversion) FROM pg_catalog.pg_extension WHERE extname = 'prefix';

--
-- Test Operators
--
-- Based on the following table from README.md but with some more tests.
--
SELECT diag('basics - operators');
SELECT
  unnest(array[
    is(a <= b, is_le,           a || ' <= ' || b),
    is(a < b,  is_lt,           a || ' <  ' || b),
    is(a = b,  is_eq,           a || ' =  ' || b),
    is(a <> b, is_ne,           a || ' <> ' || b),
    is(a >= b, is_ge,           a || ' >= ' || b),
    is(a > b,  is_gt,           a || ' >  ' || b),
    is(a @> b, is_cs,           a || ' @> ' || b),
    is(a <@ b, is_cd,           a || ' <@ ' || b),
    is(a && b, is_ol,           a || ' && ' || b),
    is((a | b)::text, v_un,     a || ' |  ' || b),
    is((a & b)::text, v_is,     a || ' &  ' || b)
  ])
FROM
  (SELECT
     a::prefix_range, b::prefix_range,
                                is_le, is_lt, is_eq, is_ne, is_ge, is_gt, is_cs, is_cd, is_ol,  v_un,       v_is
   FROM
    (values
      ('123',      '123[0-9]',  true,  true,  false, true,  false, false, true,  false, true,   '123',      '123[0-9]'),
      ('123',      '123[]',     true,  false, true,  false, true,  false, true,  true,  true,   '123',      '123'),
      ('123',      '123',       true,  false, true,  false, true,  false, true,  true,  true,   '123',      '123'),
      ('123',      '124',       true,  true,  false, true,  false, false, false, false, false,  '12[3-4]',  ''),
      ('125',      '123',       false, false, false, true,  true,  true,  false, false, false,  '12[3-5]',  ''),
      ('123',      '123[4-5]',  true,  true,  false, true,  false, false, true,  false, true,   '123',      '123'),
      ('123[4-5]', '123[2-7]',  false, false, false, true,  true,  true,  false, true,  true,   '123[2-7]', '123[4-5]'),
      ('123',      '[2-3]',     true,  true,  false, true,  false, false, false, false, false,  '[1-3]',    '')
    ) as tmp(a, b, is_le, is_lt, is_eq, is_ne, is_ge, is_gt, is_cs, is_cd, is_ol, v_un, v_is)
  ) as tmp2
;

-- Casting from and to text
SELECT diag('basics - casting');
SELECT is(prefix_range('123'), '123');
SELECT is(prefix_range('123[4-5]'), '123[4-5]');
SELECT is(prefix_range('[2-3]'), '[2-3]');
SELECT is(prefix_range('123', '4', '5'), '123[4-5]'::prefix_range); -- constructor
SELECT cast_context_is('text', 'prefix_range', 'implicit');
SELECT cast_context_is('prefix_range', 'text', 'explicit');
SELECT is(length('12345'::prefix_range), 5);
SELECT is(length('12345[]'::prefix_range), 5);
SELECT is(length('123[4-5]'::prefix_range), 5);
SELECT is(length('1234'::prefix_range), 4);


-- Check transitive behaviour
SELECT diag('basics - transitive behaviour');
SELECT
  unnest(array[
    is(a <= b, a_le_b,          a || ' <= ' || b),
    is(b <= c, b_le_c,          b || ' <= ' || c),
    is(a <= c, a_le_c,          a || ' <= ' || c)
  ])
FROM
  (SELECT
     a::prefix_range, b::prefix_range, c::prefix_range, a_le_b, b_le_c, a_le_c
   FROM
    (values
      ('123',      '123',      '123',      true,  true,  true),
      ('123',      '124',      '125',      true,  true,  true),
      ('123',      '123[4-5]', '123[4-6]', true,  true,  true),
      ('123[4-5]', '123[2-7]', '123[1-8]', false, false, false),
      ('123',      '[2-3]',    '4',        true,  true,  true)
    ) as tmp(a, b, c, a_le_b, b_le_c, a_le_c)
  ) as tmp2
;

--
-- Tests from "falcon.sql"
--
-- Check if the GIST index is actually used and if the same number of rows is found.
SELECT diag('performance - falcon.sql');

CREATE TABLE falcon (prefix prefix_range);
INSERT INTO falcon
  SELECT trim(to_char(i, '00000'))
    FROM generate_series(1, 99999) as i;

PREPARE falcon_stmt AS SELECT count(*) FROM falcon WHERE prefix <@ '55';

SELECT is(count(*)::int, 1000) FROM falcon WHERE prefix <@ '55';
SELECT alike(expl, '%<Node-Type>Seq Scan</Node-Type>%')
  FROM expl_ana($$ SELECT count(*) FROM falcon WHERE prefix <@ '55' $$) as tmp(expl);
-- there is no performs_not_ok()

CREATE INDEX falcon_idx ON falcon USING gist (prefix);
SELECT index_is_type('falcon_idx', 'gist');

SELECT is(count(*)::int, 1000) FROM falcon WHERE prefix <@ '55';
SELECT alike(expl, '%<Node-Type>Bitmap Index Scan</Node-Type>%<Index-Name>falcon_idx</Index-Name>%')
  FROM expl_ana($$ SELECT count(*) FROM falcon WHERE prefix <@ '55' $$) as tmp(expl);
SELECT performs_ok('falcon_stmt', 3); -- 2ms (on my Desktop)

--
-- Tests with prefixes.fr.csv from TESTS.md
--
SELECT diag('performance - prefixes.fr.csv');
CREATE TABLE prefixes (
  prefix    text primary key,
  name      text not null,
  shortname text,
  state     char default 'S',
  check(state in ('S', 'R'))
);
\copy prefixes from 'prefixes.fr.csv' with delimiter ';' csv quote '"'
SELECT is(count(*)::int, 11966) FROM prefixes;

CREATE TABLE ranges AS SELECT prefix::prefix_range, name, shortname, state from prefixes;
CREATE INDEX idx_prefix ON ranges USING gist(prefix gist_prefix_range_ops);
SELECT is(count(*)::int, 11966) FROM ranges;

ANALYZE;

-- Debian Bug 690160 regarding the symetry of <@ and @>
SELECT is(count(*)::int, 9) FROM ranges WHERE prefix <@ '01000';
SELECT is(count(*)::int, 0) FROM ranges WHERE prefix @> '01000';
SELECT is(count(*)::int, 0) FROM ranges WHERE '01000' <@ prefix;
SELECT is(count(*)::int, 9) FROM ranges WHERE '01000' @> prefix;
SELECT is(count(*)::int, 0) FROM ranges WHERE '010009888' @> prefix;
SELECT is(count(*)::int, 1) FROM ranges WHERE '010009888' <@ prefix;
SELECT is(count(*)::int, 1) FROM ranges WHERE prefix @> '010009888';
SELECT is(count(*)::int, 0) FROM ranges WHERE prefix <@ '010009888';

-- Is index used?
SELECT is(count(*)::int, 1) FROM ranges WHERE prefix @> '0146640123';
SELECT alike(expl, '%<Node-Type>Bitmap Index Scan</Node-Type>%<Index-Name>idx_prefix</Index-Name>%')
  FROM expl_ana($$ SELECT count(*) FROM ranges WHERE prefix @> '0146640123' $$) as tmp(expl);
SELECT is(count(*)::int, 0) FROM ranges WHERE prefix <@ '0146640123';
SELECT alike(expl, '%<Node-Type>Bitmap Index Scan</Node-Type>%<Index-Name>idx_prefix</Index-Name>%')
  FROM expl_ana($$ SELECT count(*) FROM ranges WHERE prefix <@ '0146640123' $$) as tmp(expl);

-- Debian Bug 690208 regarding unused gist index when using LIMIT
-- That bug most likely only occurs with 20,000,000 entries but loading
-- those takes more time than I want to wait for a regression test.
SELECT alike(expl, '%<Node-Type>Bitmap Index Scan</Node-Type>%<Index-Name>idx_prefix</Index-Name>%')
  FROM expl_ana($$ SELECT prefix FROM ranges WHERE prefix <@ '0146640123' $$) as tmp(expl);
SELECT alike(expl, '%<Node-Type>Bitmap Index Scan</Node-Type>%<Index-Name>idx_prefix</Index-Name>%')
  FROM expl_ana($$ SELECT prefix FROM ranges WHERE prefix <@ '0146640123' ORDER BY length(prefix) desc LIMIT 1 $$) as tmp(expl);


-- Penality
SELECT
  is(pr_penalty(a::prefix_range, b::prefix_range)::numeric, p)
FROM
  (values
    ('095[4-5]', '0[8-9]', 1.52588e-05),
    ('095[4-5]', '0[0-9]', 1.52588e-05),
    ('095[4-5]', '[0-3]',  0.00390625),
    ('095[4-5]', '0',      0.00390625),
    ('095[4-5]', '[0-9]',  0.00390625),
    ('095[4-5]', '0[1-5]', 0.0078125),
    ('095[4-5]', '32',     1),
    ('095[4-5]', '[1-3]',  1)
  ) as t(a, b, p)
;


-- Check some statistics
CREATE OR REPLACE FUNCTION load_gevel() RETURNS void AS $$
BEGIN
  CREATE EXTENSION gevel; -- unofficial
EXCEPTION
  when others then
END;
$$ LANGUAGE plpgsql;
SELECT load_gevel();

SELECT
  CASE WHEN count(*) != 1
    THEN skip('Gevel extension not installed', 2)
    ELSE
      collect_tap(
        diag('performance - gevel stats'),
        alike(gist_stat('idx_prefix'), e'%leaf pages:% 68\n%'),
        alike(gist_stat('idx_prefix'), e'%invalid tuples:% 0\n%'),
        is((SELECT count(*)::int FROM gist_print('idx_prefix') as t(level int, valid bool, a prefix_range) WHERE level = 1) , 68),
        is((SELECT count(*)::int FROM gist_print('idx_prefix') as t(level int, valid bool, a prefix_range)) , 12034)
      )
  END
FROM
  pg_extension
WHERE
  extname = 'gevel'
;

-- End Tests
SELECT * FROM finish();
