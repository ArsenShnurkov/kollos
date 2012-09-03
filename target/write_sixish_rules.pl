#!perl

use 5.010;
use strict;
use warnings;

use Data::Dumper;
BEGIN { require './OP4.pm' }

my $OP_rules = Marpa::R2::Demo::OP4::parse_rules( <<'END_OF_RULES');
    <top> ::= <short rule>
    <short rule> ::= <rhs> :action<do_short_rule>
    <rhs> ::= <concatenation>
    <concatenation> ::=
    <concatenation> ::= <concatenation> <opt ws> <quantified atom> :action<do_remove_undefs>
    <opt ws> ::= :action<do_undef>
    <opt ws> ::= <opt ws> <ws char> :action<do_undef>
    <quantified atom> ::= <atom> <opt ws> <quantifier>
    <quantified atom> ::= <atom>
    <atom> ::= <quoted literal>
        <quoted literal> ::= <single quote> <single quoted char seq> <single quote>
    <single quoted char seq> ::= <single quoted char>*
    <atom> ::= <self>
    <self> ::= '<~~>' :action<do_self>
    <quantifier> ::= '*'
END_OF_RULES

say <<'END_OF_CODE';
package Marpa::R2::Sixish::Own_Rules;
END_OF_CODE

say Data::Dumper->Dump([$OP_rules], [qw(rules)]);

print <<'END_OF_CODE';
1;
END_OF_CODE

