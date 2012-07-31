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
my $pp = 0;
my $getopt_result = GetOptions(
    "length=i" => \$length,
    "example=s"   => \$example,
    "string=s"   => \$string,
    "pp" => \$pp,
);   

if ($pp) {
    die 'PP not currently implemented';
    require Marpa::PP;
    'Marpa::PP'->VERSION(0.010000);
    say "Marpa::PP ", $Marpa::PP::VERSION;
    no strict 'refs';
    *{'main::Marpa::grammar_new'} = \&Marpa::PP::Grammar::new;
    *{'main::Marpa::recce_new'} = \&Marpa::PP::Recognizer::new;
}
else {
    require Marpa::R2;
    'Marpa::R2'->VERSION(0.020000);
    say "Marpa::R2 ", $Marpa::R2::VERSION;
}

my $tchrist_regex = '(\\((?:[^()]++|(?-1))*+\\))';

if ( defined $string ) {
    die "Bad string: $string" if not $string =~ /\A [()]+ \z/xms;
    say "Testing $string";
    do_marpa_r2($string);
    do_regex($string);
    do_regex_new($string);
    exit 0;
} ## end if ( defined $string )

$length += 0;
if ($length <= 0) {
    die "Bad length $length";
}

$example //= "final";
my $s;
CREATE_S: {
    my $s_balanced = '(()())((';
    if ( $example eq 'pos2_simple' ) {
        $s = '(' . '()'. ( '(' x ( $length - length $s_balanced ) );
        last CREATE_S;
    }
    if ( $example eq 'pos2' ) {
        $s = '(' . $s_balanced . ( '(' x ( $length - length $s_balanced ) );
        last CREATE_S;
    }
    if ( $example eq 'final' ) {
        $s = ( '(' x ( $length - length $s_balanced ) ) . $s_balanced;
        last CREATE_S;
    }
    die qq{Example "$example" not known};
} ## end CREATE_S:

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
my $regex_answer_shown;
my $regex_new_answer_shown;

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

sub do_marpa_r2 {
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
            $event_count = $recce->read( 'xlparen', $location );
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

} ## end sub do_marpa_r2e

sub do_regex {
    my ($s) = @_;
    my $answer =
          $s =~ /$RE{balanced}{-parens=>'()'}{-keep}/
        ? $1
        : 'no balanced parentheses';
    return 0 if $regex_answer_shown;
    $regex_answer_shown = $answer;
    say qq{regex answer: "$answer"};
    return 0;
} ## end sub do_regex

sub do_regex_new {
    my ($s) = @_;
    my $answer =
          $s =~ $tchrist_regex
        ? $1
        : 'no balanced parentheses';
    return 0 if $regex_new_answer_shown;
    $regex_new_answer_shown = $answer;
    say qq{tchrist answer: "$answer"};
    return 0;
} ## end sub do_regex

sub do_thin {
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
    my $thin_grammar = $grammar->thin();

    $grammar->precompute();

    my $s_xlparen = $grammar->thin_symbol('xlparen');
    my $s_ilparen = $grammar->thin_symbol('ilparen');
    my $s_rparen = $grammar->thin_symbol('rparen');

    my ($first_balanced_rule) =
        grep { ( $grammar->rule($_) )[0] eq 'first_balanced' }
        $grammar->rule_ids();

    my $recce         = Marpa::R2::Recognizer->new( { grammar => $grammar } );
    my $thin_recce = $recce->thin();
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

} ## end sub do_thine

# say timestr countit( 2, sub { do_marpa_r2($s) } );
# say timestr countit( 2, sub { do_regex($s) } );
# say timestr countit( 2, sub { do_regex_new($s) } );
Benchmark::cmpthese ( -4, {
    marpa_r2 => sub { do_marpa_r2($s) },
    thin => sub { do_thin($s) },
    regex => sub { do_regex_new($s) }
} );

say +($marpa_answer_shown eq $regex_new_answer_shown ? 'R2 Answer matches' : 'R2 ANSWER DOES NOT MATCH!');
say +($thin_answer_shown eq $regex_new_answer_shown ? 'Thin Answer matches' : 'Thin ANSWER DOES NOT MATCH!');
