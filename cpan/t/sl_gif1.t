#!perl
# Copyright 2013 Jeffrey Kegler
# This file is part of Marpa::R2.  Marpa::R2 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R2.  If not, see
# http://www.gnu.org/licenses/.

# Tests which require only a GIF combination-- a grammar (G),
# input (I), and an (F) ASF output, with no semantics

use 5.010;
use strict;
use warnings;

use Test::More tests => 22;
use English qw( -no_match_vars );
use lib 'inc';
use Marpa::R2::Test;
use Marpa::R2;
use Data::Dumper;

my @tests_data = ();

my $aaaa_grammar = Marpa::R2::Scanless::G->new(
    {   source => \(<<'END_OF_SOURCE'),
    :start ::= quartet
    quartet ::= a a a a
    a ~ 'a'
END_OF_SOURCE
    }
);

push @tests_data, [
    $aaaa_grammar, 'aaaa',
    <<'END_OF_ASF',
CP2 Rule 1: quartet -> a a a a
  CP7 Symbol: a "a"
  CP6 Symbol: a "a"
  CP5 Symbol: a "a"
  CP4 Symbol: a "a"
END_OF_ASF
    'ASF OK',
    'Basic "a a a a" grammar'
    ]
    if 1;

my $abcd_grammar = Marpa::R2::Scanless::G->new(
    {   source => \(<<'END_OF_SOURCE'),
    :start ::= quartet
    quartet ::= a b c d
    a ~ 'a'
    b ~ 'b'
    c ~ 'c'
    d ~ 'd'
END_OF_SOURCE
    }
);

my $venus_grammar = Marpa::R2::Scanless::G->new(
    {   source => \(<<'END_OF_SOURCE'),
    :start ::= planet
    planet ::= hesperus
    planet ::= phosphorus
    hesperus ::= venus
    phosphorus ::= venus
    venus ~ 'venus'
END_OF_SOURCE
    }
);

push @tests_data, [
    $venus_grammar, 'venus',
    <<'END_OF_ASF',
Symbol #0, planet, has 2 symches
  Symch #0.0
  CP2 Rule 1: planet -> hesperus
    CP1 Rule 3: hesperus -> venus
      CP7 Symbol: venus "venus"
  Symch #0.1
  CP2 Rule 2: planet -> phosphorus
    CP6 Rule 4: phosphorus -> venus
      CP10 Symbol: venus "venus"
END_OF_ASF
    'ASF OK',
    '"Hesperus is Phosphorus"" grammar'
    ]
    if 1;

push @tests_data, [
    $abcd_grammar, 'abcd',
    <<'END_OF_ASF',
CP2 Rule 1: quartet -> a b c d
  CP7 Symbol: a "a"
  CP6 Symbol: b "b"
  CP5 Symbol: c "c"
  CP4 Symbol: d "d"
END_OF_ASF
    'ASF OK',
    'Basic "a b c d" grammar'
    ]
    if 1;

my $bb_grammar = Marpa::R2::Scanless::G->new(
    {   source => \(<<'END_OF_SOURCE'),
:start ::= top
top ::= b b
b ::= a a
b ::= a
a ~ 'a'
END_OF_SOURCE
    }
);

push @tests_data, [
    $bb_grammar, 'aaa',
    <<'END_OF_ASF',
CP2 Rule 1: top -> b b
  Factoring #0
    CP5 Rule 3: b -> a
      CP8 Symbol: a "a"
    CP4 Rule 2: b -> a a
      CP10 Symbol: a "a"
      CP9 Symbol: a "a"
  Factoring #1
    CP6 Rule 2: b -> a a
      CP15 Symbol: a "a"
      CP14 Symbol: a "a"
    CP12 Rule 3: b -> a
      CP18 Symbol: a "a"
END_OF_ASF
    'ASF OK',
    '"b b" grammar'
    ]
    if 1;

my $seq_grammar = Marpa::R2::Scanless::G->new(
    {   source => \(<<'END_OF_SOURCE'),
:start ::= sequence
sequence ::= item+
item ::= pair | singleton
singleton ::= 'a'
pair ::= item item
END_OF_SOURCE
    }
);

push @tests_data, [
    $seq_grammar, 'aa',
    <<'END_OF_ASF',
CP2 Rule 1: sequence -> item+
  Factoring #0
    CP4 Rule 2: item -> pair
      CP6 Rule 5: pair -> item item
        CP8 Rule 3: item -> singleton
          CP1 Rule 4: singleton -> [Lex-0]
            CP10 Symbol: [Lex-0] "a"
        CP7 Rule 3: item -> singleton
          CP12 Rule 4: singleton -> [Lex-0]
            CP13 Symbol: [Lex-0] "a"
  Factoring #1
    CP8 already displayed
    CP7 already displayed
END_OF_ASF
    'ASF OK',
    'Sequence grammar for "aa"'
    ]
    if 1;

push @tests_data, [
    $seq_grammar, 'aaa',
    <<'END_OF_ASF',
CP2 Rule 1: sequence -> item+
  Factoring #0
    CP4 Rule 2: item -> pair
      CP6 Rule 5: pair -> item item
        Factoring #0.0
          CP9 Rule 2: item -> pair
            CP11 Rule 5: pair -> item item
              CP13 Rule 3: item -> singleton
                CP1 Rule 4: singleton -> [Lex-0]
                  CP16 Symbol: [Lex-0] "a"
              CP7 Rule 3: item -> singleton
                CP18 Rule 4: singleton -> [Lex-0]
                  CP20 Symbol: [Lex-0] "a"
          CP8 Rule 3: item -> singleton
            CP21 Rule 4: singleton -> [Lex-0]
              CP23 Symbol: [Lex-0] "a"
        Factoring #0.1
          CP13 already displayed
          CP24 Rule 2: item -> pair
            CP19 Rule 5: pair -> item item
              CP7 already displayed
              CP8 already displayed
  Factoring #1
    CP9 already displayed
    CP8 already displayed
  Factoring #2
    CP13 already displayed
    CP7 already displayed
    CP8 already displayed
  Factoring #3
    CP13 already displayed
    CP24 already displayed
END_OF_ASF
    'ASF OK',
    'Sequence grammar for "aaa"'
    ]
    if 1;

my $venus_seq_grammar = Marpa::R2::Scanless::G->new(
    {   source => \(<<'END_OF_SOURCE'),
:start ::= sequence
sequence ::= item+
item ::= pair | Hesperus | Phosphorus
Hesperus ::= 'a'
Phosphorus ::= 'a'
pair ::= item item
END_OF_SOURCE
    }
);

push @tests_data, [
    $venus_seq_grammar, 'aa',
    <<'END_OF_ASF',
CP2 Rule 1: sequence -> item+
  Factoring #0
    CP4 Rule 2: item -> pair
      CP6 Rule 7: pair -> item item
        Symbol #0, item, has 2 symches
          Symch #0.0.0
          CP9 Rule 3: item -> Hesperus
            CP14 Rule 5: Hesperus -> [Lex-0]
              CP15 Symbol: [Lex-0] "a"
          Symch #0.0.1
          CP9 Rule 4: item -> Phosphorus
            CP1 Rule 6: Phosphorus -> [Lex-1]
              CP16 Symbol: [Lex-1] "a"
        Symbol #1, item, has 2 symches
          Symch #0.1.0
          CP8 Rule 3: item -> Hesperus
            CP18 Rule 5: Hesperus -> [Lex-0]
              CP20 Symbol: [Lex-0] "a"
          Symch #0.1.1
          CP8 Rule 4: item -> Phosphorus
            CP22 Rule 6: Phosphorus -> [Lex-1]
              CP24 Symbol: [Lex-1] "a"
  Factoring #1
    CP9 already displayed
    CP8 already displayed
END_OF_ASF
    'ASF OK',
    'Sequence grammar for "aa"'
    ]
    if 1;

my $nulls_grammar = Marpa::R2::Scanless::G->new(
    {   source => \(<<'END_OF_SOURCE'),
:start ::= top
top ::= a a a a
a ::= 'a'
a ::=
END_OF_SOURCE
    }
);

push @tests_data, [
    $nulls_grammar, 'aaaa',
    <<'END_OF_ASF',
CP2 Rule 1: top -> a a a a
  CP1 Rule 2: a -> [Lex-0]
    CP9 Symbol: [Lex-0] "a"
  CP3 Rule 2: a -> [Lex-0]
    CP10 Symbol: [Lex-0] "a"
  CP5 Rule 2: a -> [Lex-0]
    CP11 Symbol: [Lex-0] "a"
  CP4 Rule 2: a -> [Lex-0]
    CP13 Symbol: [Lex-0] "a"
END_OF_ASF
    'ASF OK',
    'Nulls grammar for "aaaa"'
    ]
    if 1;

push @tests_data, [
    $nulls_grammar, 'aaa',
    <<'END_OF_ASF',
CP2 Rule 1: top -> a a a a
  Factoring #0
    CP7 Symbol: a ""
    CP6 Rule 2: a -> [Lex-0]
      CP11 Symbol: [Lex-0] "a"
    CP5 Rule 2: a -> [Lex-0]
      CP13 Symbol: [Lex-0] "a"
    CP4 Rule 2: a -> [Lex-0]
      CP15 Symbol: [Lex-0] "a"
  Factoring #1
    CP6 already displayed
    CP17 Symbol: a ""
    CP5 already displayed
    CP4 already displayed
  Factoring #2
    CP6 already displayed
    CP5 already displayed
    CP18 Symbol: a ""
    CP4 already displayed
  Factoring #3
    CP6 already displayed
    CP5 already displayed
    CP4 already displayed
    CP20 Symbol: a ""
END_OF_ASF
    'ASF OK',
    'Nulls grammar for "aaa"'
    ]
    if 1;

push @tests_data, [
    $nulls_grammar, 'aa',
    <<'END_OF_ASF',
CP2 Rule 1: top -> a a a a
  Factoring #0
    CP6 Symbol: a ""
    CP5 Symbol: a ""
    CP3 Rule 2: a -> [Lex-0]
      CP11 Symbol: [Lex-0] "a"
    CP4 Rule 2: a -> [Lex-0]
      CP13 Symbol: [Lex-0] "a"
  Factoring #1
    CP6 already displayed
    CP3 already displayed
    CP15 Symbol: a ""
    CP4 already displayed
  Factoring #2
    CP6 already displayed
    CP3 already displayed
    CP4 already displayed
    CP17 Symbol: a ""
  Factoring #3
    CP3 already displayed
    CP4 already displayed
    CP20 Symbol: a ""
    CP19 Symbol: a ""
  Factoring #4
    CP3 already displayed
    CP23 Symbol: a ""
    CP15 already displayed
    CP4 already displayed
  Factoring #5
    CP3 already displayed
    CP23 already displayed
    CP4 already displayed
    CP17 already displayed
END_OF_ASF
    'ASF OK',
    'Nulls grammar for "aa"'
    ]
    if 1;

push @tests_data, [
    $nulls_grammar, 'a',
    <<'END_OF_ASF',
CP2 Rule 1: top -> a a a a
  Factoring #0
    CP7 Rule 2: a -> [Lex-0]
      CP12 Symbol: [Lex-0] "a"
    CP6 Symbol: a ""
    CP5 Symbol: a ""
    CP4 Symbol: a ""
  Factoring #1
    CP16 Symbol: a ""
    CP7 already displayed
    CP15 Symbol: a ""
    CP14 Symbol: a ""
  Factoring #2
    CP16 already displayed
    CP20 Symbol: a ""
    CP19 Symbol: a ""
    CP7 already displayed
  Factoring #3
    CP16 already displayed
    CP20 already displayed
    CP7 already displayed
    CP23 Symbol: a ""
END_OF_ASF
    'ASF OK',
    'Nulls grammar for "a"'
    ]
    if 1;

TEST:
for my $test_data (@tests_data) {
    my ( $grammar, $test_string, $expected_value, $expected_result,
        $test_name )
        = @{$test_data};

    my ( $actual_value, $actual_result ) =
        my_parser( $grammar, $test_string );
    Marpa::R2::Test::is(
        Data::Dumper::Dumper( \$actual_value ),
        Data::Dumper::Dumper( \$expected_value ),
        qq{Value of $test_name}
    );
    Test::More::is( $actual_result, $expected_result,
        qq{Result of $test_name} );
} ## end TEST: for my $test_data (@tests_data)

sub my_parser {
    my ( $grammar, $string ) = @_;

    my $slr = Marpa::R2::Scanless::R->new( { grammar => $grammar } );

    if ( not defined eval { $slr->read( \$string ); 1 } ) {
        my $abbreviated_error = $EVAL_ERROR;
        chomp $abbreviated_error;
        $abbreviated_error =~ s/\n.*//xms;
        $abbreviated_error =~ s/^Error \s+ in \s+ string_read: \s+ //xms;
        return 'No parse', $abbreviated_error;
    } ## end if ( not defined eval { $slr->read( \$string ); 1 } )
    my $asf = Marpa::R2::ASF->new( { slr => $slr } );
    if ( not defined $asf ) {
        return 'No ASF', 'Input read to end but no ASF';
    }

    my $asf_desc = show($asf);
    return $asf_desc, 'ASF OK';

} ## end sub my_parser

# CHOICEPOINT_SEEN is a local -- this is to silence warnings
our %CHOICEPOINT_SEEN;

sub form_choice {
    my ( $parent_choice, $sub_choice ) = @_;
    return $sub_choice if not defined $parent_choice;
    return join q{.}, $parent_choice, $sub_choice;
}

sub show_symches {
    my ( $choicepoint, $parent_choice, $item_ix ) = @_;
    my $id = $choicepoint->base_id();
    if ( $CHOICEPOINT_SEEN{$id} ) {
        return ["CP$id already displayed"];
    }
    $CHOICEPOINT_SEEN{$id} = 1;

    # Check if choicepoint already seen?
    my $grammar      = $choicepoint->grammar();
    my @lines        = ();
    my $symch_indent = q{};

    my $symch_count  = $choicepoint->symch_count();
    my $symch_choice = $parent_choice;
    if ( $symch_count > 1 ) {
        $item_ix //= 0;
        push @lines,
              "Symbol #$item_ix, "
            . $choicepoint->symbol_name()
            . ", has $symch_count symches";
        $symch_indent .= q{  };
        $symch_choice = form_choice( $parent_choice, $item_ix );
    } ## end if ( $symch_count > 1 )
    for ( my $symch_ix = 0; $symch_ix < $symch_count; $symch_ix++ ) {
        $choicepoint->symch_set($symch_ix);
        my $current_choice =
            $symch_count > 1
            ? form_choice( $symch_choice, $symch_ix )
            : $symch_choice;
        my $indent = $symch_indent;
        if ( $symch_count > 1 ) {
            push @lines, $symch_indent . "Symch #$current_choice";
        }
        my $rule_id = $choicepoint->rule_id();
        if ( defined $rule_id ) {
            push @lines,
                (     $symch_indent
                    . "CP$id Rule "
                    . $grammar->brief_rule($rule_id) ),
                map { $symch_indent . q{  } . $_ }
                @{ show_factorings( $choicepoint, $current_choice ) };
        } ## end if ( $rule_id >= 0 )
        else {
            push @lines,
                map { $symch_indent . $_ }
                @{ show_symch_tokens( $choicepoint, $current_choice ) };
        }
    } ## end for ( my $symch_ix = 0; $symch_ix < $symch_count; $symch_ix...)
    return \@lines;
} ## end sub show_symches

# Show all the factorings of a SYMCH
sub show_factorings {
    my ( $choicepoint, $parent_choice ) = @_;

    # Check if choicepoint already seen?
    my @lines;
    my $factor_ix = 0;
    my $nid_count = $choicepoint->nid_count();
    for ( my $nid_ix = 0; $nid_ix < $nid_count; $nid_ix++ ) {
        $choicepoint->nid_set($nid_ix);

        $choicepoint->first_factoring();
        my $factoring = $choicepoint->factors();

        my $choicepoint_is_ambiguous = $choicepoint->ambiguous_prefix();
        my $factoring_is_ambiguous   = ( $nid_count > 1 )
            || $choicepoint_is_ambiguous;
        FACTOR: while ( defined $factoring ) {
            my $current_choice =
                $factoring_is_ambiguous
                ? form_choice( $parent_choice, $factor_ix )
                : $parent_choice;
            my $indent = q{};
            if ($factoring_is_ambiguous) {
                push @lines, "Factoring #$current_choice";
                $indent = q{  };
            }
            for ( my $item_ix = $#{$factoring}; $item_ix >= 0; $item_ix-- ) {
                my $item_choicepoint = $factoring->[$item_ix];
                push @lines, map { $indent . $_ } @{
                    show_symches(
                        $item_choicepoint, $current_choice,
                        ( $#{$factoring} - $item_ix )
                    )
                    };
            } ## end for ( my $item_ix = $#{$factoring}; $item_ix >= 0; ...)
            $choicepoint->next_factoring();
            $factoring = $choicepoint->factors();
            $factor_ix++;
        } ## end FACTOR: while ( defined $factoring )
    } ## end for ( my $nid_ix = 0; $nid_ix < $nid_count; $nid_ix++)
    return \@lines;
} ## end sub show_factorings

# Show all the tokens of a SYMCH
sub show_symch_tokens {
    my ($choicepoint) = @_;
    my $base_id = $choicepoint->base_id();

    # Check if choicepoint already seen?
    my @lines;

    for ( my $nid_ix = 0; $choicepoint->nid_set($nid_ix); $nid_ix++ ) {
        my $literal     = $choicepoint->literal();
        my $symbol_name = $choicepoint->symbol_name();
        push @lines, qq{CP$base_id Symbol: $symbol_name "$literal"};
    }
    return \@lines;
} ## end sub show_symch_tokens

sub show {
    my ($asf) = @_;
    my $top = $asf->top();
    local %CHOICEPOINT_SEEN = ();  ## no critic (Variables::ProhibitLocalVars)
    my $lines = show_symches($top);
    return join "\n", ( map { substr $_, 2 } @{$lines}[ 1 .. $#{$lines} ] ),
        q{};
} ## end sub show

# vim: expandtab shiftwidth=4:
