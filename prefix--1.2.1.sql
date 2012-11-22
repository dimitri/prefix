---
--- prefix_range datatype installation
---

CREATE OR REPLACE FUNCTION prefix_range_in(cstring)
RETURNS prefix_range
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_out(prefix_range)
RETURNS cstring
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_recv(internal)
RETURNS prefix_range
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_send(prefix_range)
RETURNS bytea
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE TYPE prefix_range (
	INPUT   = prefix_range_in,
	OUTPUT  = prefix_range_out,
	RECEIVE = prefix_range_recv,
	SEND    = prefix_range_send
);
COMMENT ON TYPE prefix_range IS 'prefix range: (prefix)?([a-b])?';

CREATE OR REPLACE FUNCTION prefix_range(text, text, text)
RETURNS prefix_range
AS '$libdir/prefix', 'prefix_range_init'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range(text)
RETURNS prefix_range
AS '$libdir/prefix', 'prefix_range_cast_from_text'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION text(prefix_range)
RETURNS text
AS '$libdir/prefix', 'prefix_range_cast_to_text'
LANGUAGE C IMMUTABLE STRICT;

CREATE CAST (text as prefix_range) WITH FUNCTION prefix_range(text) AS IMPLICIT;
CREATE CAST (prefix_range as text) WITH FUNCTION text(prefix_range);


CREATE OR REPLACE FUNCTION prefix_range_eq(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_neq(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_lt(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_le(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_gt(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_ge(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_cmp(prefix_range, prefix_range)
RETURNS integer
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_overlaps(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_contains(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_contains_strict(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_contained_by(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_contained_by_strict(prefix_range, prefix_range)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_union(prefix_range, prefix_range)
RETURNS prefix_range
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_range_inter(prefix_range, prefix_range)
RETURNS prefix_range
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION length(prefix_range)
RETURNS int
AS '$libdir/prefix', 'prefix_range_length'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION prefix_like(a prefix_range, b text) 
RETURNS bool
AS $$ 
    SELECT $1::text like $2;
$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION prefix_like(prefix_range, text) IS 'matches LIKE expression';

CREATE OR REPLACE FUNCTION prefix_not_like(a prefix_range, b text)
RETURNS bool 
AS $$ 
    SELECT $1::text not like $2; 
$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION prefix_not_like(prefix_range, text) IS 'does not match LIKE expression';

CREATE OPERATOR = (
	LEFTARG = prefix_range,
	RIGHTARG = prefix_range,
	PROCEDURE = prefix_range_eq,
	COMMUTATOR = '=',
	NEGATOR = '<>',
	RESTRICT = eqsel,
	JOIN = eqjoinsel
);
COMMENT ON OPERATOR =(prefix_range, prefix_range) IS 'equals?';

CREATE OPERATOR <> (
	LEFTARG = prefix_range,
	RIGHTARG = prefix_range,
	PROCEDURE = prefix_range_neq,
	COMMUTATOR = '<>',
	NEGATOR = '=',
	RESTRICT = neqsel,
	JOIN = neqjoinsel
);
COMMENT ON OPERATOR <>(prefix_range, prefix_range) IS 'not equals?';

CREATE OPERATOR < (
	LEFTARG = prefix_range,
	RIGHTARG = prefix_range,
	PROCEDURE = prefix_range_lt,
	COMMUTATOR = > , 
	NEGATOR = >= ,
   	RESTRICT = scalarltsel, 
	JOIN = scalarltjoinsel
);
COMMENT ON OPERATOR <(prefix_range, prefix_range) IS 'less-than';

CREATE OPERATOR <= (
	LEFTARG = prefix_range,
	RIGHTARG = prefix_range,
	PROCEDURE = prefix_range_le,
	COMMUTATOR = >= , 
	NEGATOR = > ,
   	RESTRICT = scalarltsel, 
	JOIN = scalarltjoinsel
);
COMMENT ON OPERATOR <=(prefix_range, prefix_range) IS 'less-than-or-equal';

CREATE OPERATOR > (
	LEFTARG = prefix_range,
	RIGHTARG = prefix_range,
	PROCEDURE = prefix_range_gt,
	COMMUTATOR = < , 
	NEGATOR = <= ,
   	RESTRICT = scalargtsel, 
	JOIN = scalargtjoinsel
);
COMMENT ON OPERATOR >(prefix_range, prefix_range) IS 'greater-than';

CREATE OPERATOR >= (
	LEFTARG = prefix_range,
	RIGHTARG = prefix_range,
	PROCEDURE = prefix_range_ge,
	COMMUTATOR = <= , 
	NEGATOR = < ,
   	RESTRICT = scalargtsel, 
	JOIN = scalargtjoinsel
);
COMMENT ON OPERATOR >=(prefix_range, prefix_range) IS 'greater-than-or-equal';

CREATE OPERATOR | (
	LEFTARG = prefix_range,
	RIGHTARG = prefix_range,
	PROCEDURE = prefix_range_union
);
COMMENT ON OPERATOR |(prefix_range, prefix_range) IS 'union';

CREATE OPERATOR & (
	LEFTARG = prefix_range,
	RIGHTARG = prefix_range,
	PROCEDURE = prefix_range_inter
);
COMMENT ON OPERATOR &(prefix_range, prefix_range) IS 'intersection';

CREATE OPERATOR && (
	LEFTARG = prefix_range,
	RIGHTARG = prefix_range,
	PROCEDURE = prefix_range_overlaps,
	COMMUTATOR = '&&',
	RESTRICT = areasel,
	JOIN = areajoinsel
);
COMMENT ON OPERATOR &&(prefix_range, prefix_range) IS 'overlaps?';

CREATE OPERATOR @> (
	LEFTARG    = prefix_range,
	RIGHTARG   = prefix_range,
	PROCEDURE  = prefix_range_contains,
	COMMUTATOR = '<@',
	RESTRICT   = contsel,
	JOIN       = contjoinsel
);
COMMENT ON OPERATOR @>(prefix_range, prefix_range) IS 'contains?';

CREATE OPERATOR <@ (
	LEFTARG = prefix_range,
	RIGHTARG = prefix_range,
	PROCEDURE = prefix_range_contained_by,
	COMMUTATOR = '@>',
	RESTRICT   = contsel,
	JOIN       = contjoinsel
);
COMMENT ON OPERATOR <@(prefix_range, prefix_range) IS 'contained by?';

CREATE OPERATOR ~~ (
    LEFTARG   = prefix_range,
    RIGHTARG  = text,
    PROCEDURE = prefix_like,
    NEGATOR   = '!~~',
    RESTRICT  = likesel,
    JOIN      = likejoinsel
);
COMMENT ON OPERATOR ~~(prefix_range, text) IS 'matches LIKE expression';

CREATE OPERATOR !~~ (
    LEFTARG   = prefix_range,
    RIGHTARG  = text,
    PROCEDURE = prefix_not_like,
    NEGATOR   = '~~',
    RESTRICT  = likesel,
    JOIN      = likejoinsel
);
COMMENT ON OPERATOR !~~(prefix_range, text) IS 'does not match LIKE expression';

CREATE OPERATOR CLASS btree_prefix_range_ops
DEFAULT FOR TYPE prefix_range USING btree
AS
	OPERATOR	1	< ,
	OPERATOR	2	<= ,
	OPERATOR	3	= ,
	OPERATOR	4	>= ,
	OPERATOR	5	> ,
	FUNCTION	1	prefix_range_cmp(prefix_range, prefix_range);


--
-- Up until 8.4, consistent took 3 arguments, then 5. In all cases, the
-- CREATE OPERATOR CLASS command will not check this.
--

CREATE OR REPLACE FUNCTION gpr_consistent(internal, prefix_range, smallint, oid)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION gpr_consistent(internal, prefix_range, smallint, oid, internal)
RETURNS bool
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION gpr_compress(internal)
RETURNS internal 
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION gpr_decompress(internal)
RETURNS internal 
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION gpr_penalty(internal, internal, internal)
RETURNS internal
AS '$libdir/prefix'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION pr_penalty(prefix_range, prefix_range)
RETURNS float4
AS '$libdir/prefix'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION gpr_picksplit(internal, internal)
RETURNS internal
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION gpr_picksplit_presort(internal, internal)
RETURNS internal
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION gpr_picksplit_jordan(internal, internal)
RETURNS internal
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION gpr_union(internal, internal)
RETURNS text
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION gpr_same(prefix_range, prefix_range, internal)
RETURNS internal 
AS '$libdir/prefix'
LANGUAGE C IMMUTABLE STRICT;


CREATE OPERATOR CLASS gist_prefix_range_ops
DEFAULT FOR TYPE prefix_range USING gist 
AS
	OPERATOR	1	@>,
	OPERATOR	2	<@,
	OPERATOR	3	=,
	OPERATOR	4	&&,
	FUNCTION	1	gpr_consistent (internal, prefix_range, smallint, oid, internal),
	FUNCTION	2	gpr_union (internal, internal),
	FUNCTION	3	gpr_compress (internal),
	FUNCTION	4	gpr_decompress (internal),
	FUNCTION	5	gpr_penalty (internal, internal, internal),
	FUNCTION	6	gpr_picksplit (internal, internal),
	FUNCTION	7	gpr_same (prefix_range, prefix_range, internal);

-- CREATE OPERATOR CLASS gist_prefix_range_presort_ops
-- FOR TYPE prefix_range USING gist 
-- AS
-- 	OPERATOR	1	@>,
-- 	FUNCTION	1	gpr_consistent (internal, prefix_range, smallint, oid, internal),
-- 	FUNCTION	2	gpr_union (internal, internal),
-- 	FUNCTION	3	gpr_compress (internal),
-- 	FUNCTION	4	gpr_decompress (internal),
-- 	FUNCTION	5	gpr_penalty (internal, internal, internal),
-- 	FUNCTION	6	gpr_picksplit_presort (internal, internal),
-- 	FUNCTION	7	gpr_same (prefix_range, prefix_range, internal);

-- CREATE OPERATOR CLASS gist_prefix_range_jordan_ops
-- FOR TYPE prefix_range USING gist 
-- AS
-- 	OPERATOR	1	@>,
-- 	FUNCTION	1	gpr_consistent (internal, prefix_range, smallint, oid, internal),
-- 	FUNCTION	2	gpr_union (internal, internal),
-- 	FUNCTION	3	gpr_compress (internal),
-- 	FUNCTION	4	gpr_decompress (internal),
-- 	FUNCTION	5	gpr_penalty (internal, internal, internal),
-- 	FUNCTION	6	gpr_picksplit_jordan (internal, internal),
-- 	FUNCTION	7	gpr_same (prefix_range, prefix_range, internal);
