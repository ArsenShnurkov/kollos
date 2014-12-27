# Marpa in constant space

This document describes how Marpa can parse a grammar
in constant space,
assuming that Marpa parses that grammar in linear time.
(The grammars Marpa parses in linear time include those in
all grammar classes currently in practical use.)

## What's the point?  Evaluation is linear or worse.

In practice, we never just parse a grammar -- we do so as a step
toward evaluting it, usually into something like a tree.
A tree takes linear space -- O(n) -- or worse -- O(n log n) --
depending on how we count.
Reducing the time from linear to constant in just the parser
does not affect the overall time complexity of the algorithm.
So what's the point?

In fact, in many cases, there may be little or not point.
Compilers incur major space requirements for optimization
and other purposes, and in their context optimizing the parser
for space may be pointless.

But there are applications that
convert huge files into reasonably
compact formats, and that do without using
a lot of space in their intermediate processing.
Applications that write
JSON and XML databases can be of this kind.
Pure JSON, in fact, is a small, lexing-driven language which really does
not require a parser as powerful as Marpa.
But bringing Marpa's performance as close as possible to that of custom-written
JSON parsers is a useful challenge.

In what follows,
we'll assume that a tree is being built, but we won't count its overhead.
That makes sense, because tree building will be the same for all parsers.

## The idea

The strategy will be to parse the input until we've used a fixed
amount of memory, then create a tree-slice from it.
Once we have the tree-slice, we can throw away the Marpa parse,
with all its memory, and start fresh on a 2nd tree-slice.

Next, we run the Marpa parser to produce a 2nd tree-slice.
When we have the 2nd tree-slice,
we connect it and the first tree-slice.
We can now throw away the 2nd Marpa parse.
We repeat this process until we've read the entire input
and assembled the whole tree.

If we track memory while creating slices,
we can quarantee that it never gets beyond some fixed size.
In practice, this size will be quite reasonable
and can be configurable.
It's optimum value will be a tradeoff between speed
and memory consumption.

## A bit of theory

Every context-free grammar has a context-free "suffix grammar" --
a grammar, whose language is the set of suffixes of the first language.
That is, let `g1` be the grammar for language `L1`, where `g1` is a context-free
grammar.
(In parsing theory, "language" is an fancy term for a set of strings.)
Let `suffixes(L1)` be the set of strings, all of which are suffixes of `L1`.
`L1` will be a subset of `suffixes(L1)`.
Then there is a context-free grammar `g2`, whose language is `suffixes(L1)`.

## Creating the split grammar

The "split grammar" here is based on
the "suffix grammar", whose construction is described in
Grune & Jacobs, 2nd ed.
Our purpose differs from theirs, in that

* we want our parse to contain only those suffixes which
    match a known prefix; and

* we want to be able to create trees from both suffix
    and prefix, and to combine these trees.

In order to accomplish our purposes, we need to define
a "split grammar".
Let our original grammar be `g1`.
Ignore, for the moment, the two issues of nullable symbols,
and of empty rules.
We need to define, for every rule in `g1`, two 'split rules',
a `left rule` and a `right rule`.

First, we'll need some new symbols.
For every non-terminal, we will want a left
and a right version.
For example, for the symbol `A`,
we want two new symbols, `A-L` and `A-R`.

We will also defined a new set of "connector symbols",
whose purpose will be to tell us how to reconnect
split rules.
Connector symbols will be defined in right-left pairs.
The pairs of connector symbols will have the form `c42R`,
and `c421L`;
where the initial `c` means "connector";
`R` and `L` indicate, respectively,
the right and left member of the pair;
and `42` represents some arbitrary number,
chosen to make sure that the pair is unique.
Every split rule must use a unique pair of connector
symbols.


Let a `g1` rule be
```
     X ::= A B C
```
The six pairs of 
"split rules" that we will need are
```
    X-L ::= c1L            X-R ::= c1R A B C
    X-L ::= A-L c2L        X-R ::= c2R A-R B C
    X-L ::= A c3L          X-R ::= c3R B C
    X-L ::= A B-L c4L      X-R ::= c4R B-R C
    X-L ::= A B c5L        X-R ::= c5R C
    X-L ::= A B C-L c6L    X-R ::= c6R C-R
```
It will be seen that these pairs represent splits
in the middle of each of the three symbols,
and before each of the three symbols.

Every `g1` rule will need `n` pairs of split rules,
where `n` is the number of symbols on the RHS of the
`g1` rule.
Empty rules can be ignored.

We need a pair of split rules to represent a "split" before the first
symbol of a `g1` rule, but we do not need a pair to represent a
split after the last symbol.
In other words, we need to deal with predictions,
but we can ignore completions.
We can also ignore any splits that occur before nulling symbols.

The above rules imply that left split rules can be nulling --
in fact one of the left split rules must be nulling.
But no right split rule can be nulling.
Informally, a right split rule must represent "something".

For a small grammar, it is not hard to write the above rules by hand.
For large grammars, there is nothing to prevent the rewrite from
being automated.

[ *Corrected to here* ]

[ *From here on out this discussion has problems.*
The basis idea is correct, I believe, but a lot of the details
that follow
are missing or wrong. ]

Our connector grammar, `g-conn`, consists of

* All the rules from `g1`, except for the start rule.

* All the connector suffix rules.

* All the connector start rules.
   
The start symbol for `g-conn` is the connector start symbol,
`Start-C`.

## Connector lexemes

As the name suggests,
the connector lexemes will play a big role in connecting
our parses.
For this purpose, we will want to define a notion:
the *connector lexeme of a dotted rule*.
Dotted rules, as a reminder, are rules with a
"current location" marked with a dot.
For example,
```
    X ::= A . B C
```
Call the symbols after the dot, the "suffix" of a dotted rule.
The connector lexeme of a dotted rule is the connector lexeme used
in the connector rule which is derived with the 
same original rule, and which has the same suffix.
For example, the connector lexeme for the dotted rule above
is `Lex-C2`.
The reader may be able to see how these could be used to connect
dotted rules from one parse with connector rules in another.

## The method

Now that we have a connector grammar, we can describe how the method
works.

* First, parse with the original grammar, `g1`, until we decide we've
    used enough space.

* At the last location, look at all the dotted rules.
    Ignore the completions -- those rules with the dot after the last
    symbol of the RHS.
    For the other, get the list of connector lexemes.

* Create a subtree from the parse so far.
    Call this the "prefix subtree".
    Use the connector lexemes to mark those places where more symbols are
    expected.
    We call the locations of the connector lexemes,
    the "right edge" of the prefix tree.

* Throw away the current Marpa parse, releasing its space.

* Start a new Marpa parse, using the connector grammar, 'g-conn`.
    At its first location, read all the connector lexemes from the
    previous grammar.  Marpa allows ambiguous lexemes, so this can be done.

* Resume parsing, with the new "connector" parser and the real input.

* When enough memory has been used, stop.
    Produce a new subtree from the connector parse.
    Call this the "connector subtree".
    The connector lexemes in the connector subtree
    mark its "left edge".
    Connect these with the "right edge"
    of the prefix subtree 
    to join the two subtrees together.

* Throw away the connector parse, releasing its space.

* If the entire input has been read,
    this newly joined subtree is the full tree for the parse.
    We are done.

* If there is more input to be read,
    use the newly joined subtree
    as the prefix subtree for the next phase.
    Mark its "right edge".

* Repeatedly do connector parses, and connect the subtrees
    at their edges,
    until we reach the end of the input.

## Some details

It would be quite possible, for example, to modify Marpa
so that it monitors memory and, if usage passes a limit,
switches to a connector grammar,
creating it on the fly.
If the subtrees are standard AST's it will be clear
how to connect them.

It's possible the same connector lexeme can appear more than once
on the right edge of the prefix subtree,
as well as on left edge of the connector subtree.
In these cases, the general solution is to make *all* possible connections.

<!---
vim: expandtab shiftwidth=4
-->
