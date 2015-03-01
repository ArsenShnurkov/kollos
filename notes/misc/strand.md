# Strand parsing

This document describes Marpa's planned
"strand parsing" facility.
Strand parsing allows parsing to do done in pieces,
pieces which can then be "wound" together.
The technique bears a slight resemblance to
that for DNA unwinding, rewinding
and transcription,
and a lot of the terminology
for strand parsing
is borrowed
from biochemistry.

## Theory: suffix grammars

In what follows, some sections will,
like this one,
be marked "Theory".
It is safe to skip them.
They record mathematical details,
some of which are important
for ensuring the correctness of the algorithm.

The "transcription grammar" here is based on
the "suffix grammar", whose construction is described in
Grune & Jacobs, 2nd ed., section 12.1, p. 401.
Our purpose differs from theirs, in that

* we want our parse to contain only those suffixes which
    match a known prefix; and

* we want to be able to create parse forests from both suffix
    and prefix, and to combine these parse forests.

Every context-free grammar has a context-free "suffix grammar" --
a grammar, whose language is the set of suffixes of the first language.
That is, let `g1` be the grammar for language `L1`, where `g1` is a context-free
grammar.
(In parsing theory, "language" is an fancy term for a set of strings.)
Let `suffixes(L1)` be the set of strings, all of which are suffixes of `L1`.
`L1` will always be a subset of `suffixes(L1)`.
It can be shown that there is always some context-free grammar `g2`,
whose language is `suffixes(L1)`.

## Nucleobases, nucleosides and nucleotides

In order to make the following algorithm appeal to the intuition more,
we use an analogy to DNA transcription and winding.
For this purpose, we borrow some of the specialist terminology
of biochemistry.

A DNA molecule consists of two "strands", which are joined
by "nucleobase pairs".
In DNA, there are four nucleobases: the familiar
cytosine (C), guanine (G), adenine (A) and thymine (T).
In our strand grammars, we will usually need many more
nucleobases.

In DNA, each nucleobase molecule is attached to a sugar to
form a nucleoside.
Biochemists occasionally call this sugar a nucleosugar.
In DNA,
each nucleoside
is attached to 
one or more phosphate groups
to form
a nucleotide.
(Some biochemical texts insist there can be only one
phosphate group in a nucleotide.
For our purposes, the difference is not relevant,
and we will let the chemists argue this out among themselves.)

For our purposes,
a *nucleobase* is a lexeme
at which two "strands" touch directly.
There are left and right nucleobases,
which occur on the left edge and right
edge of strands, respectively.

The RHS of a rule contains at most one nucleobase.
If it is a right nucleobase, it will always be
the first symbol of the RHS.
If it is a left nucleobase, it will always be
the last symbol of the RHS.

In a RHS containing a nucleobase,
a symbol is "inside" another if it is in the direction heading away from
the edge.
If the nucleobase on the RHS of a rule is a left nucleobase,
one symbol is inside another one if it to its left.
If the nucleobase on the RHS of a rule is a right nucleobase,
one symbol is inside another one if it to its right.

If symbol `<A>` is inside symbol `<B>`,
then symbol `<B>` is outside of symbol `<A>`.
If a RHS does not contain a nucleobase,
"inside" and "outside" are not defined.

A *nucleosugar* is a non-terminal used in
winding and unwinding strands.
Nucleosugars always occur in a RHS next to,
and inside of, a nucleobase.

A *nucleoside*, for our purposes, is a nucleobase
with its adjacent nucleosugar, if there is one.
Note that while DNA nucleosides *always* contain
nucleosugars, in our terminology,
nucleosugars are optional.

Finally, a *nucleotide* is a rule that contains
nucleobases.

As a mnemonic, note that
the order from inside to outside,
and the order from smallest to largest,
is the same as the alphabetical order of the terms:
"base", "side" and "tide".

## Dotted rules

As a reminder,
dotted rules are of three kinds:

* predictions, in which the dot is before the first RHS symbol;

* completions, in which the dot is after the last RHS symbol; and

* medials, which are those dotted rules which are neither
    predictions or completions.

If a dotted rule has the dot after a RHS symbol instance,
the predecessor of that dotted rule is the dotted rule
with the dot before that symbol instance --
in
other words, with the dot one position earlier.
If a dotted rule has the dot before a RHS symbol instance,
the predecessor of that dotted rule is the dotted rule
with the dot after that symbol instance --
other words, with the dot one position later.
Predictions do not have predecessors
and completions do not have successors.

## Creating the strand grammar

Let our original grammar be `g1`.
We also call `g1` the pre-strand grammar.
We will need to extend `g1` to a
"strand grammar".

We need to define, for every rule in `g1`, two 'nucleotide rules',
a 'left nucleotide' and a 'right nucleotide'.

First, we define our set of "nucleobase symbols".
The purpose of nucleobase symbols is similar to the purpose
of nucleobases in DNA -- they occur where two strand "touch"
and they occur in pairs.
The matching of nucleobase pairs indicates where two strands
should "touch" in order to preserve their information.

Nuclebase symbols
have the form `b42R`,
and `b42L`;
where the initial `b` means "base".
`R` and `L` indicate, respectively,
the right and left member of the base pair.
`42` is an arbitrary number,
chosen to make sure that every base pair is unique.
A nucleobase symbol can occur only once.
They must occur on the outside of a RHS.
(Pedantically, their location defines "inside" and "outside".)

Every pair of nucleotide rules must have a unique pair of nucleobase
symbols.

Nucleosugar symbols exist to allow non-terminals to be split in half.
Like nucleobase symbols, nucleosugars come in right and left versions.
For example, for the symbol `A`,
the nucleosugars will be `A-L` and `A-R`.

We will call the original grammar,
before it has strand rules and symbols added to it,
the "pre-strand grammar".
The rules of a pre-strand grammar are pre-strand rules
and the symbols of a pre-strand grammar are pre-strand symbols.

To split rules in half, we use nucleotide rules.
Let one of `g1`'s pre-strand rules be
```
     X ::= A B C
```
Call this rule `rule-X`.

The six pairs of 
"nucleotide rules" that we will need for `rule-X` are
```
    1: X-L ::= b1L            X-R ::= b1R A B C
    2: X-L ::= A-L b2L        X-R ::= b2R A-R B C
    3: X-L ::= A b3L          X-R ::= b3R B C
    4: X-L ::= A B-L b4L      X-R ::= b4R B-R C
    5: X-L ::= A B b5L        X-R ::= b5R C
    6: X-L ::= A B C-L b6L    X-R ::= b6R C-R
```
The pairs are numbered 1 to 6, the same number which
is used in the example to uniquely identify the nucleobase
symbols.
`rule-X` is called the "base rule" of these nucleotides.

Pairs 1, 3 and 5 are
"inter-nucleotides" --
nucleotides that split their base rule
at a point between two symbols.
Pairs 2, 4 and 6 are
"intra-nucleotides" --
nucleotides that split their base rule
at a point within a single symbol.

Every nucleotide has a "base dotted rule".
(As a reminder,
a "dotted rule"
is a BNF rule with one of its positions marked with a dot.)

The rule of a nucleotide's "base dotted rule" is the nucleotide's base rule.
The base dotted rule for nucleotide pairs 1 and 2 is
```
    X ::= . A B C
```
The base dotted rule for nucleotide pairs 3 and 4 is
```
    X ::= A . B C
```
The base dotted rule for nucleotide pairs 5 and 6 is
```
    X ::= A B . C
```

A completion is 
a dotted rule with the dot
after the last RHS symbol.
In this example, it is
```
    X ::= A B C .
```
A completion is never the base dotted rule
of a nucleotide.

We can ignore completions,
but we do need to deal with predictions,
The inter-nucleotide pair whose base dotted rule has its dot
before the first non-nulled RHS symbol is called the "prediction nucleotide pair".
In this example, the prediction nucleotides are pair 1.

Each pre-strand rule potentially needs `2*n` pairs of nucleotide rules,
where `n` is the number of symbols on the RHS of the
`g1` rule.
Empty rules can be ignored.
We can also ignore any splits that occur before nulling symbols.

The above rules imply that left split rules can be nulling.
In fact,
for every pre-strand rule,
one of the left split rules derived from it must be nulling.
But no right split rule can be nulling.
Informally, a right split rule must represent "something".

## Active strands

An active strand is one capable of being wound together with
another active strand.
An active strand must be left-active or right-active.
A strand can be *both* left- and right-active,
in which case we call it double-active.
An active strand which is not double-active
is called single-active.
An inactive strand is the same as an ordinary
parse forest.

A strand is right-active if it has nucleobases at its right edge.
A strand is left-active if it has nucleobases at its left edge.

If a strand is right-active, we call it a left strand.
If a strand is left-active, we call it a right strand.
This may seem confused, but the idea is that a left strand is
wound together with a right one and
for that to occur,
the left strand must have an active edge on its right and
the right strand must have an active edge on its left.

## Broken nucleotides

Sometimes we want to represent a partial parse
as a parse forest,
at a point where the parse is exhausted,
and where there is no convenient "top rule".
This will be the case in many parse failures.

To do this, we can use "broken nucleotides".
A broken nucletide is a nucleotide without the
nucleobase.
In this form, the nucleotide represents a partial
rule but, unlike in the full nucleotide,
the broken rule cannot be combined with another
nucleotide.

## Archtypal strand parsing

Before getting into details of the algorithms for forming
and winding strands,
it may be helpful to indicate how they are intended to
be used.
There are many ways in which strand parsing can be used,
but 
the archetypal case is that where we
are parsing from left-to-right,
breaking the parse up at arbitrary "split points",
and winding pairs of strands together as
we proceed.

In more detail:

* We start by parsing the input until
    we have an initial single-active left strand,
    or the parse has succeeded,
    or the parse has failed.
    If the parse succeeded or failed,
    we have an inactive strand,
    and we proceed as described in the section titled
    "Producing the ASF".

* We then loop for as long as we can create double-active strands,
    by parsing the remaining input.

    * We parse the remaining input to create a new strand.

    * If this new strand is not double-active, we end the loop.

    * At this point,
        we have a single-active left strand and a double-active strand.

    * We wind our two strands together,
         leaving a single-active left strand,
         and continue the loop.

* On leaving the loop, we have two single-active strands, one
    left, one right.
    We wind these two together to produce an inactive strand.
    Call this the "final strand".
    We proceed as described in the section titled
    "Producing the ASF".

## The structure of an ASF

Marpa::R2 has two ASF formats.
The one
[externally documented](https://metacpan.org/pod/distribution/Marpa-R2/pod/ASF.pod)
as its ASF interface
is for advanced uses,
and is an upper layer to the undocumented
"bocage" interface.
The bocage interface (which is essentially
the same as Elizabeth Scott's SPFF format)
is the one which will be described here.
An Marpa::R2 ASF can be built from the bocage,
when and if desired.

A bocage consists of nodes.
All nodes are either terminal nodes
or non-terminal nodes.
A terminal node is a 4-tuple of

* A symbol ID, which is one of the symbols
 of the grammar.

* A node value, which may be anything
 meaningful to the application,
 or which may be undefined.

* A start position, which is a G1 location.

* An end position, which is a G1 location
 at or after the start position.

The start position and end position may be
the same, in which case the terminal node
is a nulling node.
The length of the node is the difference
between end position and start position,
which must be a non-negative integer.
A node is nulling if and only if the length is zero.
In normal applications,
the length
of non-nulling terminal nodes
will be one.

A non-terminal node is a 3-tuple of

* Dotted rule.
 As a reminder, a dotted rule is
 a rule of the grammar with one of its
 positions distinguished as the "dot position".

* Origin, that is, the G1 location at which
 the dotted rule starts.

* Dot location, which
 is the G1 location of
 the dotted rule's dot position.

It is convenient to use the same terminology for G1 locations
in both terminal and non-terminal nodes, so that the
start and end position of a terminal node are often
called,respectively, its origin and dot location.

A non-terminal nodes is called a prediction,
a medial and or a completion,
based on their dotted rules.
A prediction node whose dotted rule
is a nucleotide,
will only occur on the active edge of
a strand,
and is called an
active prediction node.
All other prediction nodes
are called inactive prediction nodes.
The information in
inactive prediction nodes
can usually be deduced from the other nodes,
so that inactive prediction nodes are not physically represented
in the bocage.

Every non-terminal node has zero or more "source links",
which describe why the node exists.
If the node is a prediction,
its source is not tracked,
and it will have zero links.
Otherwise, a non-terminal node has one or more links.

Every link is a duple,
consisting of
a predecessor and
a successor.
The predecessor and successor
are called children of the node that their
link belongs to.
If node A is a child of node B,
then node B is a parent of node A.

Conceptually, the links indicate how the node
was formed,
with the predecessor describing a
dotted rule with its dot one symbol
earlier in the rule,
and the successor describing the source
of the symbol which allowed the dot
to be moved forward.

The successor may be either a terminal node
or a non-terminal node.
If the successor is a non-terminal node,
that node must be a completion.

The predecessor is always
a non-terminal node,
and is never a completion.
It may be a prediction,
in which case the node the link points
to will not be physically represented in
the bocage unless it is an active prediction node.

In creating or extending a bocage,
no node is ever added twice.
If a node has more than one source,
the node with, if appropriate, a link
is added by the first source.
Subsequent sources add links,
when appropriate,
to original node.
Also, no link is ever added twice.

### Expanding a partial bocage

In what follows,
we will refer to "expanding the pre-strand symbols"
of an initial set of nodes in a bocage,
relative to a series of Earley sets.
We first create a working set of bocage nodes,
starting with the initial set.
We then do the following
until the working set is empty.

* We remove a node from the 
  working set.
  We call this the working node.
  If it is a terminal node,
  we do nothing further with it.
  Otherwise we continue with the following
  steps.

*  If pre-dot symbol of the working
  node's dotted rule is
 not a pre-strand symbol,
 we do nothing further with the working node.
 Otherwise we continue with the following
 steps.

* We produce a list of duples from the
  Earley sets and the input, where each duples
  is such that

    - the first element is an Earley item
      whose origin
      is the same as the origin of the node.

    - the 2nd element is an input token
      whose end location is the same
      is as the
      dot location of the node;
      or the 2nd element is an Earley item whose
      dot location is the same as
      the dot location of the node.

    - if the 2nd element of the duple is an
      input token, the token symbol is
      the same as the pre-dot symbol
      of the working node;

    - if the 2nd element of the duple is an
      Earley item, it is a completion
      and the dotted rule's LHS symbol is
      the same as the pre-dot symbol
      of the working node;

    - the dot location of the 1st element
      is the same as the
      origin of the 2nd element.

* For each of the duples,
   we add a link to the working node
   such that

   - the predecessor of the link
   is a new node which
   takes its dotted rule, origin,
   and dot location from the 1st element
   of the pair;

   - if the 2nd element is an input token,
   the successor is a terminal node
   which takes its start and end
   locations from the start and end
   location of the input token,
   and its symbol and value
   from the token symbol and value;
   and

   - if the 2nd element is an Earley item,
   the successor is a new node which
   takes its dotted rule, origin,
   and dot location from the 2nd element
   of the pair;

* For each link added in the previous step,
  we add the predecessor node and,
  if the successor is a non-terminal node,
  the successor node,
  to the working set.

## Producing the ASF

To produce an ASF from an inactive strand,
we must determine if the parse succeeded
or failed.
If there is completed start rule covering the entire
input in the inactive strand,
the parse succeeded.
Otherwise, the parse is a failure.

On success,
the final strand is our completed parse forest.
If the parse is a failure, we can produce a parse
forest to help detect the error.
To represent the rules in progress at the point of
failure, we can use broken left nucleotides.

## Creating a left-active strand

To create a left-active strand, we start with

* an Earley parse; and

* a location in that parse, called the "split point"; and

* a set of medial dotted rules at the split point.

From the Earley parse, we know

* the dotted rules that apply at the current location; and

* how they link to child rules and symbols.

At the Libmarpa level both these things are known.
As of this writing, only the dotted rules
are supported at the SLIF level -- the calls that make
their links available are currently not documented.


[ Most recent draft done up to here. ]

but it will not be a left-active strand -- it will be
the final parse forest
and there will be no way of
joining it up with a parse forest to its right.

There may be no medial dotted rules.
In this case the parse is exhausted -- it can go no further.
We do not continue with the following steps.

### Medial dotted rules at the split point

At the split point, we look at each of the medial
dotted rules.
For each of these dotted rules:

* Call the LHS of its dotted rule, `medial-LHS`.
   Call its parent dotted rule, `parent-dr`.

* Add the corresponding left inter-split rule
   as a node of the left strand.
   Call this new node, `new-node`,

Next, for every `new-node` in the list
of nodes just created:

* Let the medial dotted rule for `new-node` be
    `new-dr`.

* If `new-dr` is the cause of an effect,
    let that effect be `effect-dr`.

* If `effect-dr` does not already have
    a node in the left strand, create one.
    Call this node, `effect-node`.

* Make `effect-node` a parent of `new-node`
    in the left strand.

### Theory: Proofs about pre-split symbols

*To prove*: At the split point, all children of medial rules in
the left strand are pre-split symbols.

*Proof*:
Split-active symbols occur only as part of split rules.
All medial rules are taken from the Earley sets, which
only contain rules from the pre-split grammar.

(Left split rules are added to the left strand,
but they are always completions at the split point.
Right split rules are used in the suffix grammar,
but they are always joined to a left split rule
and eliminated when creating a left strand.)

Since all medial rules are from the pre-split grammar,
all of its children are symbols in the pre-split grammar.
*QED*.

*To prove*: No pre-split symbol derives a post-split symbol

*Proof*:
The only rules with
post-split symbols on their LHS are the left and right split rules.
The only rules with
post-split symbols on their RHS are also left and right split rules.
So no rule with a pre-split symbol directly derives a
post-split symbol.
And therefore, by induction, no rule with a pre-split symbol,
no pre-split symbol derives a post-split symbol.
*QED*.

### Derive split point predictions.

We use a "prediction work list", of duples of the form:
`[symbol, parent]`.
To initialize it, for each medial rule from the above step,
we add `[postdot, medial-node]` to the prediction work list,
where `postdot` is the medial rule's postdot symbol,
and `medial-node` is the left strand node created from it.

Then, for every `[symbol, parent]` in the prediction work list:

* For every `rule` with `symbol` on its LHS:

    + We find the strand node for the left predicted split rule,
      createing it if it does not already exist.
      Call this node `new-node`.

    + Link `new-node` to `parent`.

    + Where `rule-postdot` is the postdot symbol of `rule`,
      add `[rule-postdot, new-node]` to the prediction work list.

### Intra-split nodes at the split point.

## Nucleobases

As the name suggests,
the nucleobase symbols will play a big role in connecting
our strands.
For this purpose, we will want to define a notion:
the *nucleobase of a dotted rule*.
Dotted rules, as a reminder, are rules with a
"current location" marked with a dot.
For example,
```
    X ::= A . B C
```
Call the symbols after the dot, the "suffix" of a dotted rule.
The nucleobase of a dotted rule is the nucleobase
in the nucleotide rule which is derived with the 
same original rule, and which has the same suffix.
For example, the nucleobase of the dotted rule above
are `b3L` and `b3R`.

## Some details

It's possible the same connector lexeme can appear more than once
on the right edge of the prefix subtree,
as well as on left edge of the connector subtree.
In these cases, the general solution is to make *all* possible connections.

<!---
vim: expandtab shiftwidth=4
-->
