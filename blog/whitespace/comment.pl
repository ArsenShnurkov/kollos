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
use Getopt::Long;

my $do_demo = 0;
my $getopt_result = GetOptions( "demo!" => \$do_demo, );

sub usage {
    die <<"END_OF_USAGE_MESSAGE";
$PROGRAM_NAME --demo
$PROGRAM_NAME 'exp' [...]

Run $PROGRAM_NAME with either the "--demo" argument
or a series of calculator expressions.
END_OF_USAGE_MESSAGE
} ## end sub usage

if ( not $getopt_result ) {
    usage();
}
if ($do_demo) {
    if ( scalar @ARGV > 0 ) { say join q{ }, @ARGV; usage(); }
}
elsif ( scalar @ARGV <= 0 ) { usage(); }

my $prefix_grammar = Marpa::R2::Grammar->new(
    {
        action_object        => 'My_Actions',
        default_action => 'do_arg0',
        scannerless => 1,
        rules          => [ <<'END_OF_RULES' ]
:start ::= Script
Script ::= Calculation* action => do_list
Calculation ::= Expression | 'say' Expression
Expression ::=
     Number
   | '+' Expression Expression action => do_add
Number ~ [\d] + action => do_literal
:comment ~ <hash comment>
<hash comment> ~ '#' <hash comment body> <hash comment end>
<hash comment body> ~ <hash comment char>*
<hash comment end> ~ :$ | <vertical space char>
<vertical space char> ~ [\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
<hash comment char> ~ [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
END_OF_RULES
    }
);

package My_Actions;
our $SELF;
sub new { return $SELF }
sub do_list {
    my ($self, @results) = @_;
    return +(scalar @results) . ' results: ' . join q{ }, @results;
}
sub do_literal {
    my $self = shift;
    my $recce = $self->{recce};
    my ( $start, $end ) = Marpa::R2::Context::location();
    my $result = $recce->sl_range_to_string($start, $end);
    $result =~ s/ \A \s+ //xms;
    $result =~ s/ \s+ \z //xms;
    return $result;
} ## end sub do_literal

sub do_add  { shift; return $_[0] + $_[1] }
sub do_arg0 { shift; return shift; }

package main;

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

sub My_Error::show_last_expression {
    my ($self) = @_;
    my ( $start, $end ) = $self->last_completed_range('Expression');
    return 'No expression was successfully parsed' if not defined $start;
    my $last_expression = $self->{recce}->sl_range_to_string( $start, $end );
    return "Last expression successfully parsed was: $last_expression";
} ## end sub My_Error::show_last_expression

sub my_parser {
    my ( $grammar, $string ) = @_;

    my $self = bless { grammar => $grammar, input => \$string, }, 'My_Error';
    local $My_Actions::SELF = $self;

    my $recce = Marpa::R2::Recognizer->new( { grammar => $grammar } );
    $self->{recce} = $recce;
    my $event_count;

    if ( not defined eval { $event_count = $recce->sl_read($string); 1 } ) {

        # Add last expression found, and rethrow
        my $eval_error = $EVAL_ERROR;
        chomp $eval_error;
        die $self->show_last_expression(), "\n", $eval_error, "\n";
    } ## end if ( not defined eval { $recce->sl_read($string)...})
    if (not defined $event_count) {
        die $self->show_last_expression(), "\n", $recce->sl_error();
    }
    $recce->sl_end_input();
    my $value_ref = $recce->value;
    if ( not defined $value_ref ) {
        say STDERR $recce->show_progress();
        die $self->show_last_expression(), "\n",
            "No parse was found, after reading the entire input\n";
    }
    return ${$value_ref};
} ## end sub my_parser

my @test_strings;
if ($do_demo) {
    push @test_strings,
    <<'END_OF_STRING';
#this is a first first comment
2
# this is my very first comment
5 #this is a final comment
END_OF_STRING

} else {
    push @test_strings, shift;
}

TEST:
for my $test_string (@test_strings) {
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
} ## end TEST: for my $test_string (@test_strings)

# vim: expandtab shiftwidth=4:
