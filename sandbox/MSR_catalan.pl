#!perl
use 5.010;
use strict;
use warnings;

use English qw( -no_match_vars );
use Marpa::XS;
use MarpaX::Simple::Rules 'parse_rules';

my $catalan_rules = parse_rules(<<"RULES");
     pair ::= a a
     pair ::= pair a
     pair ::= a pair
     pair ::= pair pair
RULES

my $grammar = Marpa::XS::Grammar->new(
    {   start => 'pair',
        rules => $catalan_rules,
    }
);
$grammar->precompute();

sub do_catalan {
    my $n           = shift;
    my $parse_count = 0;
    my $recce       = Marpa::XS::Recognizer->new( { grammar => $grammar } );

    # Just in case
    $recce->set( { max_parses => 999, } );
    for my $token_ix ( 0 .. $n - 1 ) {
        defined $recce->read('a') or die "Cannot read char $token_ix";
    }
    $parse_count++ while $recce->value();
    return $parse_count;
} ## end sub do_catalan

my @catalan_numbers = ( 0, 1, 1, 2, 5, 14, 42, 132, 429 );

my $expected = join q{ }, @catalan_numbers;
my $actual = join q{ }, 0, 1, map { do_catalan($_) } 2 .. 8;

say "Expected: $expected" or die "say failed: $ERRNO";
say "  Actual: $actual"   or die "say failed: $ERRNO";
say $actual eq $expected ? 'OK' : 'MISMATCH' or die "say failed: $ERRNO";

