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
use autodie;

use English qw( -no_match_vars );

my $BNF = <<'END_OF_BNF';
# Non-element tokens
cruft ::= CRUFT
comment ::= C
pi ::= PI
decl ::= D
pcdata ::= PCDATA
cdata ::= CDATA
whitespace ::= WHITESPACE
# SGML flows
SGML_flow_item ::= comment
SGML_flow_item ::= pi
SGML_flow_item ::= decl
SGML_flow_item ::= whitespace
SGML_flow_item ::= cruft
SGML_flow ::= SGML_flow_item*

# For element x,
# ELE_x is complete element
# S_x is start tag
# E_x is end tag
# EC_x is the element's contents
#   The contents of many elements consists of zero or more items
# EI_x is a content "item" for element x

# Top-level structure
document ::= prolog ELE_html trailer EOF
prolog ::= SGML_flow
trailer ::= SGML_flow
ELE_html ::= S_html EC_html E_html
EC_html ::= SGML_flow ELE_head SGML_flow ELE_body SGML_flow
ELE_head ::= S_head EC_head E_head
EC_head ::= head_item*
ELE_body ::= S_body mixed_flow E_body

# Common types of element content
empty ::=
mixed_flow ::= mixed_flow_item*
mixed_flow_item ::= block_element
mixed_flow_item ::= inline_flow_item
block_element ::= ELE_table
block_element ::= list_item_element
inline_element ::= ELE_script
inline_element ::= ELE_object
head_item ::= ELE_script
head_item ::= ELE_object
head_item ::= ELE_style
head_item ::= ELE_meta
head_item ::= ELE_link
head_item ::= ELE_title
head_item ::= ELE_base
head_item ::= SGML_flow_item
inline_flow ::= inline_flow_item*
inline_flow_item ::= pcdata_flow_item
inline_flow_item ::= inline_element
pcdata_flow ::= pcdata_flow_item*
pcdata_flow_item ::= cdata
pcdata_flow_item ::= pcdata
pcdata_flow_item ::= SGML_flow_item
cdata_flow ::= cdata_flow_item*
cdata_flow_item ::= cdata

# Alphabetically, by tagname
ELE_base ::= S_base empty E_base
EC_colgroup ::= EI_colgroup*
EI_colgroup ::= ELE_col
EI_colgroup ::= SGML_flow_item
select_flow_item ::= ELE_optgroup
select_flow_item ::= ELE_option
select_flow_item ::= SGML_flow_item
table_flow_item ::= ELE_caption
table_flow_item ::= ELE_col
table_flow_item ::= ELE_colgroup
table_flow_item ::= ELE_tbody
table_flow_item ::= ELE_tfoot
table_flow_item ::= ELE_thead
table_flow_item ::= SGML_flow_item
table_flow ::= table_flow_item*
ELE_isindex ::= S_isindex empty E_isindex
list_item_flow ::= list_item_flow_item*
list_item_flow_item ::= SGML_flow_item
list_item_flow_item ::= block_element
list_item_flow_item ::= cdata
list_item_flow_item ::= header_element
list_item_flow_item ::= inline_element
list_item_flow_item ::= pcdata
ELE_link ::= S_link empty E_link
ELE_meta ::= S_meta empty E_meta
Item_object ::= ELE_param
EC_object ::= Item_object*
ELE_object ::= S_object EC_object E_object
Item_object ::= mixed_flow_item
EC_optgroup ::= EI_optgroup*
EI_optgroup ::= ELE_option
EI_optgroup ::= SGML_flow_item
ELE_param ::= S_param inline_flow E_param
ELE_script ::= S_script inline_flow E_script
EC_select ::= select_flow_item*
ELE_style ::= S_style inline_flow E_style
ELE_table ::= S_table table_flow E_table
EC_tbody ::= EI_tbody*
EI_tbody ::= ELE_tr
ELE_tbody ::= S_tbody EC_tbody E_tbody
EI_tbody ::= SGML_flow_item
ELE_td ::= S_td mixed_flow E_td
ELE_title ::= S_title inline_flow E_title
EC_tr ::= EI_tr*
EI_tr ::= ELE_td
EI_tr ::= ELE_th
ELE_tr ::= S_tr EC_tr E_tr
EI_tr ::= SGML_flow_item
END_OF_BNF

@Marpa::R2::HTML::Internal::CORE_RULES = ();

my %handler = (
    cruft      => 'SPE_CRUFT',
    comment    => 'SPE_COMMENT',
    pi         => 'SPE_PI',
    decl       => 'SPE_DECL',
    document   => 'SPE_TOP',
    whitespace => 'SPE_WHITESPACE',
    pcdata     => 'SPE_PCDATA',
    cdata      => 'SPE_CDATA',
    prolog     => 'SPE_PROLOG',
    trailer    => 'SPE_TRAILER',
);

LINE: for my $bnf_production ( split /\n/xms, $BNF ) {
    $bnf_production =~ s/ [#] .* //;    # Remove comments
    next LINE
        if not $bnf_production =~ / \S /xms;    # ignore all-whitespace line
    my $sequence = ( $bnf_production =~ s/ [*] \s* $//xms );
    $bnf_production =~ s/ \s* [:][:][=] \s* / /xms;
    my @symbols         = ( split q{ }, $bnf_production );
    my $lhs             = shift @symbols;
    my %rule_descriptor = (
        lhs => $lhs,
        rhs => \@symbols,
    );
    if ($sequence) {
        $rule_descriptor{min} = 0;
    }
    if ( my $handler = $handler{$lhs} ) {
        $rule_descriptor{action} = $handler;
    }
    elsif ( $lhs =~ /^ELE_/xms ) {
        $rule_descriptor{action} = "$lhs";
    }
    push @Marpa::R2::HTML::Internal::CORE_RULES, \%rule_descriptor;
} ## end LINE: for my $bnf_production ( split /\n/xms, $BNF )

open my $fh, q{<}, '../../../../../..//inc/Marpa/R2/legal.pl';
my $legal = join q{}, <$fh>;
close $fh;

my $output = $legal;
$output .=  "\n";

$output .= "# This file was generated automatically by $PROGRAM_NAME\n";
$output .= "# The date of generation was " . ( scalar localtime() );
$output .= "\n\n";

$output .= 'package Marpa::R2::HTML::Internal;';
$output .= "\n\n";

require Data::Dumper;
$output .= Data::Dumper->Purity(1)
    ->Dump( [ \@Marpa::R2::HTML::Internal::CORE_RULES ], [qw(CORE_RULES)] );

my @element_hierarchy = (
    [qw( span option )],
    [qw( li optgroup dd dt )],
    [qw( dir menu )],
    [qw( div )],
    [qw( ul ol dl )],
    [qw( th td )],
    [qw( tr )],
    [qw( col )],
    [qw( caption colgroup thead tfoot tbody )],
    [qw( table )],
    [qw( p )],
    [qw( head body )],
    [qw( html )],
);

my @last_resort_tags = qw(S_table E_body E_html);

my @tag_hierarchy = ();
push @tag_hierarchy,
    grep { not $_ ~~ \@last_resort_tags }
    map { 'S_' . $_ } map { @{$_} } reverse @element_hierarchy;
push @tag_hierarchy,
    grep { not $_ ~~ \@last_resort_tags }
    map { 'E_' . $_ } map { @{$_} } @element_hierarchy;
push @tag_hierarchy, @last_resort_tags;

say Data::Dumper::Dumper(\@tag_hierarchy);

open my $out_fh, q{>}, 'Core_Grammar.pm';
say {$out_fh} $output;
close $out_fh;
