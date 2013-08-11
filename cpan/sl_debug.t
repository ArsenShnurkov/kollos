#!/usr/bin/perl
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

# Displays for SLIF Progress.pod

use 5.010;
use strict;
use warnings;

use Test::More tests => 12;

use English qw( -no_match_vars );
use Fatal qw( open close );
use lib 'inc';
use Marpa::R2::Test;
use Marpa::R2;
use Data::Dumper;

my $progress_report = q{};

# Marpa::R2::Display
# name: SLIF Debug Example Part 1

my $slg = Marpa::R2::Scanless::G->new(
    {  source => \(<<'END_OF_SOURCE')
:start ::= statements
statements ::= statement*
statement ::= assignment | <numeric assignment>
assignment ::= 'set' variable 'to' expression
<numeric assignment> ::= variable '=' expression
expression ::=
       variable
    || expression '+' expression
<numeric expression> ::=
       variable | number
    || expression '+' expression
    || expression '*' expression
variable ~ [\w]+
number ~ [\d]+
END_OF_SOURCE
});

# Marpa::R2::Display::End

## no critic (InputOutput::RequireBriefOpen)
open my $trace_fh, q{>}, \( my $trace_output = q{} );
## use critic

# Marpa::R2::Display
# name: Grammar set Synopsis

$slg->set( { trace_file_handle => $trace_fh } );

# Marpa::R2::Display::End

# Marpa::R2::Display
# name: Debug Example Part 2

my $slr = Marpa::R2::Scanless::R->new(
    { grammar => $slg } );

die if not defined $slr->read( \'a = 8675309 + 42 * 711' );

$progress_report = $slr->show_progress( 0, -1 );

# Marpa::R2::Display::End

my $value_ref = $slr->value();
my $value = $value_ref ? ${$value_ref} : 'No Parse';

Test::More::is( $value, 42, 'value' );

# Marpa::R2::Display
# name: Debug Example Progress Report
# start-after-line: END_PROGRESS_REPORT
# end-before-line: '^END_PROGRESS_REPORT$'

Marpa::R2::Test::is( $progress_report,
    <<'END_PROGRESS_REPORT', 'progress report' );
P0 @0-0 Expression -> . Factor
P2 @0-0 Factor -> . Number
P4 @0-0 Factor -> . Factor Multiply Factor
F0 @0-1 Expression -> Factor .
F2 @0-1 Factor -> Number .
R4:1 @0-1 Factor -> Factor . Multiply Factor
P2 @2-2 Factor -> . Number
P4 @2-2 Factor -> . Factor Multiply Factor
R4:2 @0-2 Factor -> Factor Multiply . Factor
F0 @0-3 Expression -> Factor .
F2 @2-3 Factor -> Number .
R4:1 x2 @0,2-3 Factor -> Factor . Multiply Factor
F4 @0-3 Factor -> Factor Multiply Factor .
END_PROGRESS_REPORT

# Marpa::R2::Display::End

$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;

# Marpa::R2::Display
# name: progress(0) example

my $report0 = $slr->progress(0);

# Marpa::R2::Display::End

# Marpa::R2::Display
# name: progress() output at location 0
# start-after-line: END_PROGRESS_REPORT
# end-before-line: '^END_PROGRESS_REPORT$'

chomp( my $expected_report0 = <<'END_PROGRESS_REPORT');
[[0,0,0],[2,0,0],[4,0,0]]
END_PROGRESS_REPORT
Marpa::R2::Test::is( Data::Dumper::Dumper($report0),
    $expected_report0, 'progress report at location 0' );

# Marpa::R2::Display::End

# Try again with negative index
$report0 = $slr->progress(-4);
Marpa::R2::Test::is( Data::Dumper::Dumper($report0),
    $expected_report0, 'progress report at location -4' );

my $report1 = $slr->progress(1);

# Marpa::R2::Display
# name: progress() output at location 1
# start-after-line: END_PROGRESS_REPORT
# end-before-line: '^END_PROGRESS_REPORT$'

chomp( my $expected_report1 = <<'END_PROGRESS_REPORT');
[[0,-1,0],[2,-1,0],[4,1,0]]
END_PROGRESS_REPORT
Marpa::R2::Test::is( Data::Dumper::Dumper($report1),
    $expected_report1, 'progress report at location 1' );

# Marpa::R2::Display::End

# Try again with negative index
$report1 = $slr->progress(-3);
Marpa::R2::Test::is( Data::Dumper::Dumper($report1),
    $expected_report1, 'progress report at location -3' );

my $report2 = $slr->progress(2);

# Marpa::R2::Display
# name: progress() output at location 2
# start-after-line: END_PROGRESS_REPORT
# end-before-line: '^END_PROGRESS_REPORT$'

chomp( my $expected_report2 = <<'END_PROGRESS_REPORT');
[[2,0,2],[4,0,2],[4,2,0]]
END_PROGRESS_REPORT
Marpa::R2::Test::is( Data::Dumper::Dumper($report2),
    $expected_report2, 'progress report at location 2' );

# Marpa::R2::Display::End

# Try again with negative index
$report2 = $slr->progress(-2);
Marpa::R2::Test::is( Data::Dumper::Dumper($report2),
    $expected_report2, 'progress report at location -2' );

# Marpa::R2::Display
# name: progress() example

my $latest_report = $slr->progress();

# Marpa::R2::Display::End

# Marpa::R2::Display
# name: progress() output at location 3
# start-after-line: END_PROGRESS_REPORT
# end-before-line: '^END_PROGRESS_REPORT$'

chomp( my $expected_report3 = <<'END_PROGRESS_REPORT');
[[0,-1,0],[2,-1,2],[4,-1,0],[4,1,0],[4,1,2]]
END_PROGRESS_REPORT
Marpa::R2::Test::is( Data::Dumper::Dumper($latest_report),
    $expected_report3, 'progress report at location 3' );

# Marpa::R2::Display::End

# Try latest report again with explicit index
my $report3 = $slr->progress(3);
Marpa::R2::Test::is( Data::Dumper::Dumper($report3),
    $expected_report3, 'progress report at location 3' );

# Try latest report again with negative index
$latest_report = $slr->progress(-1);
Marpa::R2::Test::is( Data::Dumper::Dumper($latest_report),
    $expected_report3, 'progress report at location -1' );

# Marpa::R2::Display
# name: Debug Example Trace Output
# start-after-line: END_TRACE_OUTPUT
# end-before-line: '^END_TRACE_OUTPUT$'

Marpa::R2::Test::is( $trace_output, <<'END_TRACE_OUTPUT', 'trace output' );
Inaccessible symbol: Add
Inaccessible symbol: Term
Setting trace_terminals option
Expecting "Number" at earleme 0
Accepted "Number" at 0-1
Expecting "Multiply" at 1
Accepted "Multiply" at 1-2
Expecting "Number" at 2
Accepted "Number" at 2-3
Expecting "Multiply" at 3
Rejected "Add" at 3-4
END_TRACE_OUTPUT

# Marpa::R2::Display::End

1;    # In case used as "do" file

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
