-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "ALTER EXTENSION prefix UPDATE TO '1.2.0'" to load this file. \quit

-- version 1.2.0 adds restrict and join properties to the operator <@
-- (prefix_range, prefix_range), but don't automatically update that here:
--
-- due to dependencies, that would mean dropping all your prefix_range
-- columns and having to install the extension all over again. please
-- consider doing so yourself if you need it.

