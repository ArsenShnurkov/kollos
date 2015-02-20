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

#include "marpa_test.h"

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

int
main (int argc, char *argv[])
{
  int rc;
  int ix;

  Marpa_Config marpa_configuration;

  Marpa_Grammar g;
  Marpa_Recognizer r;

  Marpa_Rank negative_rank, positive_rank;
  int flag;

  int whatever;

  plan_lazy();

  marpa_c_init (&marpa_configuration);
  g = marpa_g_trivial_new(&marpa_configuration);

  marpa_m_grammar_set(g); /* for marpa_g_error() in marpa_m_test() */

  /* Grammar Methods per sections of api.texi: Symbols, Rules, Sequnces, Ranks, Events */

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
  {
    int reactivate;
    int value;
    Marpa_Symbol_ID S_predicted, S_completed;

    /* completion */
    S_completed = S_B1;

    value = 0;
    marpa_m_test("marpa_g_symbol_is_completion_event_set", g, S_completed, value, value);
    marpa_m_test("marpa_g_symbol_is_completion_event", g, S_completed, value);

    value = 1;
    marpa_m_test("marpa_g_symbol_is_completion_event_set", g, S_completed, value, value);
    marpa_m_test("marpa_g_symbol_is_completion_event", g, S_completed, value);

    reactivate = 0;
    marpa_m_test("marpa_g_completion_symbol_activate", g, S_completed, reactivate, reactivate);

    reactivate = 1;
    marpa_m_test("marpa_g_completion_symbol_activate", g, S_completed, reactivate, reactivate);

    /* prediction */
    S_predicted = S_A1;

    value = 0;
    marpa_m_test("marpa_g_symbol_is_prediction_event_set", g, S_predicted, value, value);
    marpa_m_test("marpa_g_symbol_is_prediction_event", g, S_predicted, value);

    value = 1;
    marpa_m_test("marpa_g_symbol_is_prediction_event_set", g, S_predicted, value, value);
    marpa_m_test("marpa_g_symbol_is_prediction_event", g, S_predicted, value);

    reactivate = 0;
    marpa_m_test("marpa_g_prediction_symbol_activate", g, S_predicted, reactivate, reactivate);

    reactivate = 1;
    marpa_m_test("marpa_g_prediction_symbol_activate", g, S_predicted, reactivate, reactivate);

    /* completion on predicted symbol */
    value = 1;
    marpa_m_test("marpa_g_symbol_is_completion_event_set", g, S_predicted, value, value);
    marpa_m_test("marpa_g_symbol_is_completion_event", g, S_predicted, value);

    /* prediction on completed symbol */
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
      marpa_m_test(marpa_g_event_setters[ix], g, whatever, whatever, -2, MARPA_ERR_PRECOMPUTED);
    marpa_m_test("marpa_g_symbol_is_prediction_event", g, S_predicted, value);
    marpa_m_test("marpa_g_symbol_is_completion_event", g, S_completed, value);
  }

  /* Recognizer Methods */
  {
    r = marpa_r_new (g);
    if (!r)
      fail("marpa_r_new", g);

    rc = marpa_r_start_input (r);
    if (!rc)
      fail("marpa_r_start_input", g);

    diag ("The below recce tests are at earleme 0");

    { /* event loop -- just count events so far -- there must be no event except exhausted */
      Marpa_Event event;
      int exhausted_event_triggered = 0;
      int spurious_events = 0;
      int prediction_events = 0;
      int completion_events = 0;
      int event_ix;
      const int event_count = marpa_g_event_count (g);

      is_int(1, event_count, "event count at earleme 0 is %ld", (long) event_count);

      for (event_ix = 0; event_ix < event_count; event_ix++)
      {
        int event_type = marpa_g_event (g, &event, event_ix);
        if (event_type == MARPA_EVENT_SYMBOL_COMPLETED)
          completion_events++;
        else if (event_type == MARPA_EVENT_SYMBOL_PREDICTED)
          prediction_events++;
        else if (event_type == MARPA_EVENT_EXHAUSTED)
          exhausted_event_triggered++;
        else
        {
          printf ("spurious event type is %ld\n", (long) event_type);
          spurious_events++;
        }
      }

      is_int(0, spurious_events, "spurious events triggered: %ld", (long) spurious_events);
      is_int(0, completion_events, "completion events triggered: %ld", (long) completion_events);
      is_int(0, prediction_events, "completion events triggered: %ld", (long) prediction_events);
      ok (exhausted_event_triggered, "exhausted event triggered");

    } /* event loop */

    Marpa_Symbol_ID S_expected = S_A2;
    int value = 1;
    marpa_m_test("marpa_r_expected_symbol_event_set", r, S_expected, value, value);

    /* recognizer reading methods */
    Marpa_Symbol_ID S_token = S_A2;
    marpa_m_test("marpa_r_alternative", r, S_invalid, 0, 0,
      MARPA_ERR_RECCE_NOT_ACCEPTING_INPUT, "not accepting input is checked before invalid symbol");
    marpa_m_test("marpa_r_alternative", r, S_no_such, 0, 0,
      MARPA_ERR_RECCE_NOT_ACCEPTING_INPUT, "not accepting input is checked before no such symbol");
    marpa_m_test("marpa_r_alternative", r, S_token, 0, 0,
      MARPA_ERR_RECCE_NOT_ACCEPTING_INPUT, "not accepting input");
    marpa_m_test("marpa_r_earleme_complete", r, -2, MARPA_ERR_RECCE_NOT_ACCEPTING_INPUT);

    marpa_m_test("marpa_r_is_exhausted", r, 1, "at earleme 0");

    /* Location accessors */
    {
      /* the below 2 always succeed */
      unsigned int current_earleme = 0;
      marpa_m_test("marpa_r_current_earleme", r, current_earleme);

      unsigned int furthest_earleme = current_earleme;
      marpa_m_test("marpa_r_furthest_earleme", r, furthest_earleme);

      marpa_m_test("marpa_r_latest_earley_set", r, furthest_earleme);

//      marpa_m_test("marpa_r_earleme", r, current_earleme, -2, MARPA_ERR_NO_EARLEY_SET_AT_LOCATION);

    }

    marpa_r_earleme(r, 0);
    diag("about to call marpa_r_earley_set_value(r, 0) after marpa_r_earleme(r, 0)");
    marpa_r_earley_set_value (r, 0);

  } /* recce method tests */

  return 0;
}
