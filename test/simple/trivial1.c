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
fail (const char *s, Marpa_Grammar g)
{
  const char *error_string;
  Marpa_Error_Code errcode = marpa_g_error (g, &error_string);
  printf ("%s returned %d: %s", s, errcode, error_string);
  exit (1);
}

Marpa_Symbol_ID S_top;
Marpa_Symbol_ID S_A1;
Marpa_Symbol_ID S_A2;
Marpa_Symbol_ID S_B1;
Marpa_Symbol_ID S_B2;
Marpa_Symbol_ID S_C1;
Marpa_Symbol_ID S_C2;

/* For fatal error messages */
char error_buffer[80];

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
  sprintf (error_buffer, "no such symbol: %d", id);
  return error_buffer;
};

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
};


int
main (int argc, char *argv[])
{
  int rc;
  const char *error_string;

  Marpa_Config marpa_configuration;

  Marpa_Grammar g;
  Marpa_Recognizer r;
  /* Longest rule is <= 4 symbols */
  Marpa_Symbol_ID rhs[4];

  Marpa_Rule_ID R_top_1;
  Marpa_Rule_ID R_top_2;
  Marpa_Rule_ID R_C2_3; // highest rule id

  plan(30);

  marpa_c_init (&marpa_configuration);
  g = marpa_g_new (&marpa_configuration);
  if (!g)
    {
      Marpa_Error_Code errcode =
      marpa_c_error (&marpa_configuration, &error_string);
      printf ("marpa_g_new returned %d: %s", errcode, error_string);
      exit (1);
    }

  ((S_top = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((marpa_g_symbol_is_nulled_event_set(g, S_top, 1)) >= 0)
    || fail ("marpa_g_symbol_is_nulled_event_set", g);
  ((S_A1 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((marpa_g_symbol_is_nulled_event_set(g, S_A1, 1)) >= 0)
    || fail ("marpa_g_symbol_is_nulled_event_set", g);
  ((S_A2 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((marpa_g_symbol_is_nulled_event_set(g, S_A2, 1)) >= 0)
    || fail ("marpa_g_symbol_is_nulled_event_set", g);
  ((S_B1 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((marpa_g_symbol_is_nulled_event_set(g, S_B1, 1)) >= 0)
    || fail ("marpa_g_symbol_is_nulled_event_set", g);
  ((S_B2 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((marpa_g_symbol_is_nulled_event_set(g, S_B2, 1)) >= 0)
    || fail ("marpa_g_symbol_is_nulled_event_set", g);
  ((S_C1 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((marpa_g_symbol_is_nulled_event_set(g, S_C1, 1)) >= 0)
    || fail ("marpa_g_symbol_is_nulled_event_set", g);
  ((S_C2 = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((marpa_g_symbol_is_nulled_event_set(g, S_C2, 1)) >= 0)
    || fail ("marpa_g_symbol_is_nulled_event_set", g);

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

  (marpa_g_start_symbol_set (g, S_top) >= 0)
    || fail ("marpa_g_start_symbol_set", g);

  /* these don't have @<Fail if not precomputed@>@, but just in case */
  is_int(S_top, marpa_g_start_symbol (g), "marpa_g_start_symbol()");
  is_int(S_C2, marpa_g_highest_symbol_id (g), "marpa_g_highest_symbol_id()"); 

  if (marpa_g_precompute (g) < 0)
    {
      marpa_g_error (g, &error_string);
      puts (error_string);
      exit (1);
    }
  ok(1, "precomputation succeeded");

  /* grammar methods, per sections of api.texi's Grammar Methods */

  /* Symbols -- these do have @<Fail if not precomputed@>@ */
  is_int(1, marpa_g_symbol_is_accessible  (g, S_C2), "marpa_g_symbol_is_accessible()");
  is_int(1, marpa_g_symbol_is_nullable (g, S_A1), "marpa_g_symbol_is_nullable()");
  is_int(1, marpa_g_symbol_is_nulling (g, S_A1), "marpa_g_symbol_is_nulling()");
  is_int(1, marpa_g_symbol_is_productive (g, S_top), "marpa_g_symbol_is_productive()");
  is_int(1, marpa_g_symbol_is_start (g, S_top), "marpa_g_symbol_is_start()");
  is_int(0, marpa_g_symbol_is_terminal(g, S_top), "marpa_g_symbol_is_terminal()");
  
  /* Rules */
  is_int(R_C2_3, marpa_g_highest_rule_id (g), "marpa_g_highest_rule_id()");
  is_int(1, marpa_g_rule_is_accessible (g, R_top_1), "marpa_g_rule_is_accessible()");
  is_int(1, marpa_g_rule_is_nullable (g, R_top_2), "marpa_g_rule_is_nullable()");
  is_int(1, marpa_g_rule_is_nulling (g, R_top_2), "marpa_g_rule_is_nulling()");
  is_int(0, marpa_g_rule_is_loop (g, R_C2_3), "marpa_g_rule_is_loop()");
  is_int(1, marpa_g_rule_is_productive (g, R_C2_3), "marpa_g_rule_is_productive()");
  is_int(1, marpa_g_rule_length (g, R_top_1), "marpa_g_rule_length(), rule R_top_1");
  is_int(0, marpa_g_rule_length (g, R_C2_3), "marpa_g_rule_length(), rule R_C2_3");
  is_int(S_top, marpa_g_rule_lhs (g, R_top_1), "marpa_g_rule_lhs (), rule R_top_1");
  is_int(S_A1, marpa_g_rule_rhs (g, R_top_1, 0), "marpa_g_rule_rhs (), rule R_top_1");
  is_int(S_A2, marpa_g_rule_rhs (g, R_top_2, 0), "marpa_g_rule_rhs (), rule R_top_2");

  /* recognizer methods */
  r = marpa_r_new (g);
  if (!r)
    {
      marpa_g_error (g, &error_string);
      puts (error_string);
      exit (1);
    }
  rc = marpa_r_start_input (r);
  if (!rc)
    {
      marpa_g_error (g, &error_string);
      puts (error_string);
      exit (1);
    }
  ok((marpa_r_is_exhausted(r)), "exhausted at earleme 0");
  
  return 0;
}
