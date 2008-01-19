create table prefixes (
       prefix    text primary key,
       name      text not null,
       shortname text,
       state     char default 'S',

       check( state in ('S', 'R') )
);

comment on column prefixes.state is 'S: attribué - R: réservé';