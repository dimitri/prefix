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
 * $Id: prefix.c,v 1.4 2008/01/22 17:47:49 dim Exp $
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
 * - Operator prefix @> query and query <@ prefix
 * - greater_prefix, exposed as a func and an aggregate
 * - prefix_penalty, exposed for testing purpose
 */
Datum prefix_contains(PG_FUNCTION_ARGS);
Datum prefix_contained_by(PG_FUNCTION_ARGS);
Datum greater_prefix(PG_FUNCTION_ARGS);
Datum prefix_penalty(PG_FUNCTION_ARGS);

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
 * penalty internal function, which is called in more places than just
 * gist penalty() function, namely picksplit() uses it too.
 *
 * Consider greater common prefix length, the greater the better, then
 * for a distance of 1 (only last prefix char is different), consider
 * char code distance.
 *
 * With gplen the size of the greatest common prefix and dist the char
 * code distance, the following maths should do (per AndrewSN):
 *
 * penalty() = dist / (256 ^ gplen)
 *
 * penalty(01,   03) == 2 / (256^1)
 * penalty(123, 125) == 2 / (256^2)
 * penalty(12,   56) == 4 / (256^0)
 * penalty(0, 17532) == 1 / (256^0)
 *
 * 256 is then number of codes any text position (char) can admit.
 */
static inline
float prefix_penalty_internal(text *orig, text *new)
{
  float penalty;
  text *gp;
  int  nlen, olen, gplen, dist = 0;

  olen  = VARSIZE(orig) - VARHDRSZ;
  nlen  = VARSIZE(new)  - VARHDRSZ;
  gp    = greater_prefix_internal(orig, new);
  gplen = VARSIZE(gp) - VARHDRSZ;

  /**
   * greater_prefix length is orig length only if orig == gp
   */
  if( gplen == olen )
    penalty = 0;

  dist = 1;
  if( nlen == olen ) {
    char *o = VARDATA(orig);
    char *n = VARDATA(new);
    dist    = abs((int)o[olen-1] - (int)n[nlen-1]);
  }
  penalty = (((float)dist) / powf(256, gplen));

#ifdef DEBUG
  elog(NOTICE, "gprefix_penalty_internal(%s, %s) == %d/(256^%d) == %g", 
       DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(orig))),
       DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(new))),
       dist, gplen, penalty);
#endif

  return penalty;
}

/**
 * For testing purposes we export our penalty function to SQL
 */
PG_FUNCTION_INFO_V1(prefix_penalty);
Datum
prefix_penalty(PG_FUNCTION_ARGS)
{
  float penalty = prefix_penalty_internal(PG_GETARG_TEXT_P(0),
					  PG_GETARG_TEXT_P(1));

  PG_RETURN_FLOAT4(penalty);
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
     * and we want to avoid compiler complaints that we do not use it.
     */ 
    Assert(strategy == 1);
    (void) strategy;
    retval = prefix_contains_internal(key, query, true);

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

  *penalty = prefix_penalty_internal(orig, new);
  PG_RETURN_POINTER(penalty);
}

/**
 * prefix picksplit implementation
 *
 * The idea is to consume the SPLITVEC vector by both its start and
 * end, inserting one or two items at a time depending on relative
 * penalty() with current ends of new vectors.
 *
 * Idea and perl test script per AndreSN with some modifications by me
 * (Dimitri Fontaine).
 *
 * TODO: check whether qsort() is the right first pass. Another idea
 * (by dim, this time) being to care first about items which non-empty
 * union appears the most in the SPLITVEC vector. Perl test
 * implementation show good results on random test data.
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
    OffsetNumber offl, offr;
    OffsetNumber *listL;
    OffsetNumber *listR;
    text *curl, *curr, *gp;
    text *unionL;
    text *unionR;
    
    /**
     * Keeping track of penalties to insert into ListL or ListR, for
     * both the leftmost and the rightmost element of the remaining
     * list.
     */
    float pll, plr, prl, prr;

    /* qsort(ent, maxoff, sizeof(text *), bttextcmp); */

    nbytes = (maxoff + 2) * sizeof(OffsetNumber);
    listL = (OffsetNumber *) palloc(nbytes);
    listR = (OffsetNumber *) palloc(nbytes);
    v->spl_left  = listL;
    v->spl_right = listR;
    v->spl_nleft = v->spl_nright = 0;

    offl = FirstOffsetNumber;
    offr = maxoff;

    unionL = (text *) DatumGetPointer(ent[offl].key);
    unionR = (text *) DatumGetPointer(ent[offr].key);

    v->spl_left[v->spl_nleft++]   = offl;
    v->spl_right[v->spl_nright++] = offr;
    v->spl_left  = listL;
    v->spl_right = listR;

    for(; offl < offr; offl = OffsetNumberNext(offl), offr = OffsetNumberPrev(offr)) {
      curl = (text *) DatumGetPointer(ent[offl].key);
      curr = (text *) DatumGetPointer(ent[offr].key);

      pll = prefix_penalty_internal(unionL, curl);
      plr = prefix_penalty_internal(unionR, curl);
      prl = prefix_penalty_internal(unionL, curr);
      prr = prefix_penalty_internal(unionR, curr);

      if( pll <= plr && prl >= prr ) {
	/**
	 * curl should go to left and curr to right, unless they share
	 * a non-empty common prefix, in which case we place both curr
	 * and curl on the same side. Arbitrarily the left one.
	 */
	if( pll == plr && prl == prr ) {
	  gp = greater_prefix_internal(curl, curr);
	  if( VARSIZE(gp) - VARHDRSZ > 0 ) {
	    unionL = greater_prefix_internal(unionL, gp);
	    v->spl_left[v->spl_nleft++] = offl;
	    v->spl_left[v->spl_nleft++] = offr;
	    continue;
	  }
	}
	/**
	 * here pll < plr and prl > prr
	 */
	unionL = greater_prefix_internal(unionL, curl);
	unionR = greater_prefix_internal(unionR, curr);
	v->spl_left[v->spl_nleft++]   = offl;
	v->spl_right[v->spl_nright++] = offr;
      }
      else if( pll > plr && prl >= prr ) {
	unionR = greater_prefix_internal(unionR, curr);
	v->spl_right[v->spl_nright++] = offr;
      }
      else if( pll <= plr && prl < prr ) {
	/**
	 * Current leftmost entry is added to listL
	 */
	unionL = greater_prefix_internal(unionL, curl);
	v->spl_left[v->spl_nleft++] = offl;
      }
      else if( (pll - plr) < (prr - prl) ) {
	/**
	 * All entries still in the list go into listL
	 */
	for(; offl < maxoff; offl = OffsetNumberNext(offl)) {
	  curl   = (text *) DatumGetPointer(ent[offl].key);
	  unionL = greater_prefix_internal(unionL, curl);
	  v->spl_left[v->spl_nleft++] = offl;
	}
      }
      else {
	/**
	 * All entries still in the list go into listR
	 */
	for(; offl < maxoff; offl = OffsetNumberNext(offl)) {
	  curl   = (text *) DatumGetPointer(ent[offl].key);
	  unionR = greater_prefix_internal(unionR, curl);
	  v->spl_right[v->spl_nright++] = offl;
	}
      }
    }
    
    if( offl == offr ) {
      curl = (text *) DatumGetPointer(ent[offl].key);
      pll  = prefix_penalty_internal(unionL, curl);
      plr  = prefix_penalty_internal(unionR, curl);

      if( pll < plr || (pll == plr && v->spl_nleft < v->spl_nright) ) {
	for(; offl < maxoff; offl = OffsetNumberNext(offl)) {
	  curl   = (text *) DatumGetPointer(ent[offl].key);
	  unionL = greater_prefix_internal(unionL, curl);
	  v->spl_left[v->spl_nleft++] = offl;
	}
      }
      else {
	for(; offl < maxoff; offl = OffsetNumberNext(offl)) {
	  curl   = (text *) DatumGetPointer(ent[offl].key);
	  unionR = greater_prefix_internal(unionR, curl);
	  v->spl_right[v->spl_nright++] = offl;
	}
      }
    }

    v->spl_ldatum = PointerGetDatum(unionL);
    v->spl_rdatum = PointerGetDatum(unionR);

#ifdef DEBUG
    elog(NOTICE, "gprefix_picksplit(): %s %d %s %d",
	   DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(unionL))),
	 v->spl_nleft,
	 DatumGetCString(DirectFunctionCall1(textout,PointerGetDatum(unionR))),
	 v->spl_nright);
#endif
	
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

