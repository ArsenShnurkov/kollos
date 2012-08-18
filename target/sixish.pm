use 5.010;
use strict;
use warnings;

use Marpa::R2::Thin::Trace;

our $sixish_answer_shown;

my $op_alternative      = Marpa::R2::Thin::op('alternative');
my $op_alternative_args = Marpa::R2::Thin::op('alternative;args');
my $op_alternative_args_ignore =
    Marpa::R2::Thin::op('alternative;args;ignore');
my $op_alternative_ignore = Marpa::R2::Thin::op('alternative;ignore');
my $op_earleme_complete   = Marpa::R2::Thin::op('earleme_complete');

my $paren_grammar = q{'(' <~~>* ')'};

sub sixish_new {
    my $sixish_grammar  = Marpa::R2::Thin::G->new( { if => 1 } );
    my $tracer          = Marpa::R2::Thin::Trace->new($sixish_grammar);
    my %char_to_symbol  = ();
    my @regex_to_symbol = ();

    $char_to_symbol{'*'}  = $tracer->symbol_new('star');
    $char_to_symbol{'<'}  = $tracer->symbol_new('langle');
    $char_to_symbol{'>'}  = $tracer->symbol_new('rangle');
    $char_to_symbol{q{'}} = $tracer->symbol_new('single_quote');
    $char_to_symbol{'~'}  = $tracer->symbol_new('tilde');

    my $s_ws_char = $tracer->symbol_new('ws_char');
    push @regex_to_symbol, [ qr/\s/xms, $s_ws_char ];
    my $s_single_quoted_char = $tracer->symbol_new('single_quoted_char');
    push @regex_to_symbol, [ qr/[^\\']/xms, $s_single_quoted_char ];

    $tracer->symbol_new('atom');
    $tracer->symbol_new('concatenation');
    $tracer->symbol_new('single_quoted_char_seq');
    $tracer->symbol_new('opt_ws');
    $tracer->symbol_new('quantified_atom');
    $tracer->symbol_new('quantifier');
    $tracer->symbol_new('quoted_literal');
    $tracer->symbol_new('self');
    $tracer->symbol_new('start');

    $tracer->rule_new('start ::= concatenation');
    $tracer->rule_new('concatenation ::=');
    $tracer->rule_new(
        'concatenation ::= concatenation opt_ws quantified_atom');
    $tracer->rule_new('opt_ws ::= ');
    $tracer->rule_new('opt_ws ::= opt_ws ws_char');
    $tracer->rule_new('quantified_atom ::= atom opt_ws quantifier');
    $tracer->rule_new('quantified_atom ::= atom');
    $tracer->rule_new('atom ::= quoted_literal');
    $tracer->rule_new(
        'quoted_literal ::= single_quote single_quoted_char_seq single_quote');
    $sixish_grammar->sequence_new(
        $tracer->symbol_by_name('single_quoted_char_seq'),
        $tracer->symbol_by_name('single_quoted_char'),
        { min => 0 }
    );
    $tracer->rule_new('atom ::= self');
    $sixish_grammar->rule_new( $tracer->symbol_by_name('self'),
        [ map { $char_to_symbol{$_} } split //xms, '<~~>' ] );
    $tracer->rule_new('quantifier ::= star');

    $sixish_grammar->start_symbol_set( $tracer->symbol_by_name('start'), );
    $sixish_grammar->precompute();
    return $tracer, $sixish_grammar, \%char_to_symbol, \@regex_to_symbol;
} ## end sub sixish_new

my ( $sixish_tracer, $sixish_grammar, $sixish_char_to_symbol, $sixish_regex_to_symbol ) =
    sixish_new();

sub sixish_child_new {
    my ($child_source) = @_;
    my $sixish_recce = Marpa::R2::Thin::R->new($sixish_grammar);
    $sixish_recce->start_input();
    while ( my ( $char, $symbol ) = each %{$sixish_char_to_symbol} ) {
        my @alternatives = ($symbol);
        push @alternatives,
            map { $_->[1] }
            grep { $char =~ $_->[0] } @{$sixish_regex_to_symbol};
        $sixish_recce->char_register( ord($char),
            ( map { ( $op_alternative_ignore, $_ ) } @alternatives ),
            $op_earleme_complete );
    } ## end while ( my ( $char, $symbol ) = each %{$sixish_char_to_symbol...})
    $sixish_recce->input_string_set($child_source);
    READ: while (1) {
        my $event_count = $sixish_recce->input_string_read();
        last READ if not defined $event_count;
        if ( $event_count == -2 ) {
            my $char = substr $child_source,
                $sixish_recce->input_string_pos(), 1;
            my @alternatives =
                map { $_->[1] } @{$sixish_regex_to_symbol};
            $sixish_recce->char_register( ord($char),
                ( map { ( $op_alternative_ignore, $_ ) } @alternatives ),
                $op_earleme_complete );
            next READ;
        } ## end if ( $event_count == -2 )

        die "input_string_read(): $event_count, char=",
            ( substr $child_source, $sixish_recce->input_string_pos(), 1 );
    } ## end READ: while (1)

    my $latest_earley_set_ID = $sixish_recce->latest_earley_set();
    my $bocage = Marpa::R2::Thin::B->new( $sixish_recce, $latest_earley_set_ID );
    my $order  = Marpa::R2::Thin::O->new($bocage);
    my $tree   = Marpa::R2::Thin::T->new($order);

my $valuator = Marpa::R2::Thin::V->new($tree);
for my $rule_id (0 .. $sixish_grammar->rule_count() - 1) {
        $valuator->rule_is_valued_set( $rule_id,     1 );
}
        my @stack = ();
        STEP: while ( 1 ) {
            my ( $type, @step_data ) = $valuator->step();
            last STEP if not defined $type;
            if ( $type eq 'MARPA_STEP_TOKEN' ) {
                my ( undef, $token_value_ix, $arg_n ) = @step_data;

say STDERR join q{ }, $token_value_ix, $arg_n ;

                next STEP;
            }
            if ( $type eq 'MARPA_STEP_RULE' ) {
                my ( $rule_id, $arg_0, $arg_n ) = @step_data;

say STDERR join q{ }, $rule_id, $arg_0, $arg_n ;

                    next STEP;
                die "Unknown rule $rule_id";
            } ## end if ( $type eq 'MARPA_STEP_RULE' )
            die "Unexpected step type: $type";
        } ## end while ( my ( $type, @step_data ) = $valuator->step() )
        push @actual_values, $stack[0];

} ## end sub sixish_child_new

sub pre_sixish_subgrammar {
    my $child_grammar = Marpa::R2::Thin::G->new( { if => 1 } );
    my %char_to_symbol = ();
    $char_to_symbol{'('} = $child_grammar->symbol_new();
    $char_to_symbol{')'} = $child_grammar->symbol_new();
    my $s_target                  = $child_grammar->symbol_new();
    my $s_balanced_paren_sequence = $child_grammar->symbol_new();
    my $s_balanced_parens         = $child_grammar->symbol_new();
    my $target_rule =
        $child_grammar->rule_new( $s_target, [$s_balanced_parens] );
    $child_grammar->sequence_new( $s_balanced_paren_sequence,
        $s_balanced_parens, { min => 0 } );
    $child_grammar->rule_new(
        $s_balanced_parens,
        [   $char_to_symbol{'('}, $s_balanced_paren_sequence,
            $char_to_symbol{')'},
        ]
    );
    return [ $target_rule, $child_grammar, \%char_to_symbol ];
} ## end sub pre_sixish_child

sub do_sixish {
    my ( $s ) = @_;
    sixish_child_new($paren_grammar);
    my $child_grammar = pre_sixish_subgrammar( $paren_grammar );
    my ( $start_of_match, $end_of_match ) = sixish_find( $child_grammar, $s );
    my $value = substr $s, $start_of_match, $end_of_match - $start_of_match;
    return 0 if $sixish_answer_shown;
    $sixish_answer_shown = $value;
    say qq{sixish: "$value" at $start_of_match-$end_of_match};
    return 0;
} ## end sub do_sixish

sub sixish_find {
    my ( $child_grammar_data, $s ) = @_;
    my ( $target_rule, $child_grammar, $char_to_symbol ) = @{$child_grammar_data};

    my $s_target            = $child_grammar->rule_lhs($target_rule);
    my $s_start             = $child_grammar->symbol_new();
    my $s_target_end_marker = $child_grammar->symbol_new();
    my $s_prefix            = $child_grammar->symbol_new();
    my $s_prefix_char       = $child_grammar->symbol_new();
    $child_grammar->start_symbol_set($s_start);
    $child_grammar->rule_new( $s_start,
        [ $s_prefix, $s_target, $s_target_end_marker ] );
    $child_grammar->sequence_new( $s_prefix, $s_prefix_char, { min => 0 } );

    $child_grammar->precompute();

    my $child_recce = Marpa::R2::Thin::R->new($child_grammar);
    $child_recce->start_input();
    $child_recce->expected_symbol_event_set( $s_target_end_marker, 1 );

    while ( my ( $char, $symbol ) = each %{$char_to_symbol} ) {
        $child_recce->char_register(
            ord($char), $op_alternative_ignore, $symbol,
            $op_alternative_ignore, $s_prefix_char, $op_earleme_complete
        );
    } ## end while ( my ( $char, $symbol ) = each %char_to_symbol )

    my $string_length = length $s;
    my $end_of_match_earleme;

    $child_recce->input_string_set($s);
    my $event_count = $child_recce->input_string_read();
    if ( not $event_count ) {
        say "No balanced parens";
        return 0;
    }
    if ( $event_count < 0 ) {
        die "Token rejected";
    }

    if (grep { $_ eq 'MARPA_EVENT_SYMBOL_EXPECTED' }
        map { ; ( $child_grammar->event($_) )[0] } ( 0 .. $event_count - 1 )
        )
    {

        $end_of_match_earleme = $child_recce->input_string_pos();
    } ## end if ( grep { $_ eq 'MARPA_EVENT_SYMBOL_EXPECTED' } map...)

    # For arbitrary targets,
    # Add a check that we don't already expect the end_marker
    # at location 0? This will detect zero-length targets?

    if ( not defined $end_of_match_earleme ) {
        say "No balanced parens";
        return 0;
    }

    my $start_of_match_earleme = $end_of_match_earleme - 1;

    $child_recce->progress_report_start($end_of_match_earleme);
    ITEM: while (1) {
        my ( $rule_id, $dot_position, $item_origin ) =
            $child_recce->progress_item();
        last ITEM if not defined $rule_id;
        next ITEM if $dot_position >= 0;
        next ITEM if $rule_id != $target_rule;
        $start_of_match_earleme = $item_origin
            if $item_origin < $start_of_match_earleme;
    } ## end ITEM: while (1)

    # Start the recognizer over again
    $child_recce = Marpa::R2::Thin::R->new($child_grammar);
    $child_recce->start_input();

    while ( my ( $char, $symbol ) = each %{$char_to_symbol} ) {
        $child_recce->char_register(
            ord($char), $op_alternative_ignore, $symbol,
            $op_alternative_ignore, $s_prefix_char, $op_earleme_complete
        );
    } ## end while ( my ( $char, $symbol ) = each %char_to_symbol )

    $child_recce->input_string_set( substr $s, 0, $start_of_match_earleme );
    die if defined $child_recce->input_string_read();

    while ( my ( $char, $symbol ) = each %{$char_to_symbol} ) {
        $child_recce->char_register( ord($char), $op_alternative, $symbol,
            $op_earleme_complete );
    }

    $child_recce->input_string_set( substr $s, $start_of_match_earleme );
    $child_recce->expected_symbol_event_set( $s_target_end_marker, 1 );

    READ: while (1) {
        my $event_count = $child_recce->input_string_read();
        last READ if not defined $event_count;
        last READ if $event_count <= 0;
        my $exhausted = 0;
        EVENT:
        for my $event_type ( map { ( $child_grammar->event($_) )[0] }
            0 .. $event_count - 1 )
        {
            if ( $event_type eq 'MARPA_EVENT_SYMBOL_EXPECTED' ) {
                $end_of_match_earleme = $start_of_match_earleme
                    + $child_recce->input_string_pos();
                next EVENT;
            }
            if ( $event_type eq 'MARPA_EVENT_EXHAUSTED' ) {
                $exhausted = 1;
                next EVENT;
            }
            die "Unknown event: $event_type";
        } ## end for my $event_type ( map { ( $child_grammar->event($_...))})
        last READ if $exhausted;
    } ## end READ: while (1)

    $start_of_match_earleme = $end_of_match_earleme;
    $child_recce->progress_report_start($end_of_match_earleme);
    ITEM: while (1) {
        my ( $rule_id, $dot_position, $item_origin ) =
            $child_recce->progress_item();
        last ITEM if not defined $rule_id;
        next ITEM if $dot_position >= 0;
        next ITEM if $rule_id != $target_rule;
        $start_of_match_earleme = $item_origin
            if $item_origin < $start_of_match_earleme;
    } ## end ITEM: while (1)

    return ($start_of_match_earleme, $end_of_match_earleme);

} ## end sub sixish_find

1;
