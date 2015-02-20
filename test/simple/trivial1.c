/*
 * Copyright 2015 Jeffrey Kegler
 * This file is part of Libmarpa.  Libmarpa is free software: you can
 * redistribute it and/or modify it under the terms of the GNU Lesser
 * General Public License as published by the Free Software Foundation,
 * either version 3 of the License, or (at your option) any later version.
 *
 * Libmarpa is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser
 * General Public License along with Libmarpa.  If not, see
 * http://www.gnu.org/licenses/.
 */

/* Tests of Libmarpa methods on trivial grammar */

#include <stdio.h>
#include "marpa.h"

#include "tap/basic.h"

static int
warn (const char *s, Marpa_Grammar g)
{
  printf ("%s returned %d\n", s, marpa_g_error (g, NULL));
}

static int
fail (const char *s, Marpa_Grammar g)
{
  warn (s, g);
  exit (1);
}

Marpa_Symbol_ID S_top;
Marpa_Symbol_ID S_A1;
Marpa_Symbol_ID S_A2;
Marpa_Symbol_ID S_B1;
Marpa_Symbol_ID S_B2;
Marpa_Symbol_ID S_C1;
Marpa_Symbol_ID S_C2;

/* Longest rule is <= 4 symbols */
Marpa_Symbol_ID rhs[4];

Marpa_Rule_ID R_top_1;
Marpa_Rule_ID R_top_2;
Marpa_Rule_ID R_C2_3; // highest rule id

/* For (error) messages */
char msgbuf[80];

char *
symbol_name (Marpa_Symbol_ID id)
{
  if (id == S_top) return "top";
  if (id == S_A1) return "A1";
  if (id == S_A2) return "A2";
  if (id == S_B1) return "B1";
  if (id == S_B2) return "B2";
  if (id == S_C1) return "C1";
  if (id == S_C2) return "C2";
  sprintf (msgbuf, "no such symbol: %d", id);
  return msgbuf;
}

int
is_nullable (Marpa_Symbol_ID id)
{
  if (id == S_top) return 1;
  if (id == S_A1) return 1;
  if (id == S_A2) return 1;
  if (id == S_B1) return 1;
  if (id == S_B2) return 1;
  if (id == S_C1) return 1;
  if (id == S_C2) return 1;
  return 0;
}

int
is_nulling (Marpa_Symbol_ID id)
{
  if (id == S_C1) return 1;
  if (id == S_C2) return 1;
  return 0;
}

static Marpa_Grammar
marpa_g_trivial_new(Marpa_Config *config)
{
  Marpa_Grammar g;
  g = marpa_g_new (config);
  if (!g)
    {
      Marpa_Error_Code errcode = marpa_c_error (config, NULL);
      printf ("marpa_g_new returned %d", errcode);
      exit (1);
    }

  ((S_top = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_A1 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_A2 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_B1 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_B2 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_C1 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_C2 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);

  rhs[0] = S_A1;
  ((R_top_1 = marpa_g_rule_new (g, S_top, rhs, 1)) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_A2;
  ((R_top_2 = marpa_g_rule_new (g, S_top, rhs, 1)) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_B1;
  (marpa_g_rule_new (g, S_A1, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_B2;
  (marpa_g_rule_new (g, S_A2, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_C1;
  (marpa_g_rule_new (g, S_B1, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_C2;
  (marpa_g_rule_new (g, S_B2, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);
  (marpa_g_rule_new (g, S_C1, rhs, 0) >= 0)
    || fail ("marpa_g_rule_new", g);

  ((R_C2_3 = marpa_g_rule_new (g, S_C2, rhs, 0)) >= 0)
    || fail ("marpa_g_rule_new", g);

  return g;
}

static Marpa_Error_Code
marpa_g_trivial_precompute(Marpa_Grammar g, Marpa_Symbol_ID S_start)
{
  Marpa_Error_Code rc;

  (marpa_g_start_symbol_set (g, S_start) >= 0)
    || fail ("marpa_g_start_symbol_set", g);

  rc = marpa_g_precompute (g);
  if (rc < 0)
    fail("marpa_g_precompute", g);

  return rc;
}

/* Marpa method test interface */

typedef int (*marpa_m_pointer)();

/*
    %s -- Marpa_Symbol_ID
    %r -- Marpa_Rule_ID
    %n -- Marpa_Rank
    ...
*/
typedef char *marpa_m_argspec;
typedef char *marpa_m_name;

struct marpa_method_spec {
  marpa_m_name n;
  marpa_m_pointer p;
  marpa_m_argspec as;
};

typedef struct marpa_method_spec Marpa_Method_Spec;

const Marpa_Method_Spec methspec[] = {

  { "marpa_g_start_symbol_set", &marpa_g_start_symbol_set, "%s" },
  { "marpa_g_symbol_is_start", &marpa_g_symbol_is_start, "%s" },
  { "marpa_g_start_symbol", &marpa_g_start_symbol, "" },

  { "marpa_g_symbol_is_terminal_set", &marpa_g_symbol_is_terminal_set, "%s, %i" },
  { "marpa_g_symbol_is_terminal",  &marpa_g_symbol_is_terminal, "%s" },

  { "marpa_g_highest_symbol_id", &marpa_g_highest_symbol_id, ""},

  { "marpa_g_symbol_is_accessible", &marpa_g_symbol_is_accessible, "%s" },
  { "marpa_g_symbol_is_nullable", &marpa_g_symbol_is_nullable, "%s" },
  { "marpa_g_symbol_is_nulling", &marpa_g_symbol_is_nulling, "%s" },
  { "marpa_g_symbol_is_productive", &marpa_g_symbol_is_productive, "%s" },

  { "marpa_g_rule_is_nullable", &marpa_g_rule_is_nullable, "%r" },
  { "marpa_g_rule_is_nulling", &marpa_g_rule_is_nulling, "%r" },
  { "marpa_g_rule_is_loop", &marpa_g_rule_is_loop, "%r" },

  { "marpa_g_precompute", &marpa_g_precompute, "" },

  { "marpa_g_highest_rule_id", &marpa_g_highest_rule_id, "" },
  { "marpa_g_rule_is_accessible", &marpa_g_rule_is_accessible, "%r" },
  { "marpa_g_rule_is_nullable", &marpa_g_rule_is_nullable, "%r" },
  { "marpa_g_rule_is_nulling", &marpa_g_rule_is_nulling, "%r" },
  { "marpa_g_rule_is_loop", &marpa_g_rule_is_loop, "%r" },
  { "marpa_g_rule_is_productive", &marpa_g_rule_is_productive, "%r" },
  { "marpa_g_rule_length", &marpa_g_rule_length, "%r" },
  { "marpa_g_rule_lhs", &marpa_g_rule_lhs, "%r" },
  { "marpa_g_rule_rhs", &marpa_g_rule_rhs, "%r, %i" },

  { "marpa_g_sequence_new", &marpa_g_sequence_new, "%s, %s, %s, %i, %i" },
  { "marpa_g_rule_is_proper_separation", &marpa_g_rule_is_proper_separation, "%r" },
  { "marpa_g_sequence_min", &marpa_g_sequence_min, "%r" },
  { "marpa_g_sequence_separator", &marpa_g_sequence_separator, "%r" },
  { "marpa_g_symbol_is_counted", &marpa_g_symbol_is_counted, "%s" },

  { "marpa_g_rule_rank_set", &marpa_g_rule_rank_set, "%r, %i" },
  { "marpa_g_rule_rank", &marpa_g_rule_rank, "%r" },
  { "marpa_g_rule_null_high_set", &marpa_g_rule_null_high_set, "%r, %i" },
  { "marpa_g_rule_null_high", &marpa_g_rule_null_high, "%r" },

  { "marpa_g_symbol_is_completion_event_set", &marpa_g_symbol_is_completion_event_set, "%s, %i" },
  { "marpa_g_symbol_is_completion_event", &marpa_g_symbol_is_completion_event, "%s" },
  { "marpa_g_completion_symbol_activate", &marpa_g_completion_symbol_activate, "%s, %i" },

  { "marpa_g_symbol_is_prediction_event_set", &marpa_g_symbol_is_prediction_event_set, "%s, %i" },
  { "marpa_g_symbol_is_prediction_event", &marpa_g_symbol_is_prediction_event, "%s" },
  { "marpa_g_prediction_symbol_activate", &marpa_g_prediction_symbol_activate, "%s, %i" },

  { "marpa_r_is_exhausted", &marpa_r_is_exhausted, "" },
};

static Marpa_Method_Spec
marpa_m_method_spec(const char *name)
{
  int i;
  for (i = 0; i < sizeof(methspec) / sizeof(Marpa_Method_Spec); i++)
    if ( strcmp(name, methspec[i].n ) == 0 )
      return methspec[i];
  printf("No spec yet for Marpa method %s().\n", name);
  exit(1);
}

typedef char *marpa_m_errmsg;
struct marpa_m_error {
  Marpa_Error_Code c;
  marpa_m_errmsg m;
};

typedef struct marpa_m_error Marpa_Method_Error;

const Marpa_Method_Error errspec[] = {
  { MARPA_ERR_NO_START_SYMBOL, "no start symbol" },
  { MARPA_ERR_INVALID_SYMBOL_ID, "invalid symbol id" },
  { MARPA_ERR_NO_SUCH_SYMBOL_ID, "no such symbol id" },
  { MARPA_ERR_NOT_PRECOMPUTED, "grammar not precomputed" },
  { MARPA_ERR_TERMINAL_IS_LOCKED, "terminal locked" },
  { MARPA_ERR_NULLING_TERMINAL, "nulling terminal" },
  { MARPA_ERR_PRECOMPUTED, "grammar precomputed" },
  { MARPA_ERR_SEQUENCE_LHS_NOT_UNIQUE, "sequence lhs not unique" },
  { MARPA_ERR_NOT_A_SEQUENCE, "not a sequence rule" },
  { MARPA_ERR_INVALID_RULE_ID, "invalid rule id" },
  { MARPA_ERR_NO_SUCH_RULE_ID, "no such rule id" },
};

static char *marpa_m_error_message (Marpa_Error_Code error_code)
{
  int i;
  for (i = 0; i < sizeof(errspec) / sizeof(Marpa_Method_Error); i++)
    if ( error_code == errspec[i].c )
      return errspec[i].m;
  printf("No message yet for Marpa error code %d.\n", error_code);
  exit(1);
}

/* we need a grammar to call marpa_g_error() */
static Marpa_Grammar marpa_m_g = NULL;

static int
marpa_m_grammar_set(Marpa_Grammar g) { marpa_m_g = g; }

static Marpa_Grammar
marpa_m_grammar() { return marpa_m_g; }

static int
marpa_m_test(const char* name, ...)
{
  Marpa_Method_Spec ms;

  Marpa_Grammar g;
  Marpa_Recognizer r;

  Marpa_Symbol_ID S_id, S_id1, S_id2;
  Marpa_Rule_ID R_id;
  int intarg, intarg1;

  int rv_wanted, rv_seen;
  int err_wanted, err_seen;

  char tok_buf[32];  /* strtok() */
  char desc_buf[80]; /* test description  */
  char *curr_arg;
  int curr_arg_ix;

  ms = marpa_m_method_spec(name);

  va_list args;
  va_start(args, name);

  g = NULL;
#define ARG_UNDEF 42424242
  R_id = S_id = S_id1 = S_id2 = intarg = intarg1 = ARG_UNDEF;
  if (strncmp(name, "marpa_g_", 8) == 0)
    g = va_arg(args, Marpa_Grammar);
  else if (strncmp(name, "marpa_r_", 8) == 0)
    r = va_arg(args, Marpa_Recognizer);

  /* unpack arguments */
  if (ms.as == "")
  {
    /* method dispatch based on what object is set */
    if (g != NULL) rv_seen = ms.p(g);
    else if (r != NULL) rv_seen = ms.p(r);
  }
  else
  {
    strcpy( tok_buf, ms.as );
    curr_arg = strtok(tok_buf, " ,-");
    while (curr_arg != NULL)
    {
      if (strncmp(curr_arg, "%s", 2) == 0){
        if (S_id == ARG_UNDEF) S_id = va_arg(args, Marpa_Symbol_ID);
        else if (S_id1 == ARG_UNDEF) S_id1 = va_arg(args, Marpa_Symbol_ID);
        else if (S_id2 == ARG_UNDEF) S_id2 = va_arg(args, Marpa_Symbol_ID);
      }
      else if (strncmp(curr_arg, "%r", 2) == 0)
      {
        R_id   = va_arg(args, Marpa_Rule_ID);
      }
      else if (strncmp(curr_arg, "%i", 2) == 0)
      {
        if (intarg == ARG_UNDEF) intarg = va_arg(args, int);
        else if (intarg1 == ARG_UNDEF) intarg1 = va_arg(args, int);
      }

      curr_arg = strtok(NULL, " ,-");
      curr_arg_ix++;
    }
    /* call marpa method based on argspec */
    if (strcmp(ms.as, "%s") == 0) rv_seen = ms.p(g, S_id);
    else if (strcmp(ms.as, "%r") == 0) rv_seen = ms.p(g, R_id);
    else if (strcmp(ms.as, "%s, %i") == 0) rv_seen = ms.p(g, S_id, intarg);
    else if (strcmp(ms.as, "%r, %i") == 0) rv_seen = ms.p(g, R_id, intarg);
    else if (strcmp(ms.as, "%s, %s, %s, %i, %i") == 0) rv_seen = ms.p(g, S_id, S_id1, S_id2, intarg, intarg1);
    else
    {
      printf("No method yet for argument spec %s.\n", ms.as);
      exit(1);
    }
  }

  rv_wanted = va_arg(args, int);

  /* success wanted */
  if ( rv_wanted >= 0 )
  {
    /* failure seen */
    if ( rv_seen < 0 )
    {
      sprintf(msgbuf, "%s() unexpectedly returned %d.", name, rv_seen);
      ok(0, msgbuf);
    }
    /* success seen */
    else {
      sprintf(desc_buf, "%s() succeeded", name);
      is_int( rv_wanted, rv_seen, desc_buf );
    }
  }
  /* marpa_g_rule_rank() and marpa_g_rule_rank_set() may return negative values,
     but they are actually ranks if marpa_g_error() returns MARPA_ERR_NONE.
     So, we don't count them as failures. */
  else if ( strncmp( name, "marpa_g_rule_rank", 17 ) == 0
              && marpa_g_error(g, NULL) == MARPA_ERR_NONE )
    {
      sprintf(desc_buf, "%s() succeeded", name);
      is_int( rv_wanted, rv_seen, desc_buf );
    }
  /* failure wanted */
  else
  {
    /* return value */
    err_wanted = va_arg(args, int);
    sprintf(desc_buf, "%s() failed, returned %d", name, rv_seen);
    is_int( rv_wanted, rv_seen, desc_buf );

    /* error code */
    if (g == NULL)
      g = va_arg(args, Marpa_Grammar);
    err_seen = marpa_g_error(g, NULL);

    if (err_seen == MARPA_ERR_NONE && rv_seen < 0)
    {
      sprintf(msgbuf, "%s(): marpa_g_error() returned MARPA_ERR_NONE, but return value was %d.", name, rv_seen);
      ok(0, msgbuf);
    }
    /* test error code */
    else
    {
      sprintf(desc_buf, "%s() error is: %s", name, marpa_m_error_message(err_seen));
      is_int( err_wanted, err_seen, desc_buf );
    }
  }

  va_end(args);
}

int
main (int argc, char *argv[])
{
  int rc;
  int ix;

  Marpa_Config marpa_configuration;

  Marpa_Grammar g;
  Marpa_Recognizer r;

  Marpa_Symbol_ID S_invalid, S_no_such;
  Marpa_Rule_ID R_invalid, R_no_such;
  Marpa_Rank negative_rank, positive_rank;
  int flag;

  int whatever;

  int reactivate;
  int value;
  Marpa_Symbol_ID S_predicted, S_completed;

  plan_lazy();

  marpa_c_init (&marpa_configuration);
  g = marpa_g_trivial_new(&marpa_configuration);

  /* Grammar Methods per sections of api.texi: Symbols, Rules, Sequnces, Ranks, Events */
  S_invalid = R_invalid = -1;
  S_no_such = R_no_such = 42;

  marpa_m_test("marpa_g_symbol_is_start", g, S_invalid, -2, MARPA_ERR_INVALID_SYMBOL_ID);
  marpa_m_test("marpa_g_symbol_is_start", g, S_no_such, -1, MARPA_ERR_NO_SUCH_SYMBOL_ID);
  /* Returns 0 if sym_id is not the start symbol, either because the start symbol
     is different from sym_id, or because the start symbol has not been set yet. */
  marpa_m_test("marpa_g_symbol_is_start", g, S_top, 0);
  marpa_m_test("marpa_g_start_symbol", g, -1, MARPA_ERR_NO_START_SYMBOL);

  (marpa_g_start_symbol_set (g, S_top) >= 0)
    || fail ("marpa_g_start_symbol_set", g);

  /* these must succeed after the start symbol is set */
  marpa_m_test("marpa_g_symbol_is_start", g, S_top, 1);
  marpa_m_test("marpa_g_start_symbol", g, S_top);
  marpa_m_test("marpa_g_highest_symbol_id", g, S_C2);

  /* these must return -2 and set error code to MARPA_ERR_NOT_PRECOMPUTED */
  /* Symbols */
  marpa_m_test("marpa_g_symbol_is_accessible", g, S_C2, -2, MARPA_ERR_NOT_PRECOMPUTED);
  marpa_m_test("marpa_g_symbol_is_nullable", g, S_A1, -2, MARPA_ERR_NOT_PRECOMPUTED);
  marpa_m_test("marpa_g_symbol_is_nulling", g, S_A1, -2, MARPA_ERR_NOT_PRECOMPUTED);
  marpa_m_test("marpa_g_symbol_is_productive", g, S_top, -2, MARPA_ERR_NOT_PRECOMPUTED);
  marpa_m_test("marpa_g_symbol_is_terminal", g, S_top, 0);

  /* Rules */
  marpa_m_test("marpa_g_rule_is_nullable", g, R_top_2, -2, MARPA_ERR_NOT_PRECOMPUTED);
  marpa_m_test("marpa_g_rule_is_nulling", g, R_top_2, -2, MARPA_ERR_NOT_PRECOMPUTED);
  marpa_m_test("marpa_g_rule_is_loop", g, R_C2_3, -2, MARPA_ERR_NOT_PRECOMPUTED);

  /* marpa_g_symbol_is_terminal_set() on invalid and non-existing symbol IDs
     on a non-precomputed grammar */
  marpa_m_test("marpa_g_symbol_is_terminal_set", g, S_invalid, 1, -2, MARPA_ERR_INVALID_SYMBOL_ID);
  marpa_m_test("marpa_g_symbol_is_terminal_set", g, S_no_such, 1, -1, MARPA_ERR_NO_SUCH_SYMBOL_ID);

  /* marpa_g_symbol_is_terminal_set() on a nulling symbol */
  marpa_m_test("marpa_g_symbol_is_terminal_set", g, S_C1, 1, 1);
  /* can't change terminal status after it's been set */
  marpa_m_test("marpa_g_symbol_is_terminal_set", g, S_C1, 0, -2, MARPA_ERR_TERMINAL_IS_LOCKED);

  marpa_m_test("marpa_g_precompute", g, -2, MARPA_ERR_NULLING_TERMINAL);

  /* terminals are locked after setting, so we recreate the grammar */
  marpa_g_unref(g);
  g = marpa_g_trivial_new(&marpa_configuration);

  marpa_m_test("marpa_g_precompute", g, -2, MARPA_ERR_NO_START_SYMBOL);

  marpa_g_trivial_precompute(g, S_top);
  ok(1, "precomputation succeeded");

  /* Symbols -- status accessors must succeed on precomputed grammar */
  marpa_m_test("marpa_g_symbol_is_accessible", g, S_C2, 1);
  marpa_m_test("marpa_g_symbol_is_nullable", g, S_A1, 1);
  marpa_m_test("marpa_g_symbol_is_nulling", g, S_A1, 1);
  marpa_m_test("marpa_g_symbol_is_productive", g, S_top, 1);
  marpa_m_test("marpa_g_symbol_is_start", g, S_top, 1);
  marpa_m_test("marpa_g_symbol_is_terminal", g, S_top, 0);

  /* terminal and start symbols can't be set on precomputed grammar */
  marpa_m_test("marpa_g_symbol_is_terminal_set", g, S_top, 0, -2, MARPA_ERR_PRECOMPUTED);
  marpa_m_test("marpa_g_start_symbol_set", g, S_top, -2, MARPA_ERR_PRECOMPUTED);

  /* Rules */
  marpa_m_test("marpa_g_highest_rule_id", g, R_C2_3);
  marpa_m_test("marpa_g_rule_is_accessible", g, R_top_1, 1);
  marpa_m_test("marpa_g_rule_is_nullable", g, R_top_2, 1);
  marpa_m_test("marpa_g_rule_is_nulling", g, R_top_2, 1);
  marpa_m_test("marpa_g_rule_is_loop", g, R_C2_3, 0);
  marpa_m_test("marpa_g_rule_is_productive", g, R_C2_3, 1);
  marpa_m_test("marpa_g_rule_length", g, R_top_1, 1);
  marpa_m_test("marpa_g_rule_length", g, R_C2_3, 0);
  marpa_m_test("marpa_g_rule_lhs", g, R_top_1, S_top);
  marpa_m_test("marpa_g_rule_rhs", g, R_top_1, 0, S_A1);
  marpa_m_test("marpa_g_rule_rhs", g, R_top_2, 0, S_A2);

  /* invalid/no such rule id error handling */
  const char *marpa_g_rule_accessors[] = {
    "marpa_g_rule_is_accessible", "marpa_g_rule_is_nullable",
    "marpa_g_rule_is_nulling", "marpa_g_rule_is_loop", "marpa_g_rule_is_productive",
    "marpa_g_rule_length", "marpa_g_rule_lhs",
  };
  for (ix = 0; ix < sizeof(marpa_g_rule_accessors) / sizeof(char *); ix++)
  {
    marpa_m_test(marpa_g_rule_accessors[ix], g, R_invalid, -2, MARPA_ERR_INVALID_RULE_ID);
    marpa_m_test(marpa_g_rule_accessors[ix], g, R_no_such, -1, MARPA_ERR_NO_SUCH_RULE_ID);
  }
  marpa_m_test("marpa_g_rule_rhs", g, R_invalid, 0, -2, MARPA_ERR_INVALID_RULE_ID);
  marpa_m_test("marpa_g_rule_rhs", g, R_no_such, 0, -1, MARPA_ERR_NO_SUCH_RULE_ID);

  /* Sequences */
  /* try to add a nulling sequence, and make sure that it fails with an appropriate
     error code -- http://irclog.perlgeek.de/marpa/2015-02-13#i_10111831  */

  /* recreate the grammar */
  marpa_g_unref(g);
  g = marpa_g_trivial_new(&marpa_configuration);

  /* try to add a nulling sequence */
  marpa_m_test("marpa_g_sequence_new", g, S_top, S_B1, S_B2, 0, MARPA_PROPER_SEPARATION,
    -2, MARPA_ERR_SEQUENCE_LHS_NOT_UNIQUE);

  /* test error codes of other sequence methods */
  /* non-sequence rule id */
  marpa_m_test("marpa_g_rule_is_proper_separation", g, R_top_1, 0);
  marpa_m_test("marpa_g_sequence_min", g, R_top_1, -1, MARPA_ERR_NOT_A_SEQUENCE);
  marpa_m_test("marpa_g_sequence_separator", g, R_top_1, -2, MARPA_ERR_NOT_A_SEQUENCE);
  marpa_m_test("marpa_g_symbol_is_counted", g, S_top, 0);

  /* invalid/no such rule id error handling */
  marpa_m_test("marpa_g_sequence_separator", g, R_invalid, -2, MARPA_ERR_INVALID_RULE_ID);
  marpa_m_test("marpa_g_sequence_separator", g, R_no_such, -2, MARPA_ERR_NO_SUCH_RULE_ID);

  marpa_m_test("marpa_g_sequence_min", g, R_invalid, -2, MARPA_ERR_INVALID_RULE_ID);
  marpa_m_test("marpa_g_sequence_min", g, R_no_such, -2, MARPA_ERR_NO_SUCH_RULE_ID);

  marpa_m_test("marpa_g_rule_is_proper_separation", g, R_invalid, -2, MARPA_ERR_INVALID_RULE_ID);
  marpa_m_test("marpa_g_rule_is_proper_separation", g, R_no_such, -1, MARPA_ERR_NO_SUCH_RULE_ID);

  marpa_m_test("marpa_g_symbol_is_counted", g, S_invalid, -2, MARPA_ERR_INVALID_SYMBOL_ID);
  marpa_m_test("marpa_g_symbol_is_counted", g, S_no_such, -1, MARPA_ERR_NO_SUCH_SYMBOL_ID);

  /* Ranks */
  negative_rank = -1;
  marpa_m_test("marpa_g_rule_rank_set", g, R_top_1, negative_rank, negative_rank);
  marpa_m_test("marpa_g_rule_rank", g, R_top_1, negative_rank);

  positive_rank = 1;
  marpa_m_test("marpa_g_rule_rank_set", g, R_top_2, positive_rank, positive_rank);
  marpa_m_test("marpa_g_rule_rank", g, R_top_2, positive_rank);

  flag = 1;
  marpa_m_test("marpa_g_rule_null_high_set", g, R_top_2, flag, flag);
  marpa_m_test("marpa_g_rule_null_high", g, R_top_2, flag);

  /* invalid/no such rule id error handling */
  marpa_m_test("marpa_g_rule_rank_set", g, R_invalid, positive_rank, -2, MARPA_ERR_INVALID_RULE_ID);
  marpa_m_test("marpa_g_rule_rank_set", g, R_no_such, negative_rank, -2, MARPA_ERR_NO_SUCH_RULE_ID);

  marpa_m_test("marpa_g_rule_rank", g, R_invalid, -2, MARPA_ERR_INVALID_RULE_ID);
  marpa_m_test("marpa_g_rule_rank", g, R_no_such, -2, MARPA_ERR_NO_SUCH_RULE_ID);

  marpa_m_test("marpa_g_rule_null_high_set", g, R_invalid, flag, -2, MARPA_ERR_INVALID_RULE_ID);
  marpa_m_test("marpa_g_rule_null_high_set", g, R_no_such, flag, -1, MARPA_ERR_NO_SUCH_RULE_ID);

  marpa_m_test("marpa_g_rule_null_high", g, R_invalid, -2, MARPA_ERR_INVALID_RULE_ID);
  marpa_m_test("marpa_g_rule_null_high", g, R_no_such, -1, MARPA_ERR_NO_SUCH_RULE_ID);

  marpa_g_trivial_precompute(g, S_top);
  ok(1, "precomputation succeeded");

  /* Ranks methods on precomputed grammar */
  marpa_m_test("marpa_g_rule_rank_set", g, R_top_1, negative_rank, -2, MARPA_ERR_PRECOMPUTED);
  marpa_m_test("marpa_g_rule_rank_set", g, R_top_1, negative_rank);

  marpa_m_test("marpa_g_rule_rank_set", g, R_top_2, positive_rank, -2, MARPA_ERR_PRECOMPUTED);
  marpa_m_test("marpa_g_rule_rank_set", g, R_top_2, positive_rank);

  marpa_m_test("marpa_g_rule_null_high_set", g, R_top_2, flag, -2, MARPA_ERR_PRECOMPUTED);
  marpa_m_test("marpa_g_rule_null_high", g, R_top_2, flag);

  /* recreate the grammar to test event methods except nulled */
  marpa_g_unref(g);
  g = marpa_g_trivial_new(&marpa_configuration);

  /* Events */
  /* test that attempts to create events, other than nulled events,
     results in a reasonable error -- http://irclog.perlgeek.de/marpa/2015-02-13#i_10111838 */

  /* completion */
  S_completed = S_B1;

  value = 0;
  marpa_m_test("marpa_g_symbol_is_completion_event_set", g, S_completed, value, value);
  marpa_m_test("marpa_g_symbol_is_completion_event", g, S_completed, value);

  value = 1;
  marpa_m_test("marpa_g_symbol_is_completion_event_set", g, S_completed, value, value);
  marpa_m_test("marpa_g_symbol_is_completion_event", g, S_completed, value);

  reactivate = 1;
  marpa_m_test("marpa_g_completion_symbol_activate", g, S_completed, reactivate, reactivate);

  reactivate = 0;
  marpa_m_test("marpa_g_completion_symbol_activate", g, S_completed, reactivate, reactivate);

  /* prediction */
  S_predicted = S_A1;

  value = 0;
  marpa_m_test("marpa_g_symbol_is_prediction_event_set", g, S_predicted, value, value);
  marpa_m_test("marpa_g_symbol_is_prediction_event", g, S_predicted, value);

  value = 1;
  marpa_m_test("marpa_g_symbol_is_prediction_event_set", g, S_predicted, value, value);
  marpa_m_test("marpa_g_symbol_is_prediction_event", g, S_predicted, value);

  reactivate = 1;
  marpa_m_test("marpa_g_prediction_symbol_activate", g, S_predicted, reactivate, reactivate);

  reactivate = 0;
  marpa_m_test("marpa_g_prediction_symbol_activate", g, S_predicted, reactivate, reactivate);

  /* completion on predicted symbol */
  value = 1;
  marpa_m_test("marpa_g_symbol_is_completion_event_set", g, S_predicted, value, value);
  marpa_m_test("marpa_g_symbol_is_completion_event", g, S_predicted, value);

  /* predicton on completed symbol */
  value = 1;
  marpa_m_test("marpa_g_symbol_is_prediction_event_set", g, S_completed, value, value);
  marpa_m_test("marpa_g_symbol_is_prediction_event", g, S_completed, value);

  /* invalid/no such symbol IDs */
  const char *marpa_g_event_setters[] = {
    "marpa_g_symbol_is_completion_event_set", "marpa_g_completion_symbol_activate",
    "marpa_g_symbol_is_prediction_event_set","marpa_g_prediction_symbol_activate",
  };
  for (ix = 0; ix < sizeof(marpa_g_event_setters) / sizeof(char *); ix++)
  {
    marpa_m_test(marpa_g_event_setters[ix], g, S_invalid, whatever, -2, MARPA_ERR_INVALID_SYMBOL_ID);
    marpa_m_test(marpa_g_event_setters[ix], g, S_no_such, whatever, -1, MARPA_ERR_NO_SUCH_SYMBOL_ID);
  }
  marpa_m_test("marpa_g_symbol_is_prediction_event", g, S_invalid, -2, MARPA_ERR_INVALID_SYMBOL_ID);
  marpa_m_test("marpa_g_symbol_is_prediction_event", g, S_no_such, -1, MARPA_ERR_NO_SUCH_SYMBOL_ID);

  marpa_m_test("marpa_g_symbol_is_completion_event", g, S_invalid, -2, MARPA_ERR_INVALID_SYMBOL_ID);
  marpa_m_test("marpa_g_symbol_is_completion_event", g, S_no_such, -1, MARPA_ERR_NO_SUCH_SYMBOL_ID);

  /* precomputation */
  marpa_g_trivial_precompute(g, S_top);
  ok(1, "precomputation succeeded");

  /* event methods after precomputation */
  for (ix = 0; ix < sizeof(marpa_g_event_setters) / sizeof(char *); ix++)
  {
    marpa_m_test(marpa_g_event_setters[ix], g, whatever, whatever, -2, MARPA_ERR_PRECOMPUTED);
  }
  marpa_m_test("marpa_g_symbol_is_prediction_event", g, S_predicted, value);
  marpa_m_test("marpa_g_symbol_is_completion_event", g, S_completed, value);

  /* Recognizer Methods */
  r = marpa_r_new (g);
  if (!r)
    fail("marpa_r_new", g);

  rc = marpa_r_start_input (r);
  if (!rc)
    fail("marpa_r_start_input", g);

  marpa_m_grammar_set(g);
  diag ("at earleme 0");
  marpa_m_test("marpa_r_is_exhausted", r, 1);

  return 0;
}
