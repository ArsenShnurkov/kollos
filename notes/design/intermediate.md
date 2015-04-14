# Kollos: the intermediate representation

## Overview

Kollos's interface language will be the LUIF, essentially
Lua 5.1 extended with BNF.
A top layer, called the Kollos high layer, or KHIL,
will parse this into the "Kollos intermediate representation",
or KIR,
which is pure Lua 5.1 with some calls to the kollos Lua package.

Since the KIR is pure Lua 5.1, it can be run with Lua.
Calls in the kollos package, which I expect I will write,
will then do lower level transformations to make the grammar
ready for Libmarpa.
These lower level transformations are called the Kollos lower
layer, or KLOL.

This document describes

* the "kollos" Lua package calls in the KIR.

* the KHIL "callbacks", which allow the KLOL to get information
  from the KHIL for error messages, tracing, debugging, etc.

## The Kollos higher layer

The basic transformation needed to obtain the KIR from the LUIF is
translation of the LUIF rules, which may include precedented and
sequence rules, into a form which allows only BNF rules.
I will describe the transformations necessary to translate from
precedented rules to BNF rules,
and from sequence rules to BNF rules,
in separate documents.

## Symbols, alternatives, and rules

The KHIL will find *external* rules, alternatives and symbols
in the LUIF,
which it will turn into *internal* rules and symbols.
The external rules are the sequence, precedented and
BNF rules in the LUIF, one per statement.

An *alternative* is a part of a rule consisting of
a single LHS and a single RHS.
An ordinary BNF rule contains a single alternative.
A sequence rule also contains only one alternative.
Precedenced rules, however, may contain many alternatives.
In the SLIF, the alternatives of precedenced
statements are separated by the bar (`|`)
and double bar (`||`) symbols.

Internal symbols are either *brick* symbols or mortar
symbols.
Every brick symbol has a corresponding external symbol.
A mortar symbol does not have
a corresponding external symbol.

As of this writing, I am undecided whether rules, alternatives
and symbols should represented as integers or strings.
If strings, the representation for external symbols should
clearly be their lexical equivalent in the LUIF,
but the format of the others is also undecided.

The motivation of the above will, I hope,
be clearer when I outline the
transformations the KHIL must perform.

## KIR calls

The KIR will be Lua 5.1, and will assume that there is a "kollos.kir"
package with the calls listed in this section.
The examples assume that the Lua statement
```
    local kir = kollos.kir
```
has already been executed.

### Grammar constructor

```
     g = kir.grammar(start)
```
Here `start` is an internal symbol, which is
declared to be the start symbol of the grammar.
The grammar `g` is returned.
It is an opaque object, only to be used in other KIR
calls.

### Symbol declarators
```
    kir.terminal(sym1)
    kir.medial(sym2)
```
Internal symbols need to be declared before they
are used in a KIR rule.
These two calls declare `sym1` to be a terminal
symbol and `sym2` to be a medial symbol
(that is, not the start symbol and not a terminal).

### Rule declarators

```
    kir.rule(g, id, xid, lhs, rhs1, rhs2)
    kir.xalternative(g, xid, id, action, options)
```
The first of the statements above
(`kir.rule()`)
declares a rule for grammar `g`.
The ID of the internal rule is `id`.
The ID of the external alternative is `xid`.
Its LHS is `lhs`.
Its RHS symbols are `rhs1` and `rhs2`.
The number of RHS symbols may vary from 0 on up.

The first of the two statements above (`kir.alternative()`),
declares the external alternative ID, `xid`,
whose "top" internal rule is `id`.
`action` specified a LUA function which contains the
action for the alternative.
`options` is a Lua table specified the options.

It may turn out that actions need to be other things
besides Lua functions.
Often it is desirable to implement "built-in" actions,
for example.

As we will see when I describe the rewrites, alternatives
may be broken up into many internal rules.
Of the rules into which an alternative is broken up,
one and only one will be the "top" rule.
Only the top rule of an alternative will have a semantics
associated with it.

### Compile grammar
```
    kir.compile(g)
```
This compiles the grammar `g` into a form ready for
parsing.
This call may be unnecessary  --
it may be better to simply have the KLOL attach
a postamble to the KIR to implement the "compilation"
of the grammar.

## KHIL callbacks

For error messages, debugging, etc.,
the KIR will need to be able to access the original LUIF
text, given a rule, an alternative or a symbol.
These calls allow that.

*[ to be continued ]*

<!---
vim: expandtab shiftwidth=4
-->
