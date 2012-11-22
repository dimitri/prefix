-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION prefix UPDATE TO '1.2.1'" to load this file. \quit

-- version 1.2.1 adds a LIKE operator that casts prefix_range to text

CREATE OR REPLACE FUNCTION prefix_like(a prefix_range, b text) RETURNS bool AS $$
    SELECT $1::text like $2; 
$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION prefix_like(prefix_range, text) IS 'matches LIKE expression';

CREATE OR REPLACE FUNCTION prefix_not_like(a prefix_range, b text) RETURNS bool AS $$
    SELECT $1::text not like $2; 
$$ LANGUAGE SQL IMMUTABLE STRICT;
COMMENT ON FUNCTION prefix_not_like(prefix_range, text) IS 'does not match LIKE expression';

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
