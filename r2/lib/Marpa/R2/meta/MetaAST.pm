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

package Marpa::R2::Internal::MetaAST;

use 5.010;
use strict;
use warnings;

use vars qw($VERSION $STRING_VERSION);
$VERSION        = '2.047_007';
$STRING_VERSION = $VERSION;
## no critic(BuiltinFunctions::ProhibitStringyEval)
$VERSION = eval $VERSION;
## use critic

sub new {
    my ( $class, $p_rules_source ) = @_;

    my $meta_recce = Marpa::R2::Internal::Scanless::meta_recce();
    my $meta_grammar = $meta_recce->[Marpa::R2::Inner::Scanless::R::GRAMMAR];
    state $mask_by_rule_id =
        $meta_grammar->[Marpa::R2::Inner::Scanless::G::MASK_BY_RULE_ID];
    $meta_recce->read($p_rules_source);

    my $thick_meta_g1_grammar = $meta_grammar->[Marpa::R2::Inner::Scanless::G::THICK_G1_GRAMMAR];
    my $meta_g1_tracer       = $thick_meta_g1_grammar->tracer();
    my $thin_meta_g1_grammar = $thick_meta_g1_grammar->thin();
    my $thick_meta_g1_recce = $meta_recce->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];
    my $thick_g1_recce = $meta_recce->[Marpa::R2::Inner::Scanless::R::THICK_G1_RECCE];

    my $value_ref = $meta_recce->value();
    Marpa::R2::exception("Parse of BNF/Scanless source failed") if not defined $value_ref;
    return bless ${$value_ref}, $class;

}

sub ast_to_hash {
    my ($ast, $bnf_source) = @_;
    my $parse = bless {
        p_source => $bnf_source,
        g0_rules => [],
        g1_rules => []
    };
    my $new_ast = $ast->dwim_evaluate($parse);
    return $parse, $new_ast;
}

sub dwim_evaluate {
    my ( $value, $parse ) = @_;
    return $value if not defined $value;
    if ( Scalar::Util::blessed($value) ) {
        return $value->evaluate($parse) if $value->can('evaluate');
        return bless [ map { dwim_evaluate( $_, $parse ) } @{$value} ],
            ref $value
            if Scalar::Util::reftype($value) eq 'ARRAY';
        return $value;
    } ## end if ( Scalar::Util::blessed($value) )
    return [ map { dwim_evaluate( $_, $parse ) } @{$value} ]
        if ref $value eq 'ARRAY';
    return $value;
} ## end sub dwim_evaluate

package Marpa::R2::Internal::MetaAST::Symbol;

use English qw( -no_match_vars );

sub new {
    my ( $class, $name ) = @_;
    return bless { name => ( '' . $name ), mask => [ 1 ] }, $class;
}
sub is_symbol { return 1 }
sub name      { return shift->{name} }
sub names     { return [ shift->{name} ] }
sub mask      { return shift->{mask} }
sub mask_set      { my ( $self, $mask ) = @_; $mask //= 1; $self->{mask} = [ $mask ] }

# Return the character class symbol name,
# after ensuring everything is set up properly
sub assign_symbol_by_char_class {
    my ( $self, $char_class ) = @_;

    # character class symbol name always start with TWO left square brackets
    my $symbol_name = '[' . $char_class . ']';
    $self->{character_classes} //= {};
    my $cc_hash = $self->{character_classes};
    my ( undef, $symbol ) = $cc_hash->{$symbol_name};
    if ( not defined $symbol ) {
        my $regex;
        if ( not defined eval { $regex = qr/$char_class/xms; 1; } ) {
            Carp::croak( 'Bad Character class: ',
                $char_class, "\n", 'Perl said ', $EVAL_ERROR );
        }
        $symbol = Marpa::R2::Internal::MetaAST::Symbol->new($symbol_name);
        $cc_hash->{$symbol_name} = [ $regex, $symbol ];
    } ## end if ( not defined $symbol )
    return $symbol;
} ## end sub assign_symbol_by_char_class

package Marpa::R2::Internal::MetaAST::Symbol_List;

sub new {
    my ( $class, @lists ) = @_;
    my $self = {};
    $self->{names} = [ map { @{ $_->names() } } @lists ];
    $self->{mask}  = [ map { @{ $_->mask() } } @lists ];
    return bless $self, $class;
} ## end sub new
sub is_symbol { return 0 }
sub name {
    my ($self) = @_;
    my $names = $self->{names};
    Marpa::R2::exception( "list->name() on symbol list of length ",
        scalar @{$names} )
        if scalar @{$names} != 1;
    return $self->{names}->[0];
} ## end sub name
sub names { return shift->{names} }
sub mask { return shift->{mask} }
sub mask_set {
    my ( $self, $mask ) = @_;
    $self->{mask} = [ map { $mask } @{ $self->{mask} } ];
}

package Marpa::R2::Internal::MetaAST::Proto_Alternative;

# This class is for pieces of RHS alternatives, as they are
# being constructed

our $PROTO_ALTERNATIVE;
BEGIN { $PROTO_ALTERNATIVE = __PACKAGE__; }

sub combine {
    my ( $class, @hashes ) = @_;
    my $self = bless {}, $class;
    for my $hash_to_add (@hashes) {
        for my $key ( keys %{$hash_to_add} ) {
            Marpa::R2::exception(
                'duplicate key in ',
                $PROTO_ALTERNATIVE,
                "::combine(): $key"
            ) if exists $self->{$key};

            $self->{$key} = $hash_to_add->{$key};
        } ## end for my $key ( keys %{$hash_to_add} )
    } ## end for my $hash_to_add (@hashes)
    return $self;
} ## end sub combine

sub Marpa::R2::Internal::MetaAST::bless_hash_rule {
    my ( $parse, $hash_rule, $blessing, $original_lhs ) = @_;
    my $grammar_level = $Marpa::R2::Internal::GRAMMAR_LEVEL;
    return if $grammar_level == 0;
    $blessing //= $parse->{default_adverbs}->[$grammar_level]->{bless};
    return if not defined $blessing;
    $DB::single = 1;
    FIND_BLESSING: {
        last FIND_BLESSING if $blessing =~ /\A [\w] /xms;
        return if $blessing eq '::undef';
        # Rule may be half-formed, but assume with have lhs
        my $lhs = $hash_rule->{lhs};
        if ( $blessing eq '::lhs' ) {
            $blessing = $original_lhs;
            if ( $blessing =~ / [^ [:alnum:]] /xms ) {
                Marpa::R2::exception(
                    qq{"::lhs" blessing only allowed if LHS is whitespace and alphanumerics\n},
                    qq{   LHS was <$original_lhs>\n}
                );
            } ## end if ( $blessing =~ / [^ [:alnum:]] /xms )
            $blessing =~ s/[ ]/_/gxms;
            last FIND_BLESSING;
        } ## end if ( $blessing eq '::lhs' )
        Marpa::R2::exception(
            qq{Unknown blessing "$blessing"\n}
        );
    } ## end FIND_BLESSING:
    $hash_rule->{bless} = $blessing;
    return 1;
} ## end sub bless_hash_rule

sub Marpa::R2::Internal::MetaAST_Nodes::action_name::name {
    my ($self) = @_;
    return $self->[2];
}

sub Marpa::R2::Internal::MetaAST_Nodes::bare_name::name { return $_[0]->[2] }

sub Marpa::R2::Internal::MetaAST_Nodes::array_descriptor::name {
    return $_[0]->[2];
}

sub Marpa::R2::Internal::MetaAST_Nodes::reserved_blessing_name::name {
    return $_[0]->[2];
}

sub Marpa::R2::Internal::MetaAST_Nodes::blessing_name::name {
    my ($self) = @_;
    return $self->[2];
}

sub Marpa::R2::Internal::MetaAST_Nodes::standard_name::name {
    return $_[0]->[2];
}

sub Marpa::R2::Internal::MetaAST_Nodes::lhs::name {
    my ($values, $parse) = @_;
    my (undef, undef, $symbol) = @{$values};
    return $symbol->name();
}

# After development, delete this
sub Marpa::R2::Internal::MetaAST_Nodes::lhs::evaluate {
    my ($values, $parse) = @_;
    return $values->name();
}

sub Marpa::R2::Internal::MetaAST_Nodes::op_declare::op {
    my ($values) = @_;
    return $values->[2]->op();
}

sub Marpa::R2::Internal::MetaAST_Nodes::op_declare_match::op {
    my ($values) = @_;
    return $values->[2];
}

sub Marpa::R2::Internal::MetaAST_Nodes::op_declare_bnf::op {
    my ($values) = @_;
    return $values->[2];
}

sub Marpa::R2::Internal::MetaAST_Nodes::bracketed_name::name {
    my ($values) = @_;
    my (undef, undef, $bracketed_name) = @{$values};

    # normalize whitespace
    $bracketed_name =~ s/\A [<] \s*//xms;
    $bracketed_name =~ s/ \s* [>] \z//xms;
    $bracketed_name =~ s/ \s+ / /gxms;
    return $bracketed_name;
} ## end sub evaluate

sub Marpa::R2::Internal::MetaAST_Nodes::parenthesized_rhs_primary_list::evaluate {
    my ( $data, $parse ) = @_;
    my (undef, undef, @values) = @{$data};
    my @symbol_lists = map { $_->evaluate($parse); } @values;
    my $flattened_list = Marpa::R2::Internal::MetaAST::Symbol_List->new(@symbol_lists);
    $flattened_list->mask_set(0);
    return $flattened_list;
}

sub Marpa::R2::Internal::MetaAST_Nodes::rhs::evaluate {
    my ( $data, $parse ) = @_;
    my @symbol_lists = map { $_->evaluate($parse) } @{$data};
    my $flattened_list =
        Marpa::R2::Internal::MetaAST::Symbol_List->new(@symbol_lists);
    return bless {
        rhs  => $flattened_list->names(),
        mask => $flattened_list->mask()
        },
        $PROTO_ALTERNATIVE;
} ## end sub Marpa::R2::Internal::MetaAST_Nodes::rhs::evaluate

sub Marpa::R2::Internal::MetaAST_Nodes::rhs_primary::evaluate {
    my ( $data, $parse ) = @_;
    my (undef, undef, @values) = @{$data};
    my @symbol_lists = map { $_->evaluate($parse) } @values;
    return Marpa::R2::Internal::MetaAST::Symbol_List->new(@symbol_lists);
}

sub Marpa::R2::Internal::MetaAST_Nodes::rhs_primary_list::evaluate {
    my ( $data, $parse ) = @_;
    my (undef, undef, @values) = @{$data};
    my @symbol_lists = map { $_->evaluate($parse) } @values;
    return Marpa::R2::Internal::MetaAST::Symbol_List->new(@symbol_lists);
}

package Marpa::R2::Internal::MetaAST_Nodes::action;

sub evaluate {
    my ( $values, $parse ) = @_;
    my ( undef, undef, $child ) = @{$values};
    return bless { action => $child->name($parse) }, $PROTO_ALTERNATIVE;
}

package Marpa::R2::Internal::MetaAST_Nodes::blessing;

sub evaluate {
    my ($values) = @_;
    my ( undef, undef, $child ) = @{$values};
    return bless { bless => $child->name() }, $PROTO_ALTERNATIVE;
}

package Marpa::R2::Internal::MetaAST_Nodes::right_association;

sub evaluate {
    my ($values) = @_;
    return bless { assoc => 'R' }, $PROTO_ALTERNATIVE;
}

package Marpa::R2::Internal::MetaAST_Nodes::left_association;

sub evaluate {
    my ($values) = @_;
    return bless { assoc => 'L' }, $PROTO_ALTERNATIVE;
}

package Marpa::R2::Internal::MetaAST_Nodes::group_association;

sub evaluate {
    my ($values) = @_;
    return bless { assoc => 'G' }, $PROTO_ALTERNATIVE;
}

package Marpa::R2::Internal::MetaAST_Nodes::proper_specification;

sub evaluate {
    my ($values) = @_;
    my $child = $values->[2];
    return bless { proper => $child->value() }, $PROTO_ALTERNATIVE;
} ## end sub evaluate

sub Marpa::R2::Internal::MetaAST_Nodes::boolean::value {
   return $_[0]->[2];
}

package Marpa::R2::Internal::MetaAST_Nodes::separator_specification;

sub evaluate {
    my ( $values, $parse ) = @_;
    my $child = $values->[2];
    return bless { separator => $child->name($parse) },
        $PROTO_ALTERNATIVE;
} ## end sub evaluate

package Marpa::R2::Internal::MetaAST_Nodes::adverb_item;

sub evaluate {
    my ( $values, $parse ) = @_;
    my $child = $values->[2]->evaluate($parse);
    return bless $child, $PROTO_ALTERNATIVE;
} ## end sub evaluate

package Marpa::R2::Internal::MetaAST_Nodes::default_rule;

sub evaluate {
    my ( $values, $parse ) = @_;
    my ( undef, undef, undef, $op_declare, $unevaluated_adverb_list ) =
        @{$values};
    my $grammar_level = $op_declare->op() eq q{::=} ? 1 : 0;
    my $adverb_list = $unevaluated_adverb_list->evaluate();

    # A default rule clears the previous default
    my %default_adverbs = ();
    $parse->{default_adverbs}->[$grammar_level] = \%default_adverbs;

    ADVERB: for my $key ( keys %{$adverb_list} ) {
        my $value = $adverb_list->{$key};
        if ( $key eq 'action' ) {
            $default_adverbs{$key} = $value->name();
            next ADVERB;
        }
        if ( $key eq 'bless' ) {
            $default_adverbs{$key} = $value->name();
            next ADVERB;
        }
        Marpa::R2::exception(qq{"$key" adverb not allowed in default rule"});
    } ## end ADVERB: for my $key ( keys %{$adverb_list} )
    return undef;
} ## end sub evaluate

package Marpa::R2::Internal::MetaAST_Nodes::lexeme_rule;

sub evaluate {
    my ( $values, $parse ) = @_;
    my ( $start, $end, undef, $op_declare, $unevaluated_adverb_list ) =
        @{$values};
    Marpa::R2::exception( "lexeme rule not allowed in G0\n",
        "  Rule was ", $parse->positions_to_string( $start, $end ) )
        if $op_declare->op() ne q{::=};
    my $adverb_list = $unevaluated_adverb_list->evaluate();

    # A default rule clears the previous default
    $parse->{default_lexeme_adverbs} = {};

    ADVERB: for my $key ( keys %{$adverb_list} ) {
        my $value = $adverb_list->{$key};
        if ( $key eq 'action' ) {
            $parse->{default_lexeme_adverbs}->{$key} = $value;
            next ADVERB;
        }
        if ( $key eq 'bless' ) {
            $parse->{default_lexeme_adverbs}->{$key} = $value;
            next ADVERB;
        }
        Marpa::R2::exception(qq{"$key" adverb not allowed in default rule"});
    } ## end ADVERB: for my $key ( keys %{$adverb_list} )
    return undef;
} ## end sub evaluate

sub Marpa::R2::Internal::MetaAST_Nodes::discard_rule::evaluate {
    my ( $values, $parse ) = @_;
    my ( $start, $end, $symbol ) = @{$values};
    local $Marpa::R2::Internal::GRAMMAR_LEVEL = 0;
    push @{ $parse->{g0_rules} },
        { lhs => '[:discard]', rhs => $symbol->names($parse) };
    return undef;
} ## end sub Marpa::R2::Internal::MetaAST_Nodes::discard_rule::evaluate

sub Marpa::R2::Internal::MetaAST_Nodes::quantified_rule::evaluate {
    my ( $values, $parse ) = @_;
    my ( undef, undef, $lhs, $op_declare, $rhs, $quantifier, $proto_adverb_list ) =
        @{$values};
    my $grammar_level = $op_declare->op() eq q{::=} ? 1 : 0;
    local $Marpa::R2::Internal::GRAMMAR_LEVEL = $grammar_level;

    my $adverb_list = $proto_adverb_list->evaluate($parse);
    my $default_adverbs = $parse->{default_adverbs}->[$grammar_level];

    # Some properties of the sequence rule will not be altered
    # no matter how complicated this gets
    my %sequence_rule = (
        rhs => [ $rhs->name() ],
        min => ( $quantifier eq q{+} ? 1 : 0 )
    );

    my @rules = ( \%sequence_rule );

    my $original_separator = $adverb_list->{separator};

    # mask not needed
    my $lhs_name       = $lhs->name();
    $sequence_rule{lhs}       = $lhs_name;
    $sequence_rule{separator} = $original_separator
        if defined $original_separator;
    my $proper = $adverb_list->{proper};
    $sequence_rule{proper} = $proper if defined $proper;

    my $action = $adverb_list->{action} // $default_adverbs->{action};
    if ( defined $action ) {
        Marpa::R2::exception(
            'actions not allowed in lexical rules (rules LHS was "',
            $lhs, '")' )
            if $grammar_level <= 0;
        $sequence_rule{action} = $action;
    } ## end if ( defined $action )

    my $blessing = $adverb_list->{bless};
    if ( defined $blessing
        and $grammar_level <= 0 )
    {
        Marpa::R2::exception(
            'bless option not allowed in lexical rules (rules LHS was "',
            $lhs, '")' );
    } ## end if ( defined $blessing and $grammar_level <= 0 )
    $parse->bless_hash_rule( \%sequence_rule, $blessing, $lhs_name );

    if ( $grammar_level > 0 ) {
        push @{ $parse->{g1_rules} }, @rules;
    }
    else {
        push @{ $parse->{g0_rules} }, @rules;
    }
    return 'quantified rule consumed';

} ## end sub Marpa::R2::Internal::MetaAST_Nodes::quantified_rule::evaluate

package Marpa::R2::Internal::MetaAST_Nodes::priority_rule;

sub evaluate {
    my ( $values, $parse ) = @_;
    my ( $start, $end, $lhs, $op_declare, $priorities ) = @{$values};
    my $grammar_level = $op_declare->op() eq q{::=} ? 1 : 0;
    local $Marpa::R2::Internal::GRAMMAR_LEVEL = $grammar_level;
    return bless [
        lhs        => $lhs->evaluate(),
        priorities => [ map { $_->evaluate($parse) } @{$priorities} ]
        ],
        __PACKAGE__;
}

package Marpa::R2::Internal::MetaAST_Nodes::alternatives;

sub evaluate {
    my ( $values, $parse ) = @_;
    return
        bless [
        map { Marpa::R2::Internal::MetaAST::dwim_evaluate( $_, $parse ) }
            @{$values} ],
        __PACKAGE__;
} ## end sub evaluate

package Marpa::R2::Internal::MetaAST_Nodes::alternative;

sub evaluate {
    my ( $values, $parse ) = @_;
    my ( undef, undef, $rhs, $adverbs ) = @{$values};
    return Marpa::R2::Internal::MetaAST::Proto_Alternative->combine( map { $_->evaluate() } $rhs, $adverbs);
} ## end sub evaluate

sub Marpa::R2::Internal::MetaAST_Nodes::single_symbol::names {
    my ( $values, $parse ) = @_;
    my ( undef, undef, $symbol ) = @{$values};
    return $symbol->names($parse);
}

sub Marpa::R2::Internal::MetaAST_Nodes::single_symbol::name {
    my ( $values, $parse ) = @_;
    my ( undef, undef, $symbol ) = @{$values};
    return $symbol->name($parse);
}

sub Marpa::R2::Internal::MetaAST_Nodes::single_symbol::evaluate {
    my ( $values, $parse ) = @_;
    my ( undef, undef, $symbol ) = @{$values};
    return Marpa::R2::Internal::MetaAST::Symbol->new($symbol->name($parse));
}

sub Marpa::R2::Internal::MetaAST_Nodes::Symbol::evaluate {
    my ( $values, $parse ) = @_;
    my ( undef, undef, $symbol ) = @{$values};
    return $symbol->evaluate($parse);
}

sub Marpa::R2::Internal::MetaAST_Nodes::symbol::name { my ($self) = @_; return $self->[2]->name(); }
sub Marpa::R2::Internal::MetaAST_Nodes::symbol::names { my ($self) = @_; return $self->[2]->names(); }
sub Marpa::R2::Internal::MetaAST_Nodes::symbol_name::evaluate {
my ($self) = @_; return $self->[2]; }
sub Marpa::R2::Internal::MetaAST_Nodes::symbol_name::name {
my ($self, $parse) = @_;
return $self->evaluate($parse)->name($parse); }
sub Marpa::R2::Internal::MetaAST_Nodes::symbol_name::names {
    my ($self, $parse) = @_;
   return [$self->name($parse)];
}

package Marpa::R2::Internal::MetaAST_Nodes::adverb_list;

sub evaluate {
    my ( $values, $parse ) = @_;
    my (@adverb_items) = map { $_->evaluate($parse) } @{$values};
    return Marpa::R2::Internal::MetaAST::Proto_Alternative->combine(
        @adverb_items);
} ## end sub evaluate

sub Marpa::R2::Internal::MetaAST_Nodes::character_class::name {
    my ( $self, $parse ) = @_;
    return $self->evaluate($parse)->name($parse);
}

sub Marpa::R2::Internal::MetaAST_Nodes::character_class::evaluate {
    my ( $values, $parse ) = @_;
    my $symbol =
        Marpa::R2::Internal::MetaAST::Symbol::assign_symbol_by_char_class(
        $parse, $values->[2] );
    return $symbol if $Marpa::R2::Internal::GRAMMAR_LEVEL <= 0;
    my $lexical_lhs_index = $parse->{lexical_lhs_index}++;
    my $lexical_lhs       = "[Lex-$lexical_lhs_index]";
    my %lexical_rule      = (
        lhs  => $lexical_lhs,
        rhs  => $symbol->names(),
        mask => $symbol->mask(),
    );
    push @{ $parse->{g0_rules} }, \%lexical_rule;
    my $g1_symbol = Marpa::R2::Internal::MetaAST::Symbol->new($lexical_lhs);
    return $g1_symbol;
} ## end sub Marpa::R2::Internal::MetaAST_Nodes::character_class::evaluate

sub Marpa::R2::Internal::MetaAST_Nodes::single_quoted_string::evaluate
{
    my ( $values, $parse ) = @_;
    my ( undef, undef, $string ) = @{$values};
    my @symbols = ();
    for my $char_class (
        map { '[' . ( quotemeta $_ ) . ']' } split //xms,
        substr $string,
        1, -1
        )
    {
        my $symbol =
            Marpa::R2::Internal::MetaAST::Symbol::assign_symbol_by_char_class(
            $parse, $char_class );
        push @symbols, $symbol;
    } ## end for my $char_class ( map { '[' . ( quotemeta $_ ) . ']'...})
    my $list = Marpa::R2::Internal::MetaAST::Symbol_List->new(@symbols);
    return $list if $Marpa::R2::Internal::GRAMMAR_LEVEL <= 0;
    my $lexical_lhs_index = $parse->{lexical_lhs_index}++;
    my $lexical_lhs       = "[Lex-$lexical_lhs_index]";
    my %lexical_rule      = (
        lhs  => $lexical_lhs,
        rhs  => $list->names(),
        mask => $list->mask(),
    );
    push @{ $parse->{g0_rules} }, \%lexical_rule;
    my $g1_symbol = Marpa::R2::Internal::MetaAST::Symbol->new($lexical_lhs);
    return $g1_symbol;
} ## end sub evaluate

1;

# vim: expandtab shiftwidth=4:
