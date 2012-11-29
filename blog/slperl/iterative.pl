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
use Getopt::Long;

use Marpa::R2 2.027_003;

our $ORIGIN;

sub usage {
    die <<"END_OF_USAGE_MESSAGE";
$PROGRAM_NAME [-n] 'exp'
$PROGRAM_NAME [-n] < file
END_OF_USAGE_MESSAGE
} ## end sub usage

my $show_position_flag;
my $quiet_flag;
my $getopt_result = Getopt::Long::GetOptions(
    'n!' => \$show_position_flag,
    'q!' => \$quiet_flag,
);
usage() if not $getopt_result;

my $string = do { local $INPUT_RECORD_SEPARATOR = undef; <> };

## no critic (Subroutines::RequireFinalReturn)
sub do_undef       { undef; }
sub do_arg1        { $_[2]; }
sub do_what_I_mean { shift; return $_[0] if scalar @_ == 1; return \@_ }
## use critic

sub do_target {
    my $origin = ( Marpa::R2::Context::location() )[0];
    return if $origin != $ORIGIN;
    return $_[1];
} ## end sub do_target

my $perl_grammar = Marpa::R2::Grammar->new(
    {   scannerless => 1,
        actions        => 'main',
        default_action => 'do_what_I_mean',
        rules          => [ <<'END_OF_RULES' ]
:start ::= start
start ::= prefix target action => do_arg1
prefix ::= any_token* action => do_undef
target ::= expression action => do_target
expression ::=
     number
   | scalar
   | op_lparen expression op_rparen assoc => group
  || '--' expression
   | '++' expression
   | expression '--'
   | expression '++'
  || expression '**' expression assoc => right
  || '-' expression
   | '+' expression
   | '!' expression
   | '!' expression
  || expression '*' expression
   | expression '/' expression
   | expression '%' expression
   | expression 'x' expression
  || expression '+' expression
   | expression '-' expression
  || expression '<<' expression
   | expression '>>' expression
  || expression '&' expression
  || expression '|' expression
   | expression '^' expression
  || expression '=' expression assoc => right
  || expression ',' expression
optional_digits ~ [\d]*
digits ~ [\d]+
number ~ digits
number ~ digits [.] optional_digits
number ~ [.] digits
scalar ~ '$' [\w]+
END_OF_RULES
    }
);

$perl_grammar->precompute();

sub My_Error::last_completed_range {
    my ( $self, $symbol_name, $latest_earley_set ) = @_;
    my $grammar      = $self->{grammar};
    my $recce        = $self->{recce};
    my @sought_rules = ();
    for my $rule_id ( $grammar->rule_ids() ) {
        my ($lhs) = $grammar->bnf_rule($rule_id);
        push @sought_rules, $rule_id if $lhs eq $symbol_name;
    }
    die "Looking for completion of non-existent rule lhs: $symbol_name"
        if not scalar @sought_rules;
    $latest_earley_set //= $recce->latest_earley_set();
    my $earley_set = $latest_earley_set;

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

my @positions = (0);
my $recce = Marpa::R2::Recognizer->new( { grammar => $perl_grammar } );

# A quasi-object, for internal use only
my $self = bless {
    grammar   => $perl_grammar,
    input     => \$string,
    recce     => $recce,
    positions => \@positions
    },
    'My_Error';

local $My_Actions::SELF = $self;
my $event_count;

if ( not defined eval { $event_count = $recce->sl_read($string); 1 } ) {

    # Add last expression found, and rethrow
    my $eval_error = $EVAL_ERROR;
    chomp $eval_error;
    die $self->show_last_expression(), "\n", $eval_error, "\n";
} ## end if ( not defined eval { $event_count = $recce->sl_read...})
if ( not defined $event_count ) {
    die $self->show_last_expression(), "\n", $recce->sl_error();
}

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

my $end_of_search;
my @results = ();
RESULTS: while (1) {
    my ( $origin, $end ) =
        $self->last_completed_range( 'target', $end_of_search );
    last RESULTS if not defined $origin;
    push @results, [ $origin, $end ];
    $end_of_search = $origin;
} ## end RESULTS: while (1)

RESULT: for my $result ( reverse @results ) {
    my ( $origin, $end ) = @{$result};
    my $slice = $self->input_slice( $origin, $end );
    $slice =~ s/ \A \s* //xms;
    $slice =~ s/ \s* \z //xms;
    $slice =~ s/ \n / /gxms;
    $slice =~ s/ \s+ / /gxms;
    print qq{$origin-$end: }
        or die "print() failed: $ERRNO"
        if $show_position_flag;
    say $slice or die "say failed: $ERRNO";
    $recce->set( { end => $end } );
    my $value;
    VALUE: while ( not defined $value ) {
        local $main::ORIGIN = $origin;
        my $value_ref = $recce->value();
        last VALUE if not defined $value_ref;
        $value = ${$value_ref};
    } ## end VALUE: while ( not defined $value )
    if ( not defined $value ) {
        say 'No parse'
            or die "say() failed: $ERRNO";
        next RESULT;
    }
    say Data::Dumper::Dumper($value)
        or die "say() failed: $ERRNO"
        if not $quiet_flag;
    $recce->reset_evaluation();
} ## end RESULT: for my $result ( reverse @results )

# vim: expandtab shiftwidth=4:
