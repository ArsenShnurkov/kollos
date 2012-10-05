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
use Data::Dumper;

package HTML_Config;

use English qw( -no_match_vars );

our $BNF = <<'END_OF_BNF';
# Non-element tokens
cruft ::= CRUFT
comment ::= C
pi ::= PI
decl ::= D
pcdata ::= PCDATA
cdata ::= CDATA
whitespace ::= WHITESPACE
# SGML flows
SGML_item ::= comment
SGML_item ::= pi
SGML_item ::= decl
SGML_item ::= whitespace
SGML_item ::= cruft
SGML_flow ::= SGML_item*

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
ELE_head contains head_item
ELE_body is block_flow

# Common types of element content
empty ::=

mixed_flow ::= mixed_flow_item*
mixed_flow_item ::= anywhere_element
mixed_flow_item ::= block_element
mixed_flow_item ::= inline_element
mixed_flow_item ::= cdata
mixed_flow_item ::= pcdata
mixed_flow_item ::= SGML_item

block_flow ::= block_item*
block_item ::= SGML_item
block_item ::= block_element
block_item ::= anywhere_element
block_element ::= ELE_table
block_element ::= ELE_p
block_element ::= ELE_ol
block_element ::= ELE_ul
block_element ::= ELE_dl
block_element ::= ELE_div
block_element ::= ELE_dir
block_element ::= ELE_menu

# isindex can also be a block element
# and script can be a block and an inline element
# these will become "anywhere" elements
anywhere_element ::= ELE_script
anywhere_element ::= ELE_isindex
anywhere_element ::= ELE_textarea

head_item ::= SGML_item
head_item ::= head_element
head_item ::= anywhere_element
head_element ::= ELE_object
head_element ::= ELE_style
head_element ::= ELE_meta
head_element ::= ELE_link
head_element ::= ELE_title
head_element ::= ELE_base

inline_flow ::= inline_item*
inline_item ::= pcdata
inline_item ::= cdata
inline_item ::= SGML_item
inline_item ::= inline_element
inline_item ::= anywhere_element
inline_element ::= ELE_object
inline_element ::= ELE_select
inline_element ::= ELE_span
inline_element ::= ELE_map
inline_element ::= ELE_applet

pcdata_flow ::= pcdata_flow_item*
pcdata_flow_item ::= cdata
pcdata_flow_item ::= pcdata
pcdata_flow_item ::= SGML_item

cdata_flow ::= cdata_flow_item*
cdata_flow_item ::= cdata
cdata_flow_item ::= cruft

# Alphabetically, by tagname
ELE_base is empty
ELE_col is empty
ELE_colgroup contains ELE_col SGML_item
ELE_dd is mixed_flow
ELE_div is mixed_flow
ELE_dl contains SGML_item ELE_dt ELE_dd
ELE_dt is inline_flow
ELE_isindex is empty
ELE_li is mixed_flow
ELE_map contains block_element SGML_item ELE_area
ELE_area is empty
ELE_link is empty
ELE_meta is empty
ELE_object contains ELE_param mixed_flow_item
ELE_applet contains ELE_param mixed_flow_item
ELE_ol contains SGML_item ELE_li
ELE_dir contains SGML_item ELE_li
ELE_menu contains SGML_item ELE_li
ELE_optgroup contains ELE_option SGML_item
ELE_p is inline_flow
ELE_param is empty
ELE_script is cdata_flow
ELE_select contains ELE_optgroup ELE_option
ELE_span is inline_flow
ELE_style is cdata_flow
ELE_table contains ELE_caption ELE_col ELE_colgroup
ELE_table contains ELE_tbody ELE_tfoot ELE_thead
ELE_table contains SGML_item
ELE_textarea is cdata_flow
ELE_tbody contains SGML_item ELE_tr
ELE_td is mixed_flow
ELE_tfoot contains SGML_item ELE_tr
ELE_thead contains SGML_item ELE_tr
ELE_title is pcdata_flow
ELE_tr contains SGML_item ELE_th ELE_td
ELE_ul contains SGML_item ELE_li
END_OF_BNF

our %HANDLER = (
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

# block_element is for block-level ONLY elements.
# Note that isindex can be both a head element and
# and block level element in the body.
# ISINDEX is classified as a header_element
our %IS_BLOCK_ELEMENT = (
    address    => 'inline_flow',
    blockquote => 'mixed_flow',
    center     => 'mixed_flow',
    dir        => 'core',
    div        => 'core',
    dl         => 'core',
    fieldset   => 'mixed_flow',
    form       => 'mixed_flow',
    h1         => 'inline_flow',
    h2         => 'inline_flow',
    h3         => 'inline_flow',
    h4         => 'inline_flow',
    h5         => 'inline_flow',
    h6         => 'inline_flow',
    hr         => 'empty',
    menu       => 'core',
    noframes   => 'mixed_flow',
    noscript   => 'mixed_flow',
    ol         => 'core',
    p          => 'core',
    plaintext  => 'cdata_flow',
    pre        => 'inline_flow',
    table      => 'core',
    ul         => 'core',
    xmp        => 'cdata_flow',
);

our %IS_INLINE_ELEMENT = (
    a        => 'inline_flow',
    abbr     => 'inline_flow',
    acronym  => 'inline_flow',
    applet   => 'core',
    audio    => 'inline_flow',
    b        => 'inline_flow',
    basefont => 'empty',
    bdo      => 'inline_flow',
    big      => 'inline_flow',
    blink    => 'inline_flow',
    br       => 'empty',
    button   => 'inline_flow',
    cite     => 'inline_flow',
    code     => 'inline_flow',
    command  => 'inline_flow',
    dfn      => 'inline_flow',
    em       => 'inline_flow',
    embed    => 'inline_flow',
    font     => 'inline_flow',
    i        => 'inline_flow',
    img      => 'empty',
    input    => 'empty',
    input    => 'cdata_flow',
    kbd      => 'inline_flow',
    keygen   => 'inline_flow',
    label    => 'inline_flow',
    map     => 'core',
    mark     => 'inline_flow',
    meter    => 'inline_flow',
    nobr     => 'inline_flow',
    output   => 'inline_flow',
    progress => 'inline_flow',
    q        => 'inline_flow',
    rb       => 'inline_flow',
    rbc      => 'inline_flow',
    rp       => 'inline_flow',
    rt       => 'inline_flow',
    rtc      => 'inline_flow',
    ruby     => 'inline_flow',
    s        => 'inline_flow',
    samp     => 'inline_flow',
    select   => 'core',
    small    => 'inline_flow',
    span     => 'core',
    strike   => 'inline_flow',
    strong   => 'inline_flow',
    sub      => 'inline_flow',
    sup      => 'inline_flow',
    textarea => 'core',
    time     => 'inline_flow',
    tt       => 'inline_flow',
    u        => 'inline_flow',
    var      => 'inline_flow',
    video    => 'inline_flow',
    wbr      => 'inline_flow',
);

my @head_rubies   = qw( S_html S_head );
my @block_rubies  = qw( S_html S_head S_body );
my @inline_rubies = ( @block_rubies, qw(S_tbody S_tr S_td S_p) );

our %RUBY_CONFIG = (
    S_html              => [],
    S_head              => [qw( S_html )],
    S_body              => [qw( S_html S_head )],
    CDATA               => \@inline_rubies,
    PCDATA              => \@inline_rubies,
    '!start_tag'        => \@block_rubies,
    '!inline_start_tag' => \@inline_rubies,
    '!head_start_tag'   => \@head_rubies,
    S_area              => [ @block_rubies, 'S_map' ],
    S_option            => [ @inline_rubies, 'S_select' ],
    S_optgroup          => [ @inline_rubies, 'S_select' ],
    S_param             => [ @block_rubies, 'S_object' ],
    S_li                => [ @block_rubies, qw( !non_final_end S_ul) ],
    S_dt                => [ @block_rubies, 'S_dl' ],
    S_dd                => [ @block_rubies, 'S_dl' ],
    S_caption           => [ @block_rubies, qw( !non_final_end S_table ) ],
    S_col               => [ @block_rubies, qw( !non_final_end S_table ) ],
    S_colgroup          => [ @block_rubies, qw( !non_final_end S_table ) ],
    S_tbody             => [ @block_rubies, qw( !non_final_end S_table ) ],
    S_tfoot             => [ @block_rubies, qw( !non_final_end S_table ) ],
    S_thead             => [ @block_rubies, qw( !non_final_end S_table ) ],
    E_table             => [ @block_rubies, qw( !non_final_end S_table ) ],
    S_tr => [ @block_rubies, qw( S_tbody !non_final_end S_table ) ],
    S_th =>
        [ @block_rubies, qw( S_thead S_tbody S_tr !non_final_end S_table ) ],
    S_td => [ @block_rubies, qw( S_tbody S_tr !non_final_end S_table ) ],
    E_body => [qw( S_html S_head S_body )],
    E_html => [qw( S_html S_head S_body !non_final_end E_body )],
    EOF    => [qw( S_html S_head S_body !non_final_end E_body E_html)]
);


# Make sure the last resort defaults are always defined
for my $required_rubies_desc (qw( !start_tag !end_tag !non_element )) {
    $RUBY_CONFIG{$required_rubies_desc} //= [];
}

DESC: for my $rubies_desc (keys %RUBY_CONFIG) {
    my $candidates = $RUBY_CONFIG{$rubies_desc};
    next DESC if '!non_final_end' ~~ $candidates;
    $RUBY_CONFIG{$rubies_desc} = [@{$candidates}, '!non_final_end'];
}

1;
