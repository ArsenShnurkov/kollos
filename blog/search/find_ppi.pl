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
use Marpa::R2 2.024000;
use PPI;

my %token_by_structure = (
    q{(} => 'LPAREN',
    q{)} => 'RPAREN',
    q{[} => 'LSQUARE',
    q{]} => 'RSQUARE',
    q[{] => 'LCURLY',
    q[}] => 'RCURLY',
    q{;} => 'SEMI',
);

my %tokens_by_op = (
    q{->}  => ['ARROW'],               # 1
    q{--}  => [qw(PREDEC POSTDEC)],    # 2
    q{++}  => [qw(PREINC POSTINC)],    # 2
    q{**}  => ['POWOP'],               # 3
    q{~}   => ['TILDE'],               # 4
    q{!}   => ['BANG'],                # 4
    q{\\}  => ['REFGEN'],              # 4
    q{=~}  => ['MATCHOP'],             # 5
    q{!~}  => ['MATCHOP'],             # 5
    q{/}   => ['MULOP'],               # 6
    q{*}   => ['MULOP'],               # 6
    q{%}   => ['MULOP'],               # 6
    q{x}   => ['MULOP'],               # 6
    q{-}   => [qw(ADDOP UMINUS)],      # 7
    q{.}   => ['ADDOP'],               # 7
    q{+}   => [qw(ADDOP PLUS)],        # 7
    q{<<}  => ['SHIFTOP'],             # 8
    q{>>}  => ['SHIFTOP'],             # 8
    q{-A}  => ['UNIOP'],               # 9
    q{-b}  => ['UNIOP'],               # 9
    q{-B}  => ['UNIOP'],               # 9
    q{-c}  => ['UNIOP'],               # 9
    q{-C}  => ['UNIOP'],               # 9
    q{-d}  => ['UNIOP'],               # 9
    q{-e}  => ['UNIOP'],               # 9
    q{-f}  => ['UNIOP'],               # 9
    q{-g}  => ['UNIOP'],               # 9
    q{-k}  => ['UNIOP'],               # 9
    q{-l}  => ['UNIOP'],               # 9
    q{-M}  => ['UNIOP'],               # 9
    q{-o}  => ['UNIOP'],               # 9
    q{-O}  => ['UNIOP'],               # 9
    q{-p}  => ['UNIOP'],               # 9
    q{-r}  => ['UNIOP'],               # 9
    q{-R}  => ['UNIOP'],               # 9
    q{-s}  => ['UNIOP'],               # 9
    q{-S}  => ['UNIOP'],               # 9
    q{-t}  => ['UNIOP'],               # 9
    q{-T}  => ['UNIOP'],               # 9
    q{-u}  => ['UNIOP'],               # 9
    q{-w}  => ['UNIOP'],               # 9
    q{-W}  => ['UNIOP'],               # 9
    q{-x}  => ['UNIOP'],               # 9
    q{-X}  => ['UNIOP'],               # 9
    q{-z}  => ['UNIOP'],               # 9
    q{ge}  => ['RELOP'],               # 10
    q{gt}  => ['RELOP'],               # 10
    q{le}  => ['RELOP'],               # 10
    q{lt}  => ['RELOP'],               # 10
    q{<=}  => ['RELOP'],               # 10
    q{<}   => ['RELOP'],               # 10
    q{>=}  => ['RELOP'],               # 10
    q{>}   => ['RELOP'],               # 10
    q{cmp} => ['EQOP'],                # 11
    q{eq}  => ['EQOP'],                # 11
    q{ne}  => ['EQOP'],                # 11
    q{~~}  => ['EQOP'],                # 11
    q{<=>} => ['EQOP'],                # 11
    q{==}  => ['EQOP'],                # 11
    q{!=}  => ['EQOP'],                # 11
    q{&}   => ['BITANDOP'],            # 12
    q{^}   => ['BITOROP'],             # 13
    q{|}   => ['BITOROP'],             # 13
    q{&&}  => ['ANDAND'],              # 14
    q{||}  => ['OROR'],                # 15
    q{//}  => ['DORDOR'],              # 15
    q{..}  => ['DOTDOT'],              # 16
    q{...} => ['YADAYADA'],            # 17
    q{:}   => ['COLON'],               # 18
    q{?}   => ['QUESTION'],            # 18
    q{^=}  => ['ASSIGNOP'],            # 19
    q{<<=} => ['ASSIGNOP'],            # 19
    q{=}   => ['ASSIGNOP'],            # 19
    q{>>=} => ['ASSIGNOP'],            # 19
    q{|=}  => ['ASSIGNOP'],            # 19
    q{||=} => ['ASSIGNOP'],            # 19
    q{-=}  => ['ASSIGNOP'],            # 19
    q{/=}  => ['ASSIGNOP'],            # 19
    q{.=}  => ['ASSIGNOP'],            # 19
    q{*=}  => ['ASSIGNOP'],            # 19
    q{**=} => ['ASSIGNOP'],            # 19
    q{&=}  => ['ASSIGNOP'],            # 19
    q{&&=} => ['ASSIGNOP'],            # 19
    q{%=}  => ['ASSIGNOP'],            # 19
    q{+=}  => ['ASSIGNOP'],            # 19
    q{x=}  => ['ASSIGNOP'],            # 19
    q{,}   => ['COMMA'],               # 20
    q{=>}  => ['COMMA'],               # 20
    q{not} => ['NOTOP'],               # 22
    q{and} => ['ANDOP'],               # 23
    q{or}  => ['OROP'],                # 24
    q{xor} => ['DOROP'],               # 24
);

my $target_grammar = Marpa::R2::Grammar->new(
    {   start => 'start',
        rules => [ <<'END_OF_RULES' ]
start ::= prefix target
prefix ::= any_token*
target ::= expression
expression ::=
     number | variable
  || LPAREN expression RPAREN assoc => group
  || PREINC expression
   | PREDEC expression
   | expression POSTINC
   | expression POSTDEC
  || expression POWOP expression assoc => right
  || BANG expression 
   | TILDE expression 
   | UMINUS expression
  || expression MULOP expression
  || expression ADDOP expression
  || expression BITANDOP expression
  || expression BITOROP expression
  || expression ANDAND expression
  || expression OROR expression
END_OF_RULES
    }
);

$target_grammar->precompute();

# Prune the tables while we are building the grammar
for my $structure ( keys %token_by_structure ) {
    my $token = $token_by_structure{$structure};
    if ( not $target_grammar->check_terminal($token) ) {
        # say STDERR "Token $token is not in grammar";
        delete $token_by_structure{$structure};
    }
} ## end for my $structure ( keys %token_by_structure )

for my $op ( keys %tokens_by_op ) {
    my $tokens = $tokens_by_op{$op};
    my @tokens_used = ();
    for my $token ( @{$tokens} ) {
        if ( $target_grammar->check_terminal($token) ) {
            push @tokens_used, $token;
        }
        else {
            # say STDERR "Token $token is not in grammar";
        }
    } ## end for my $token ( @{$tokens} )
    if (scalar @tokens_used) { $tokens_by_op{$op} = \@tokens_used; }
    else              { delete $tokens_by_op{$op}; }
} ## end for my $structure ( keys %tokens_by_op )

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

sub My_Error::show_position {
    my ( $self, $position ) = @_;
    my $input = $self->{input};
    my $local_string = substr ${$input}, $position, 40;
    $local_string =~ s/\n/\\n/gxms;
    return $local_string;
} ## end sub My_Error::show_position

my $string    = join q{}, <>;
my @PPI_token_by_earley_set = ();
my $recce     = Marpa::R2::Recognizer->new(
    { grammar => $target_grammar,
       trace_terminals => 1
    } );

# A quasi-object, for internal use only
my $self = bless {
    grammar   => $target_grammar,
    input     => \$string,
    recce     => $recce,
    PPI_token_by_earley_set => \@PPI_token_by_earley_set
    },
    'My_Error';

my $document = PPI::Document->new(\$string);
$document->index_locations();
my @tokens =$document->tokens();

TOKEN: for my $PPI_token (@tokens) {

    my @tokens = ('any_token');
    my $content = $PPI_token->{content};
    my $PPI_type = ref $PPI_token;
    GIVEN_PPI_TYPE: {
        if ( $PPI_type eq 'PPI::Token::Symbol' ) {
            push @tokens, 'variable';
            last GIVEN_PPI_TYPE;
        }
        if ( $PPI_type eq 'PPI::Token::Structure' ) {
            my $token = $token_by_structure{$content};
            # For now, ignore if not defined
            # die "No token for structure $content" if not defined $token;
            push @tokens, $token if defined $token;
            last GIVEN_PPI_TYPE;
        }
        if ( $PPI_type eq 'PPI::Token::Operator' ) {
            my $tokens = $tokens_by_op{$content};
            # For now, ignore if not defined
            # die "No tokens for operator $content" if not defined $tokens;
            push @tokens, @{$tokens} if defined $tokens;
            last GIVEN_PPI_TYPE;
        }
        if (   $PPI_type eq 'PPI::Token::Number'
            or $PPI_type eq 'PPI::Token::Number::Float'
            or $PPI_type eq 'PPI::Token::Magic'
            or $PPI_type eq 'PPI::Token::Number::Version' )
        {
            push @tokens, 'number';
            last GIVEN_PPI_TYPE;
        } ## end if ( $PPI_type eq 'PPI::Token::Number' or $PPI_type ...)
    } ## end GIVEN_PPI_TYPE:

    ## parse should never get exhausted
    for my $token (@tokens) {
        # say "$PPI_type; $token; $content" ;
        $recce->alternative( $token, \$content );
    }
    $recce->earleme_complete();
    my $latest_earley_set_ID = $recce->latest_earley_set();
    $PPI_token_by_earley_set[$latest_earley_set_ID] = $PPI_token;
} ## end TOKEN: while ( pos $string < $length )

# Given a string, an earley set to position mapping,
# and two earley sets, return the slice of the string
sub My_Error::input_slice {
    my ( $self, $start, $end ) = @_;
    my $token_by_earley_set = $self->{PPI_token_by_earley_set};
    return if not defined $start;
    return join q{}, map { defined $_ ? $_->content() : q{} } @{$token_by_earley_set}[$start .. $end];
} ## end sub My_Error::input_slice

my $end_of_search;
my @results = ();
RESULTS: while (1) {
    my ( $origin, $end ) =
        $self->last_completed_range( 'target', $end_of_search );
    last RESULTS if not defined $origin;
    push @results, [$origin, $end];
    $end_of_search = $origin - 1;
}
for my $result (reverse @results) {
    my ($origin, $end) = @{$result};
    my $slice = $self->input_slice( $origin, $end );
    $slice =~ s/ \A \s* //xms;
    $slice =~ s/ \s* \z //xms;
    $slice =~ s/ \n / /gxms;
    $slice =~ s/ \s+ / /gxms;
    say qq{$origin-$end: "$slice"};
} ## end RESULTS: while (1)

# vim: expandtab shiftwidth=4:
