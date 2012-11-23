#!/usr/bin/perl
# Copyright 2012 Jeffrey Kegler
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

use 5.010;
use strict;
use warnings;
use English qw( -no_match_vars );
use Marpa::R2 2.023008;

my $prefix_grammar = Marpa::R2::Grammar->new(
    {   start          => 'Script',
        actions        => 'My_Actions',
        default_action => 'do_arg0',
        rules          => [ <<'END_OF_RULES' ]
Script ::=
     Expression
   | [s] [a] [y] :ws Expression action => do_arg1
Expression ::=
     :ows Number :ows
   | :ows [+] :ows Expression :ows action => do_add
Number ::= [\d] + action => do_number
END_OF_RULES
    }
);

sub My_Actions::do_add  { shift; return $_[1] + $_[2] }
sub My_Actions::do_arg0 { shift; return shift; }
sub My_Actions::do_arg1 { shift; return $_[1]; }

$prefix_grammar->precompute();

sub My_Error::last_completed_range {
    my ( $self, $symbol_name ) = @_;
    my $grammar      = $self->{grammar};
    my $recce        = $self->{recce};
    my @sought_rules = ();
    for my $rule_id ( $grammar->rule_ids() ) {
        my ($lhs) = $grammar->bnf_rule($rule_id);
        push @sought_rules, $rule_id if $lhs eq $symbol_name;
    }
    die "Looking for completion of non-existent rule lhs: $symbol_name"
        if not scalar @sought_rules;
    my $latest_earley_set = $recce->latest_earley_set();
    my $earley_set        = $latest_earley_set;

    # Initialize to one past the end, so we can tell if there were no hits
    my $first_origin = $latest_earley_set + 1;
    EARLEY_SET: while ( $earley_set >= 0 ) {
        my $report_items = $recce->progress($earley_set);
        ITEM: for my $report_item ( @{$report_items} ) {
            my ( $rule_id, $dot_position, $origin ) = @{$report_item};
            next ITEM if $dot_position != -1;
            next ITEM if not scalar grep { $_ == $rule_id } @sought_rules;
            next ITEM if $origin >= $first_origin;
            $first_origin = $origin;
        } ## end ITEM: for my $report_item ( @{$report_items} )
        last EARLEY_SET if $first_origin <= $latest_earley_set;
        $earley_set--;
    } ## end EARLEY_SET: while ( $earley_set >= 0 )
    return if $earley_set < 0;
    return ( $first_origin, $earley_set );
} ## end sub My_Error::last_completed_range

# Given a string, an earley set to position mapping,
# and two earley sets, return the slice of the string
sub My_Error::input_slice {
    my ( $self, $start, $end ) = @_;
    my $positions = $self->{positions};
    return if not defined $start;
    my $start_position = $positions->[$start];
    my $length         = $positions->[$end] - $start_position;
    return substr ${ $self->{input} }, $start_position, $length;
} ## end sub My_Error::input_slice

sub My_Error::show_last_expression {
    my ($self) = @_;
    my $last_expression =
        $self->input_slice( $self->last_completed_range('Expression') );
    return
        defined $last_expression
        ? "Last expression successfully parsed was: $last_expression"
        : 'No expression was successfully parsed';
} ## end sub My_Error::show_last_expression

sub My_Error::show_position {
    my ( $self, $position ) = @_;
    my $input = $self->{input};
    my $local_string = substr ${$input}, $position, 40;
    $local_string =~ s/\n/\\n/gxms;
    return $local_string;
} ## end sub My_Error::show_position

sub my_parser {
    my ( $grammar, $string ) = @_;
    my $recce = Marpa::R2::Recognizer->new( { grammar => $grammar } );

    # A quasi-object, for internal use only
    my $self = bless {
        grammar   => $grammar,
        input     => \$string,
        recce     => $recce,
        },
        'My_Error';

    $recce->read_string($string);
    my $value_ref = $recce->value;
    if ( not defined $value_ref ) {
        die $self->show_last_expression(), "\n",
            "No parse was found, after reading the entire input\n";
    }
    return ${$value_ref};
} ## end sub my_parser

TEST:
for my $test_string (
    '+++ 1 2 3 + + 1 2 4',
    'say + 1 2',
    '+ 1 say 2',
    '+ 1 2 3 + + 1 2 4',
    '+++',
    '++1 2++',
    '++1 2++3 4++',
    '1 + 2 +3  4 + 5 + 6 + 7'
    )
{
    my $output;
    my $eval_ok =
        eval { $output = my_parser( $prefix_grammar, $test_string ); 1 };
    my $eval_error = $EVAL_ERROR;
    if ( not defined $eval_ok ) {
        chomp $eval_error;
        say q{=} x 30;
        print qq{Input was "$test_string"\n},
            qq{Parse failed, with this diagnostic:\n},
            $eval_error, "\n";
        next TEST;
    } ## end if ( not defined $eval_ok )
    say q{=} x 30;
    print qq{Input was "$test_string"\n},
        qq{Parse was successful, output was "$output"\n};
} ## end TEST: for my $test_string ( '+++ 1 2 3 + + 1 2 4', 'say + 1 2'...)

# vim: expandtab shiftwidth=4:
