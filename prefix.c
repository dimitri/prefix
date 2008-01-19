/**
 * Prefix opclass allows to efficiently index a prefix table with
 * GiST.
 *
 * More common use case is telephony prefix searching for cost or
 * routing.
 *
 * Many thanks to AndrewSN, who provided great amount of help in the
 * writting of this opclass, on the PostgreSQL internals, GiST inner
 * working and prefix search analyses.
 *
 * $Id: prefix.c,v 1.1 2008/01/19 15:30:08 dim Exp $
 */

#include <stdio.h>
#include "postgres.h"

#include "access/gist.h"
#include "access/skey.h"
#include "utils/elog.h"
#include "utils/palloc.h"
#include "utils/builtins.h"
#include <math.h>

#define  DEBUG

PG_MODULE_MAGIC;

/**
 * Operator prefix @> query and query <@ prefix
 */
Datum prefix_contains(PG_FUNCTION_ARGS);
Datum prefix_contained_by(PG_FUNCTION_ARGS);
Datum greater_prefix(PG_FUNCTION_ARGS);

/**
 * GiST support methods
 */
Datum gprefix_consistent(PG_FUNCTION_ARGS);
Datum gprefix_compress(PG_FUNCTION_ARGS);
Datum gprefix_decompress(PG_FUNCTION_ARGS);
Datum gprefix_penalty(PG_FUNCTION_ARGS);
Datum gprefix_picksplit(PG_FUNCTION_ARGS);
Datum gprefix_union(PG_FUNCTION_ARGS);
Datum gprefix_same(PG_FUNCTION_ARGS);


/**
 * prefix opclass only provides 1 operator, @>
 */
static inline
bool prefix_contains_internal(text *prefix, text *query, bool eqval)
{
  int plen, qlen = 0;
    
  if( DirectFunctionCall2(texteq,
			  PointerGetDatum(prefix), 
			  PointerGetDatum(query)) )
    return eqval;

  plen = VARSIZE(prefix) - VARHDRSZ;
  qlen = VARSIZE(query)  - VARHDRSZ;

  if(qlen < plen )
    return false;

  return memcmp(VARDATA(prefix), VARDATA(query), plen) == 0;
}

/**
 * The operator @> code
 */
PG_FUNCTION_INFO_V1(prefix_contains);
Datum
prefix_contains(PG_FUNCTION_ARGS)
{
    PG_RETURN_BOOL( prefix_contains_internal(PG_GETARG_TEXT_P(0),
					     PG_GETARG_TEXT_P(1),
					     TRUE) );
}

/**
 * The commutator, <@, using the same internal code
 */
PG_FUNCTION_INFO_V1(prefix_contained_by);
Datum
prefix_contained_by(PG_FUNCTION_ARGS)
{
    PG_RETURN_BOOL( prefix_contains_internal(PG_GETARG_TEXT_P(1),
					     PG_GETARG_TEXT_P(0),
					     TRUE) );
}

/**
 * greater_prefix returns the greater prefix of any 2 given texts
 */
static inline
text *greater_prefix_internal(text *a, text *b)
{
  int i    = 0;
  int la   = VARSIZE(a) - VARHDRSZ;
  int lb   = VARSIZE(b) - VARHDRSZ;
  char *ca = VARDATA(a);
  char *cb = VARDATA(b);

  for(i=0; i<la && i<lb && ca[i] == cb[i]; i++);
  
  /* i is the last common char position in a, or 0 */
  if( i == 0 )
    return DatumGetTextP(DirectFunctionCall1(textin, CStringGetDatum("")));
  else
    return DatumGetTextPSlice(PointerGetDatum(a), 0, i);
}

PG_FUNCTION_INFO_V1(greater_prefix);
Datum
greater_prefix(PG_FUNCTION_ARGS)
{

  PG_RETURN_POINTER( greater_prefix_internal(PG_GETARG_TEXT_P(0),
					     PG_GETARG_TEXT_P(1)) );
}


/**
 * GiST opclass methods
 */

PG_FUNCTION_INFO_V1(gprefix_consistent);
Datum
gprefix_consistent(PG_FUNCTION_ARGS)
{
    GISTENTRY *entry = (GISTENTRY *) PG_GETARG_POINTER(0);
    text *query = (text *) PG_GETARG_POINTER(1);
    StrategyNumber strategy = (StrategyNumber) PG_GETARG_UINT16(2);
    text *key = (text *) DatumGetPointer(entry->key);
    bool retval;

    /**
     * We only have 1 Strategy (operator @>)
     */ 
    Assert(strategy == 1);
    retval = prefix_contains_internal(query, key, true);

    PG_RETURN_BOOL(retval);
}

/**
 * Prefix penalty: we want the penalty to be lower for closer
 * prefixes, taking into account length difference and content
 * distance.
 *
 * For examples we want new prefix 125 to be inserted by preference in
 * the 124 branch, not in a 128 or a 256 branch.
 *
 */
PG_FUNCTION_INFO_V1(gprefix_penalty);
Datum
gprefix_penalty(PG_FUNCTION_ARGS)
{
  GISTENTRY *origentry = (GISTENTRY *) PG_GETARG_POINTER(0);
  GISTENTRY *newentry = (GISTENTRY *) PG_GETARG_POINTER(1);
  float *penalty = (float *) PG_GETARG_POINTER(2);
  
  text *orig = (text *) DatumGetPointer(origentry->key);
  text *new  = (text *) DatumGetPointer(newentry->key);
  text *gp;

  int  nlen, olen, gplen, dist, lastcd = 0;

  if( DirectFunctionCall2(texteq, 
			  PointerGetDatum(new), 
			  PointerGetDatum(orig)) ) {

#ifdef DEBUG
    elog(NOTICE, "gprefix_penalty(%s, %s) = 0", 
	 DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(orig))),
	 DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(new))));
#endif
    *penalty = 0;
    PG_RETURN_POINTER(penalty);
  }
  else {
    /**
     * Consider greater common prefix length, the greater the better,
     * then for a distance of 1 (only last prefix char is different),
     * consider char code distance.
     */
    nlen  = VARSIZE(new)  - VARHDRSZ;
    olen  = VARSIZE(orig) - VARHDRSZ;
    gp    = greater_prefix_internal(orig, new);
    gplen = VARSIZE(gp) - VARHDRSZ;

    dist   = nlen - gplen;
    lastcd = 0;

    if( dist == 1 ) {
      char *o = VARDATA(orig);
      char *n = VARDATA(new);
      lastcd  = abs((int)o[olen] - (int)n[nlen]);
    }
    *penalty = (dist + lastcd - gplen);
  }

#ifdef DEBUG
  elog(NOTICE, "gprefix_penalty(%s, %s) [%d %d %d] = %f", 
       DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(orig))),
       DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(new))),
       gplen, dist, lastcd,
       *penalty);
#endif

  PG_RETURN_POINTER(penalty);
}

/**
 * prefix picksplit implementation
 *
 * Let's try a very naive first implementation
 *
 */
PG_FUNCTION_INFO_V1(gprefix_picksplit);
Datum
gprefix_picksplit(PG_FUNCTION_ARGS)
{
    GistEntryVector *entryvec = (GistEntryVector *) PG_GETARG_POINTER(0);
    OffsetNumber maxoff = entryvec->n - 2;
    GIST_SPLITVEC *v = (GIST_SPLITVEC *) PG_GETARG_POINTER(1);
    GISTENTRY *ent = entryvec->vector;

    int	nbytes;
    OffsetNumber i;
    OffsetNumber split_at;
    OffsetNumber *listL;
    OffsetNumber *listR;
    text *cur;
    text *unionL;
    text *unionR;

#ifdef DEBUG
    elog(NOTICE, "gprefix_picksplit()");
#endif

    nbytes = (maxoff + 2) * sizeof(OffsetNumber);
    listL = (OffsetNumber *) palloc(nbytes);
    listR = (OffsetNumber *) palloc(nbytes);

    split_at = FirstOffsetNumber + (maxoff - FirstOffsetNumber + 1)/2;
    v->spl_nleft = v->spl_nright = 0;

    v->spl_left = listL;
    v->spl_right = listR;

    unionL = (text *) DatumGetPointer(ent[OffsetNumberNext(FirstOffsetNumber)].key);
    
    for (i = FirstOffsetNumber; i < split_at; i = OffsetNumberNext(i)) {
      cur = (text *) DatumGetPointer(ent[i].key);
      v->spl_left[v->spl_nleft++] = i;
      unionL = greater_prefix_internal(unionL, cur);
    }

    unionR = (text *)DatumGetPointer(ent[i].key);
    for (; i <= maxoff; i = OffsetNumberNext(i)) {
      cur = (text *) DatumGetPointer(ent[i].key);
      v->spl_right[v->spl_nright++] = i;
      unionR = greater_prefix_internal(unionR, cur);
    }

    v->spl_ldatum = PointerGetDatum(unionL);
    v->spl_rdatum = PointerGetDatum(unionR);
	
    PG_RETURN_POINTER(v);
}

/**
 * Prefix union should return the greatest common prefix.
 */
PG_FUNCTION_INFO_V1(gprefix_union);
Datum
gprefix_union(PG_FUNCTION_ARGS)
{
    GistEntryVector *entryvec = (GistEntryVector *) PG_GETARG_POINTER(0);
    GISTENTRY *ent = entryvec->vector;

    text *out, *tmp, *gp;
    int	numranges, i = 0;

    numranges = entryvec->n;
    tmp = (text *) DatumGetPointer(ent[0].key);
    out = tmp;

    if( numranges == 1 ) {
      /**
       * We need to return a palloc()ed copy of ent[0].key (==tmp)
       */
      out = DatumGetTextPCopy(PointerGetDatum(tmp));
#ifdef DEBUG
      elog(NOTICE, "gprefix_union(%s) == %s",
	   DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(tmp))),
	   DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(out))));
#endif
      PG_RETURN_POINTER(out);
    }
  
    for (i = 1; i < numranges; i++) {
      tmp = (text *) DatumGetPointer(ent[i].key);
      gp = greater_prefix_internal(out, tmp);
#ifdef DEBUG
      elog(NOTICE, "gprefix_union: gp(%s, %s) == %s", 
	   DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(out))),
	   DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(tmp))),
	   DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(gp))));
#endif
      out = gp;
    }

#ifdef DEBUG
    elog(NOTICE, "gprefix_union: %s", 
	 DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(out))));
#endif

    PG_RETURN_POINTER(out);
}

/**
 * GiST Compress and Decompress methods for prefix
 * do not do anything.
 */
PG_FUNCTION_INFO_V1(gprefix_compress);
Datum
gprefix_compress(PG_FUNCTION_ARGS)
{
    PG_RETURN_POINTER(PG_GETARG_POINTER(0));
}

PG_FUNCTION_INFO_V1(gprefix_decompress);
Datum
gprefix_decompress(PG_FUNCTION_ARGS)
{
    PG_RETURN_POINTER(PG_GETARG_POINTER(0));
}

/**
 * Equality methods
 */
PG_FUNCTION_INFO_V1(gprefix_same);
Datum
gprefix_same(PG_FUNCTION_ARGS)
{
    text *v1 = (text *) PG_GETARG_POINTER(0);
    text *v2 = (text *) PG_GETARG_POINTER(1);
    bool *result = (bool *) PG_GETARG_POINTER(2);

    *result = DirectFunctionCall2(texteq,
				  PointerGetDatum(v1), 
				  PointerGetDatum(v2));

    PG_RETURN_POINTER(result);    
}

