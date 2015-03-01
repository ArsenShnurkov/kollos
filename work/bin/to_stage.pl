#!perl
# Copyright 2015 Jeffrey Kegler
# This file is part of Libmarpa.  Libmarpa is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Libmarpa is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Libmarpa.  If not, see
# http://www.gnu.org/licenses/.

# Copy things into stage/
# It makes more sense to do this in Perl than in the Makefile

use 5.010;
use strict;
use warnings;

use File::Spec;
use File::Copy;
use Getopt::Long;
use autodie;    # Portability not essential in this script

my $verbose;
my $stampfile;
GetOptions( "verbose|v" => \$verbose,
  "stamp=s" => \$stampfile
)
    or die("Error in command line arguments\n");

my $copy_count = 0;

FILE: while ( my $copy = <DATA> ) {
    chomp $copy;
    my ( $to, $from ) = $copy =~ m/\A (.*) [:] \s+ (.*) \z/xms;
    die "Bad copy spec: $copy" if not defined $to;
    next FILE if -e $to and ( -M $to <= -M $from );
    my ( undef, $to_dirs, $to_file ) = File::Spec->splitpath($to);
    my @to_dirs = File::Spec->splitdir($to_dirs);
    my @dir_found_so_far = ();
    # Make the directories we do not find
    DIR_PIECE: for my $dir_piece (@to_dirs) {
	push @dir_found_so_far, $dir_piece;
	my $dir_so_far = File::Spec->catdir(@dir_found_so_far);
        next DIR_PIECE if -e $dir_so_far;
	mkdir $dir_so_far;
    }
    File::Copy::copy($from, $to) or die "Cannot copy $from -> $to";
    $copy_count++;
    say "Copied $from -> $to" if $verbose;
} ## end FILE: while ( my $copy = <DATA> )

say "Files copied: $copy_count";

# If we have defined a stamp file, and we copied files
# or there is no stamp file, update it.
if ($stampfile and ($copy_count or not -e $stampfile)) {
   open my $stamp_fh, q{>}, $stampfile;
   say {$stamp_fh} "" . localtime;
   close $stamp_fh;
}

# Note that order DOES matter here -- the configure.ac files
# MUST be FIRST

__DATA__
doc/configure.ac: ac_doc/configure.ac
doc1/configure.ac: ac_doc1/configure.ac
stage/configure.ac: ac/configure.ac
doc/Makefile.am: ac_doc/Makefile.am
doc1/Makefile.am: ac_doc1/Makefile.am
stage/Makefile.am: ac/Makefile.am
stage/Makefile.win32: win32/Makefile.win32
stage/win32/do_config_h.pl: win32/do_config_h.pl
stage/marpa.c: dev/marpa.c
stage/win32/marpa.def: dev/marpa.def
stage/marpa.h: public/marpa.h
stage/marpa_obs.c: obs/marpa_obs.c
stage/marpa_obs.h: obs/marpa_obs.h
stage/marpa_ami.c: ami/marpa_ami.c
stage/marpa_codes.c: public/marpa_codes.c
stage/marpa_codes.h: public/marpa_codes.h
stage/marpa_ami.h: ami/marpa_ami.h
stage/marpa_avl.c: avl/marpa_avl.c
stage/marpa_avl.h: avl/marpa_avl.h
stage/marpa_tavl.h: tavl/marpa_tavl.h
stage/marpa_tavl.c: tavl/marpa_tavl.c
stage/AUTHORS: ac/AUTHORS
stage/COPYING: shared/COPYING
stage/COPYING.LESSER: obs/COPYING.LESSER
stage/ChangeLog: ac/ChangeLog
stage/NEWS: ac/NEWS
stage/README: ac/README
stage/LIB_VERSION.in: public/LIB_VERSION.in
doc/README: ac_doc/README
doc/NEWS: ac_doc/NEWS
doc/AUTHORS: ac_doc/AUTHORS
doc/ChangeLog: ac_doc/ChangeLog
doc/fdl-1.3.texi: ac_doc/fdl-1.3.texi
doc/lgpl-3.0.texi: ac_doc/lgpl-3.0.texi
doc/api.texi: dev/api.texi
doc/internal.texi: dev/internal.texi
doc1/README: ac_doc1/README
doc1/NEWS: ac_doc1/NEWS
doc1/AUTHORS: ac_doc1/AUTHORS
doc1/ChangeLog: ac_doc1/ChangeLog
doc1/fdl-1.3.texi: ac_doc1/fdl-1.3.texi
doc1/lgpl-3.0.texi: ac_doc1/lgpl-3.0.texi
doc1/api.texi: dev/api.texi
doc1/internal.texi: dev/internal.texi
stage/README.INSTALL: notes/README.INSTALL
