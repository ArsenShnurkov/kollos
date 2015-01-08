# Strand parsing

This document describes how Marpa's planned
"strand parsing" facility.
It allows parsing to do done in pieces,
which can be "wound" together.
The technique bears a slight resemblance to
that for DNA unwinding, rewinding
and transcription,
and a lot of the terminology is borrowed
from biochemistry.

## Theory: suffix grammars

In what follows, some sections will,
like this one,
be marked "Theory".
It is safe for to skip them.
They record technical details which are important
in ensuring the correctness of the algorithm.

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
`L1` will be a subset of `suffixes(L1)`.
Then there is a context-free grammar `g2`, whose language is `suffixes(L1)`.

## Nucleobases, nucleosides and nucleotides

The mechanism used for spliting and rejoining grammars
to a certain degree resembles that for replication of DNA --
enough so that some borrowed terminology might help appeal
to the intuition.

A DNA molecule consists of two "strands", which are joined
by "nucleobase pairs".
DNA uses
the matching of these nucleobase pairs for transcription
and replication.
The biochemical details are not important for our purposes,
and our analogy will be a loose one in any case.
But the following may serve as background:
In DNA, a nucleobase is one of the familiar
cytosine (C), guanine (G), adenine (A) and thymine (T).
In DNA, each nucleobase molecule is attached to a sugar to
form a nucleoside,
Each nucleoside, in turn, attached to phosphate group
(or, depending on the text, one or more phosphate groups)
to form
a nucleotide.

For our purpose, we'll follow the analogy very loosely,
and actually distort the meaning of "nucleoside" somewhat.
What we'll take out of this is

* that the *nucleobases* are
   where the two "strands" directly touch;

* as we follow
   the sequence nucleobase, nucleoside and nucleotide,
   we encounter "stuff" which is further away from where
   the two "strands" touch;

* nucleotides are a larger group, which include nucleosides
    and nucleobases.

As a mnemonic, note that "base",
"side" and "tide" are in alphabetical order.

## Creating the transcription grammar

In order to accomplish our purposes, we define
a "transcription grammar".
Let our original grammar be `g1`.
Ignore, for the moment, the two issues of nullable symbols,
and of empty rules.
We need to define, for every rule in `g1`, two 'nucleotide rules',
a `left nucleotide` and a `right nucleotide`.

First, we'll need some new symbols.
For every non-terminal, we will want a left
and a right version.
We will call the right and left variants
that we create for the transcription grammar,
"nucleoside symbols",
or just nucleosides.
For example, for the symbol `A`,
we want two nucleoside symbols, `A-L` and `A-R`.

We will also defined a new set of "nucleobase symbols",
whose purpose will be to tell us where two parses
should "touch".
Nucleobase symbols,
like nucleoside symbols,
will be defined in right-left pairs.
Nuclebase symbols
have the form `b42R`,
and `b42L`;
where the initial `b` means "base";
`R` and `L` indicate, respectively,
the right and left member of the base pair;
and `42` represents some arbitrary number,
chosen to make sure that every base pair is unique.
(DNA manages with 4 base pairs, but the typical grammar
will need many more.)
Every pair of nucleotide rules must have a unique pair of nucleobase
symbols.

We will call the original grammar,
before it has transcription rules and symbols added to it,
the "pre-transcription grammar".
Similarly,
its rules are pre-transcription rules
and its symbols are pre-transcription symbols.

Let one of `g1`'s pre-transcription rules be
```
     X ::= A B C
```
The six pairs of 
"nucleotide rules" that we will need are
```
    1: X-L ::= b1L            X-R ::= b1R A B C
    2: X-L ::= A-L b2L        X-R ::= b2R A-R B C
    3: X-L ::= A b3L          X-R ::= b3R B C
    4: X-L ::= A B-L b4L      X-R ::= b4R B-R C
    5: X-L ::= A B b5L        X-R ::= b5R C
    6: X-L ::= A B C-L b6L    X-R ::= b6R C-R
```
The pairs are numbered 1 to 6, the same number which
is used in the example to uniquely identify the nuclebase
symbols.

Pairs 1, 3 and 5 represent splits
at a point between two symbols --
these nucleotides will be called "inter-nucleotides".
Pairs 2, 4 and 6 represent splits
within a single symbol --
these nucleotides will be called "intra-nucleotides".
Every nucleotide pair corresponds to a dotted rule.
A "dotted rule" is the `g1` rule
with one of its positions marked with a dot.
Nucleotide pairs 1 and 2 correspond to the dotted rule
```
    X ::= . A B C
```
Nucleotide pairs 3 and 4 correspond to the dotted rule
```
    X ::= A . B C
```
Nucleotide pairs 5 and 6 correspond to the dotted rule
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
No nucleotides correspond to completions.

The inter-nucleotide pair for the dotted rule with the dot
before the first non-nulled RHS symbol is called the "prediction split pair".
In this example, the prediction nucleotide pair is pair 1.

Every pre-transcription rule will need `n` pairs of nucleotide rules,
where `n` is the number of symbols on the RHS of the
`g1` rule.
Empty rules can be ignored.

We need a pair of nucleotide rules to represent a "split" before the first
symbol of a `g1` rule, but we do not need a pair to represent a
split after the last symbol.
In other words, we need to deal with predictions,
but we can ignore completions.
We can also ignore any splits that occur before nulling symbols.

The above rules imply that left split rules can be nulling --
in fact one of the left split rules must be nulling.
But no right split rule can be nulling.
Informally, a right split rule must represent "something".

## Nulling symbols

Above, we assumed that no symbols are nulling.
Where a rule has nulling symbols on its RHS, we
make the following adjustments.

* There are no split pairs for dotted rules
    with the dot before a nulling symbol.

* This implies that the only split pair for
   a nulling rule is the prediction split pair.

## Deriving the left strand

Call the point at which we choose to split the parse,
the "split point".
At the split point,
we must derive a left strand.

The following discussion assumes that we know

* the dotted rules that apply at the current location; and

* how they link to child rules and symbols.

At the Libmarpa level both these things are known.
Unfortunately, as of this writing, only the dotted rules
are available at the SLIF level -- not their links.

### Is the parse exhausted?

First, we look for medial dotted rules at the split point.
Dotted rules are of three kinds:

* predictions, in which the dot is before the first RHS symbol;

* completions, in which the dot is after the last RHS symbol; and

* medials, which are those dotted rules which are neither
    predictions or completions.

There may be no medial dotted rules.
In this case the parse is exhausted -- it can go no further.
We do not continue with the following steps.

If there is completed start rule,
the parse was a success,
and we will be able to derive a full parse forest,
If there is a completion,
other than of the start rule,
we will be able to derive a parse forest,
but it will not be a left-active strand -- it will be
the final parse forest
and there will be no way of
joining it up with a parse forest to its right.

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

[ *Corrected to here* ]

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
