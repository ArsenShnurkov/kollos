use 5.010;
use strict;
use warnings;

use Benchmark qw(timeit countit timestr);
use List::Util qw(min);
use Regexp::Common qw /balanced/;
use Getopt::Long;
my $example;
my $length = 1000;
my $string;
my $pp              = 0;
my $do_regex        = 0;
my $do_thin         = 0;
my $do_r2           = 0;
my $do_timing = 1;
my $iteration_count = -4;
my $getopt_result   = GetOptions(
    "length=i"  => \$length,
    "count=i"   => \$iteration_count,
    "example=s" => \$example,
    "string=s"  => \$string,
    "regex!"    => \$do_regex,
    "thin!"     => \$do_thin,
    "r2!"       => \$do_r2,
    "time!"       => \$do_timing,
);

{
    require Marpa::R2;
    'Marpa::R2'->VERSION(0.020000);
    say "Marpa::R2 ", $Marpa::R2::VERSION;
}

my $tchrist_regex = '(\\((?:[^()]++|(?-1))*+\\))';

my $s;

if ( defined $string ) {
    die "Bad string: $string" if not $string =~ /\A [()]+ \z/xms;
    say "Testing $string";
    $s = $string;
} ## end if ( defined $string )
else {

    $length += 0;
    if ( $length <= 0 ) {
        die "Bad length $length";
    }

    $example //= "final";
    CREATE_S: {
        my $s_balanced = '(()())((';
        if ( $example eq 'pos2_simple' ) {
            $s = '(' . '()' . ( '(' x ( $length - length $s_balanced ) );
            last CREATE_S;
        }
        if ( $example eq 'pos2' ) {
            $s = '('
                . $s_balanced
                . ( '(' x ( $length - length $s_balanced ) );
            last CREATE_S;
        } ## end if ( $example eq 'pos2' )
        if ( $example eq 'final' ) {
            $s = ( '(' x ( $length - length $s_balanced ) ) . $s_balanced;
            last CREATE_S;
        }
        die qq{Example "$example" not known};
    } ## end CREATE_S:

} ## end else [ if ( defined $string ) ]

sub concat {
    my (undef, @args) = @_;
    return join q{}, grep { defined } @args;
}
sub arg0 {
    my (undef, $arg0) = @_;
    return $arg0;
}

sub arg1 {
    my (undef, undef, $arg1) = @_;
    return $arg1;
}

my $marpa_answer_shown;
my $thin_answer_shown;
my $target_answer_shown;
my $regex_old_answer_shown;
my $regex_answer_shown;

my $grammar_args =
    {   start => 'S',
        rules => [
            [ S => [qw(prefix first_balanced endmark )], 'main::arg1' ],
            {   lhs    => 'S',
                rhs    => [qw(prefix first_balanced )],
                action => 'main::arg1'
            },
            { lhs => 'prefix',      rhs => [qw(prefix_char)], min => 0 },
            { lhs => 'prefix_char', rhs => [qw(xlparen)] },
            { lhs => 'prefix_char', rhs => [qw(rparen)] },
            { lhs => 'lparen',      rhs => [qw(xlparen)] },
            { lhs => 'lparen',      rhs => [qw(ilparen)] },
            {   lhs    => 'first_balanced',
                rhs    => [qw(xlparen balanced_sequence rparen)],
                action => 'main::arg0'
            },
            {   lhs => 'balanced',
                rhs => [qw(lparen balanced_sequence rparen)],
            },
            {   lhs => 'balanced_sequence',
                rhs => [qw(balanced)],
                min => 0,
            },
        ],
    };

sub thick_grammar_generate {
    my $grammar = Marpa::R2::Grammar->new($grammar_args);
    $grammar->set( { terminals => [qw(xlparen ilparen rparen endmark )] } );

    $grammar->precompute();
    return $grammar;
} ## end sub thick_grammar_generate

sub do_r2 {
    my ($s) = @_;

    my $grammar_args = {
        start => 'S',
        rules => [
            [ S => [qw(prefix first_balanced endmark )] ],
            {   lhs => 'S',
                rhs => [qw(prefix first_balanced )]
            },
            { lhs => 'prefix',      rhs => [qw(prefix_char)], min => 0 },
            { lhs => 'prefix_char', rhs => [qw(xlparen)] },
            { lhs => 'prefix_char', rhs => [qw(rparen)] },
            { lhs => 'lparen',      rhs => [qw(xlparen)] },
            { lhs => 'lparen',      rhs => [qw(ilparen)] },
            {   lhs => 'first_balanced',
                rhs => [qw(xlparen balanced_sequence rparen)],
            },
            {   lhs => 'balanced',
                rhs => [qw(lparen balanced_sequence rparen)],
            },
            {   lhs => 'balanced_sequence',
                rhs => [qw(balanced)],
                min => 0,
            },
        ],
    };

    my $grammar = Marpa::R2::Grammar->new($grammar_args);

    $grammar->precompute();

    my ($first_balanced_rule) =
        grep { ( $grammar->rule($_) )[0] eq 'first_balanced' }
        $grammar->rule_ids();

    my $recce         = Marpa::R2::Recognizer->new( { grammar => $grammar } );
    $recce->expected_symbol_event_set( 'endmark', 1 );

    my $location      = 0;
    my $string_length = length $s;
    my $end_of_match;

    # find the match which ends first -- the one which starts
    # first must start at or before it does
    CHAR: while ( $location < $string_length ) {
        my $value = substr $s, $location, 1;
	my $event_count;
        if ( $value eq '(' ) {

            # say "Adding xlparen at $location";
            $event_count = $recce->read( 'xlparen' );
        }
        else {
            # say "Adding rparen at $location";
            $event_count = $recce->read('rparen');
        }
	if ($event_count and grep { $_->[0] eq 'SYMBOL_EXPECTED' } @{$recce->events()}) {
	    $end_of_match = $location + 1;
	    last CHAR;
	}
        $location++;
    } ## end CHAR: while ( $location < $string_length )

    if ( not defined $end_of_match ) {
        say "No balanced parens";
        return 0;
    }

    CHAR: while ( ++$location < $string_length ) {
        my $value = substr $s, $location, 1;
        my $token = $value eq '(' ? 'ilparen' : 'rparen';

        # say "Adding $token at $location";
        my $event_count = $recce->read($token);
        last CHAR if not defined $event_count;
	if ($event_count and grep { $_->[0] eq 'SYMBOL_EXPECTED' } @{$recce->events()}) {
	    $end_of_match = $location + 1;
	}
    } ## end CHAR: while ( ++$location < $string_length )

    my $report = $recce->progress($end_of_match);

    # say Dumper($report);
    my $start_of_match = List::Util::min map { $_->[2] }
        grep { $_->[1] < 0 && $_->[0] == $first_balanced_rule } @{$report};
    my $value = substr $s, $start_of_match, $end_of_match - $start_of_match;
    return 0 if $marpa_answer_shown;
    $marpa_answer_shown = $value;
    say qq{marpa: "$value" at $start_of_match-$end_of_match};
    return 0;

} ## end sub do_r2e

sub do_regex_old {
    my ($s) = @_;
    my $answer =
          $s =~ /$RE{balanced}{-parens=>'()'}{-keep}/
        ? $1
        : 'no balanced parentheses';
    return 0 if $regex_old_answer_shown;
    $regex_old_answer_shown = $answer;
    say qq{regex_old answer: "$answer"};
    return 0;
} ## end sub do_regex

sub do_regex {
    my ($s) = @_;
    my $answer =
          $s =~ $tchrist_regex
        ? $1
        : 'no balanced parentheses';
    return 0 if $regex_answer_shown;
    $regex_answer_shown = $answer;
    say qq{regex: "$answer"};
    return 0;
} ## end sub do_regex

sub do_thin {
    my ($s) = @_;

    my $grammar = Marpa::R2::Grammar->new($grammar_args);

    my $thin_grammar        = Marpa::R2::Thin::G->new( { if => 1 } );
    my $s_xlparen           = $thin_grammar->symbol_new();
    my $s_ilparen           = $thin_grammar->symbol_new();
    my $s_rparen            = $thin_grammar->symbol_new();
    my $s_lparen            = $thin_grammar->symbol_new();
    my $s_endmark           = $thin_grammar->symbol_new();
    my $s_start             = $thin_grammar->symbol_new();
    my $s_prefix            = $thin_grammar->symbol_new();
    my $s_first_balanced    = $thin_grammar->symbol_new();
    my $s_prefix_char       = $thin_grammar->symbol_new();
    my $s_balanced_sequence = $thin_grammar->symbol_new();
    my $s_balanced          = $thin_grammar->symbol_new();
    $thin_grammar->start_symbol_set($s_start);
    $thin_grammar->rule_new( $s_start,
        [ $s_prefix, $s_first_balanced, $s_endmark ] );
    $thin_grammar->rule_new( $s_start, [ $s_prefix, $s_first_balanced ] );
    $thin_grammar->rule_new( $s_prefix_char, [$s_xlparen] );
    $thin_grammar->rule_new( $s_prefix_char, [$s_rparen] );
    $thin_grammar->rule_new( $s_lparen,      [$s_xlparen] );
    $thin_grammar->rule_new( $s_lparen,      [$s_ilparen] );
    my $first_balanced_rule =
        $thin_grammar->rule_new( $s_first_balanced,
        [ $s_xlparen, $s_balanced_sequence, $s_rparen ] );
    $thin_grammar->rule_new( $s_balanced,
        [ $s_lparen, $s_balanced_sequence, $s_rparen ] );
    $thin_grammar->sequence_new( $s_prefix,            $s_prefix_char, {min => 0} );
    $thin_grammar->sequence_new( $s_balanced_sequence, $s_balanced,    {min => 0} );

    $thin_grammar->precompute();

    my $thin_recce = Marpa::R2::Thin::R->new($thin_grammar);
    $thin_recce->start_input();
    $thin_recce->expected_symbol_event_set( $s_endmark, 1 );

    my $location      = 0;
    my $string_length = length $s;
    my $end_of_match;

    # find the match which ends first -- the one which starts
    # first must start at or before it does
    CHAR: while ( $location < $string_length ) {
        my $value = substr $s, $location, 1;
        my $event_count;
        if ( $value eq '(' ) {
            # say "Adding xlparen at $location";
	    $thin_recce->alternative($s_xlparen, 0, 1);
	    $event_count = $thin_recce->earleme_complete();
        }
        else {
            # say "Adding rparen at $location";
	    $thin_recce->alternative($s_rparen, 0, 1);
	    $event_count = $thin_recce->earleme_complete();
        }
        if ( $event_count
            and grep { $_ eq 'MARPA_EVENT_SYMBOL_EXPECTED' }
            map { ;($thin_grammar->event($_))[0] } ( 0 .. $event_count - 1 ) )
        {
            $end_of_match = $location + 1;
            last CHAR;
        } ## end if ( $event_count and grep { $_->[0] eq ...})
        $location++;
    } ## end CHAR: while ( $location < $string_length )

    if ( not defined $end_of_match ) {
        say "No balanced parens";
        return 0;
    }

    CHAR: while ( ++$location < $string_length ) {
        my $value = substr $s, $location, 1;
        my $token = $value eq '(' ? $s_ilparen : $s_rparen;

        # say "Adding $token at $location";
        last CHAR if not defined $thin_recce->alternative($token, 0, 1);
        my $event_count = $thin_recce->earleme_complete();
        if ( $event_count
            and grep { $_ eq 'MARPA_EVENT_SYMBOL_EXPECTED' }
            map { ;($thin_grammar->event($_))[0] } ( 0 .. $event_count - 1 ) )
        {
	    $end_of_match = $location + 1;
	}
    } ## end CHAR: while ( ++$location < $string_length )

    my $start_of_match = $end_of_match;
    $thin_recce->progress_report_start($end_of_match);
    ITEM: while (1) {
        my ($rule_id, $dot_position, $item_origin) = $thin_recce->progress_item();
        last ITEM if not defined $rule_id;
	next ITEM if $dot_position >= 0;
        next ITEM if $rule_id != $first_balanced_rule;
	$start_of_match = $item_origin if $item_origin < $start_of_match;
    }

    my $value = substr $s, $start_of_match, $end_of_match - $start_of_match;
    return 0 if $thin_answer_shown;
    $thin_answer_shown = $value;
    say qq{thin: "$value" at $start_of_match-$end_of_match};
    return 0;

} ## end sub do_thin

sub do_target {
    my ($s) = @_;

    my $grammar = Marpa::R2::Grammar->new($grammar_args);

    my $target_grammar        = Marpa::R2::Thin::G->new( { if => 1 } );
    my $s_start = $target_grammar->symbol_new();
    my $s_target_end_marker      = $target_grammar->symbol_new();
    my $s_target      = $target_grammar->symbol_new();
    my $s_prefix            = $target_grammar->symbol_new();
    my $s_prefix_char       = $target_grammar->symbol_new();
    $target_grammar->start_symbol_set($s_start);
    $target_grammar->rule_new( $s_start,
        [ $s_prefix, $s_target, $s_target_end_marker ] );
    $target_grammar->sequence_new( $s_prefix, $s_prefix_char, { min => 0 } );

    my $s_lparen                  = $target_grammar->symbol_new();
    my $s_rparen                  = $target_grammar->symbol_new();
    my $s_balanced_paren_sequence = $target_grammar->symbol_new();
    my $s_balanced_parens         = $target_grammar->symbol_new();
    my $target_rule = $target_grammar->rule_new( $s_target, [ $s_balanced_parens ] );
    $target_grammar->sequence_new( $s_balanced_paren_sequence, $s_balanced_parens,
        { min => 0 } );
    $target_grammar->rule_new( $s_balanced_parens,
        [ $s_lparen, $s_balanced_paren_sequence, $s_rparen ] );

    $target_grammar->precompute();

    my $target_recce = Marpa::R2::Thin::R->new($target_grammar);
    $target_recce->start_input();
    $target_recce->expected_symbol_event_set( $s_target_end_marker, 1 );

    my $location      = 0;
    my $string_length = length $s;
    my $end_of_match_earleme;

    # Add a check that we don't already expect the end_marker
    # at location 0 -- this will detect zero-length targets.

    # Find the prefix length
    CHAR: while ( $location < $string_length ) {
        my $value = substr $s, $location, 1;
        my $event_count;
	$target_recce->alternative( $s_prefix_char, 0, 1);
        $value eq '(' and $target_recce->alternative( $s_lparen, 0, 1 );
        $value eq ')' and $target_recce->alternative( $s_rparen, 0, 1 );
	$event_count = $target_recce->earleme_complete();
        if ($event_count
            and grep { $_ eq 'MARPA_EVENT_SYMBOL_EXPECTED' }
            map { ; ( $target_grammar->event($_) )[0] }
            ( 0 .. $event_count - 1 )
            )
        {
            $end_of_match_earleme = $location + 1;
            last CHAR;
        } ## end if ( $event_count and grep { $_ eq ...})
        $location++;
    } ## end CHAR: while ( $location < $string_length )

    if ( not defined $end_of_match_earleme ) {
        say "No balanced parens";
        return 0;
    }
    my $start_of_match_earleme = $end_of_match_earleme - 1;

    $target_recce->progress_report_start($end_of_match_earleme);
    ITEM: while (1) {
        my ( $rule_id, $dot_position, $item_origin ) =
            $target_recce->progress_item();
        last ITEM if not defined $rule_id;
        next ITEM if $dot_position >= 0;
        next ITEM if $rule_id != $target_rule;
        $start_of_match_earleme = $item_origin if $item_origin < $start_of_match_earleme;
    } ## end ITEM: while (1)

    # Start the recognizer over again
    $target_recce = Marpa::R2::Thin::R->new($target_grammar);
    $target_recce->start_input();

    # Redo the prefix -- we know this must succeed, so no checking
    $location = 0;
    CHAR: while ( $location < $start_of_match_earleme ) {
        my $value = substr $s, $location, 1;
	$target_recce->alternative( $s_prefix_char, 0, 1);
        $value eq '(' and $target_recce->alternative( $s_lparen, 0, 1 );
        $value eq ')' and $target_recce->alternative( $s_rparen, 0, 1 );
	$target_recce->earleme_complete();
        $location++;
    } ## end CHAR: while ( $location < $string_length )

    $target_recce->expected_symbol_event_set( $s_target_end_marker, 1 );
    $target_recce->ruby_slippers_set(1);

    # We are after the prefix, so now we just continue until exhausted
    CHAR: while ( $location < $string_length ) {
        my $value = substr $s, $location, 1;
        last CHAR
            if $target_recce->alternative(
                    ( $value eq '(' ? $s_lparen : $s_rparen ),
                    0, 1 );
        my $event_count = $target_recce->earleme_complete();
        if ($event_count) {
	   my $exhausted = 0;
	   EVENT: for my $event_type (map { ($target_grammar->event($_))[0] } 0 .. $event_count-1 ) {
	      if ( $event_type eq 'MARPA_EVENT_SYMBOL_EXPECTED' ) {
		$end_of_match_earleme = $location + 1;
		next EVENT;
	      }
	      if ( $event_type eq 'MARPA_EVENT_EXHAUSTED' ) {
	         $exhausted = 1;
		next EVENT;
	      }
	      die "Unknown event: $event_type";
	   }
	   last CHAR if $exhausted;
	}
        $location++;
    } ## end CHAR: while ( $location < $string_length )

    $start_of_match_earleme = $end_of_match_earleme;
    $target_recce->progress_report_start($end_of_match_earleme);
    ITEM: while (1) {
        my ( $rule_id, $dot_position, $item_origin ) =
            $target_recce->progress_item();
        last ITEM if not defined $rule_id;
        next ITEM if $dot_position >= 0;
        next ITEM if $rule_id != $target_rule;
        $start_of_match_earleme = $item_origin if $item_origin < $start_of_match_earleme;
    } ## end ITEM: while (1)

    my $start_of_match = $start_of_match_earleme;
    my $value = substr $s, $start_of_match, $end_of_match_earleme - $start_of_match_earleme;
    return 0 if $target_answer_shown;
    $target_answer_shown = $value;
    say qq{target: "$value" at $start_of_match_earleme-$end_of_match_earleme};
    return 0;

} ## end sub do_target

my $tests = {
    thin => sub { do_thin($s) },
    target => sub { do_target($s) },
};

$tests->{regex} = sub { do_regex($s) } if $do_regex;
$tests->{thin} = sub { do_thin($s) } if $do_thin;
$tests->{r2} = sub { do_r2($s) } if $do_r2;

if ( !$do_timing ) {
    for my $test_name ( keys %{$tests} ) {
        my $closure = $tests->{$test_name};
        say "=== $test_name ===";
        $closure->();
    }
    exit 0;
} ## end if ( !$do_timing )

Benchmark::cmpthese ( $iteration_count, $tests );

my $answer = '(()())';
say +($target_answer_shown eq $answer ? 'Target Answer matches' : 'Target ANSWER DOES NOT MATCH!');
if ($do_r2) {
  say +($marpa_answer_shown eq $answer ? 'R2 Answer matches' : 'R2 ANSWER DOES NOT MATCH!');
}
if ($do_thin) {
  say +($thin_answer_shown eq $answer ? 'Thin Answer matches' : 'Thin ANSWER DOES NOT MATCH!');
}
if ($do_regex) {
  say +($regex_answer_shown eq $answer ? 'Regex Answer matches' : 'Regex ANSWER DOES NOT MATCH!');
}
