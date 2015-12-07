#!/usr/bin/perl -w
#
# Irish Grid Mapping System
# Copyright 2007-2009 Bekaert M <michael@batlab.eu>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# POD documentation - main docs before the code

=head1 NAME

IrishGrid - Irish Grid Mapping System (bioperl module)

=head1 SYNOPSIS

  # Command line help
  ..:: Irish Grid Mapping System ::..
  > Standalone program version 0.3 <

  Usage: irishgrid.pl [-options] --in=<inputfile.cvs>

   Options
     --size
           Specify the size of each square (in pixel or mm)
           used (default 5).
     --svg
           Set the SVG format as output rather than PNG.

  # SVG file
  ./irishgrid.pl --in=example.pl --svg > mymap.svg

  # PNG file with 10 pixels squares
  ./irishgrid.pl --in=example.pl --size=10 > mymap.png

=head1 DESCRIPTION

Perl module for creating geographic 10km-square maps using either SVG or PNG
(with GD library) format. 

Originally design to map the location of object in a 10 km map IrishGrid
includes:

    * native support of the Irish Grid System (see http://www.osi.ie/)
    * optimize for speed (theres as less as possible data to conversion)
    * customized color functions

As input file, IrishGrid use a text commas separated format (CVS). Each line
represents a record (in chronological order). The first field defined the color
(red, green, blue, black, grey, white), the second the position (using the
Irish Grid System).

  example.cvs

  blue, O008741
  red, C948454
  ...

=head1 REQUIREMENTS

To use this module you may need:
 * SVG modules;
 * GD module and library.

=head1 FEEDBACK

User feedback is an integral part of the evolution of this modules. Send your
comments and suggestions preferably to author.

=head1 AUTHOR

B<Michael Bekaert> (michael@batlab.eu)

The latest version of IrishGrid.pl is available at

  http://irishgrid.googlecode.com/

=head1 LICENSE

Copyright 2007-2009 - Michael Bekaert

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation version 3 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.
 
You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

use strict;
use POSIX qw(floor);
use Getopt::Long;
use SVG;
use GD;

#----------------------------------------------------------
my $version    = "0.4";
my %colormap   = ( red => [ 255, 0, 0 ], green => [ 0, 255, 0 ], blue => [ 0, 0, 255 ], black => [ 0, 0, 0 ], grey => [ 128, 128, 128 ], white => [ 255, 255, 255 ] );
my %lettermap  = ( A => [ 0, 4 ], B => [ 1, 4 ], C => [ 2, 4 ], D => [ 3, 4 ], F => [ 0, 3 ], G => [ 1, 3 ], H => [ 2, 3 ], J => [ 3, 3 ], L => [ 0, 2 ], M => [ 1, 2 ], N => [ 2, 2 ], O => [ 3, 2 ], Q => [ 0, 1 ], R => [ 1, 1 ], S => [ 2, 1 ], T => [ 3, 1 ], V => [ 0, 0 ], W => [ 1, 0 ], X => [ 2, 0 ], Y => [ 3, 0 ] );
my %squaresize = ( '2' => 10_000, '4' => 1_000, '6' => 100, '8' => 10, '10' => 1 );

#----------------------------------------------------------
sub _oneletter2offset {
    my $code    = shift();
    my $minor   = $lettermap{$code};
    my $offsete = ( 100_000 * $minor->[0] );
    my $offsetn = ( 100_000 * $minor->[1] );
    return ( $offsete, $offsetn );
}

#----------------------------------------------------------
my ( $svg, $square, $input ) = ( 0, 5 );
GetOptions( 'in=s' => \$input, 'size:i' => \$square, 'svg!' => \$svg );
if ( defined $input && -r $input ) {
    open FILE, "<$input" or die "Can't find $input: $!\n";
    my @grid;
    while (<FILE>) {
        if ( ( $_ =~ m/^(\w+),(.*)$/x ) && ( defined $colormap{ lc($1) } ) ) {
            my $color         = lc($1);
            my $GridReference = uc($2);
            $GridReference =~ s/\s//xg;
            if ( ( $GridReference =~ m/^([ABCDFGHJLMNOQRSTVWXY])(\d+)$/x ) && ( ( length($2) % 2 ) == 0 ) && ( length($2) <= 10 ) ) {
                my $square            = $1;
                my $digits            = $2;
                my $DefaultResolution = $squaresize{ length($digits) };
                my ( $eastingo, $northingo ) = _oneletter2offset($square);
                my $eastinga = substr( $digits, 0, length($digits) / 2 );
                my $northinga = substr( $digits, length($digits) / 2, length($digits) / 2 );
                my $easting  = $eastingo + $eastinga * $DefaultResolution;
                my $northing = $northingo + $northinga * $DefaultResolution;
                my $error;
                $error = 'west'  if ( $easting < 0 );
                $error = 'east'  if ( $easting >= 400_000 );
                $error = 'south' if ( $northing < 0 );
                $error = 'north' if ( $northing >= 500_000 );
                if ( !defined $error ) { push @grid, ( [ floor( $northing / 10_000 ), floor( $easting / 10_000 ), $color, $GridReference ] ); }
                else                   { print STDERR"Point $_ is out of the area covered - too far $error\n"; }
            } else {
                print STDERR"The grid reference $GridReference does not look valid\n";
            }
        } else {
            print STDERR"The entry $_ does not look valid\n";
        }
    }
    close FILE;
    my $rect = $square + ( $square / 5 ) * 3;
    my $size = 50 * $rect;
    if ($svg) {
        #SVG version
        my $svg = SVG->new( width => $size, height => $size, -nocredits => 1 );

        #Map (Ireland)
        my $land = $svg->group( id => 'land', style => { stroke => 'silver', fill => 'silver' } );
        while (<DATA>) {
            my ( $x, $y ) = split /\W/;
            $land->rectangle( x => $x * $rect, y => ( 50 - $y - 1 ) * $rect, width => $square, height => $square, id => 'X' . $x . 'Y' . $y );
        }

        #Records
        if (@grid) {
            my $records = $svg->group( id => 'records' );
            foreach my $entry (@grid) { $records->rectangle( x => ${$entry}[1] * $rect, y => ( 50 - ${$entry}[0] - 1 ) * $rect, width => $square, height => $square, style => { stroke => ${$entry}[2], fill => ${$entry}[2] }, id => ${$entry}[3] ); }
        }
        print $svg->xmlify;
    } else {
        #GD/PNG version
        my $gd = new GD::Image( $size, $size );
        my $bg = $gd->colorAllocate( 255, 255, 255 );
        $gd->transparent($bg);

        #Map(Ireland)
        my $land = $gd->colorAllocate( 192, 192, 192 );
        while (<DATA>) {
            my ( $x, $y ) = split /\W/;
            $gd->filledRectangle( $x * $rect, ( 50 - $y - 1 ) * $rect, $x * $rect + $square, ( 50 - $y - 1 ) * $rect + $square, $land );
        }

        #Records
        my %color;
        while ( my ( $key, $colors ) = each(%colormap) ) { $color{$key} = $gd->colorAllocate( ${$colors}[0], ${$colors}[1], ${$colors}[2] ); }
        if (@grid) {
            foreach my $entry (@grid) { $gd->filledRectangle( ${$entry}[1] * $rect, ( 50 - ${$entry}[0] - 1 ) * $rect, ${$entry}[1] * $rect + $square, ( 50 - ${$entry}[0] - 1 ) * $rect + $square, $color{ ${$entry}[2] } ); }
        }
        binmode STDOUT;
        print $gd->png;
    }
} else {
    print STDERR"\n..:: Irish Grid Mapping System ::..\n> Standalone program version $version <\n\nFATAL: Incorrect arguments.\nUsage: irishgrid.pl [-options] --in=<inputfile.cvs>\n\n Options\n   --size\n         Specify the size of each square (in pixel or mm)\n         used (default 5).\n   --svg\n         Set the SVG format as output rather than PNG.\n\n";
}
__DATA__
24,45
25,45
21,44
22,44
23,44
24,44
25,44
26,44
29,44
30,44
31,44
32,44
18,43
19,43
20,43
21,43
22,43
23,43
24,43
25,43
27,43
28,43
29,43
30,43
31,43
32,43
18,42
19,42
20,42
21,42
22,42
23,42
24,42
25,42
26,42
27,42
28,42
29,42
30,42
31,42
32,42
17,41
18,41
19,41
20,41
21,41
22,41
23,41
24,41
25,41
26,41
27,41
28,41
29,41
30,41
31,41
32,41
33,41
18,40
19,40
20,40
21,40
22,40
23,40
24,40
25,40
26,40
27,40
28,40
29,40
30,40
31,40
32,40
33,40
34,40
16,39
17,39
18,39
19,39
20,39
21,39
22,39
23,39
24,39
25,39
26,39
27,39
28,39
29,39
30,39
31,39
32,39
33,39
34,39
15,38
16,38
17,38
18,38
19,38
20,38
21,38
22,38
23,38
24,38
25,38
26,38
27,38
28,38
29,38
30,38
31,38
32,38
33,38
34,38
35,38
19,37
20,37
21,37
22,37
23,37
24,37
25,37
26,37
27,37
28,37
29,37
30,37
31,37
32,37
33,37
34,37
35,37
36,37
18,36
19,36
20,36
21,36
22,36
23,36
24,36
25,36
26,36
27,36
28,36
29,36
30,36
31,36
32,36
33,36
34,36
35,36
36,36
17,35
18,35
19,35
20,35
21,35
22,35
23,35
24,35
25,35
26,35
27,35
28,35
29,35
30,35
31,35
32,35
33,35
34,35
35,35
36,35
8,34
9,34
10,34
11,34
17,34
18,34
19,34
20,34
21,34
22,34
23,34
24,34
25,34
26,34
27,34
28,34
29,34
30,34
31,34
32,34
33,34
34,34
35,34
7,33
8,33
9,33
10,33
11,33
12,33
13,33
14,33
15,33
16,33
17,33
18,33
19,33
20,33
21,33
22,33
23,33
24,33
25,33
26,33
27,33
28,33
29,33
30,33
31,33
32,33
33,33
8,32
9,32
10,32
11,32
12,32
13,32
14,32
15,32
16,32
17,32
18,32
19,32
20,32
21,32
22,32
23,32
24,32
25,32
26,32
27,32
28,32
29,32
30,32
31,32
32,32
33,32
8,31
9,31
10,31
11,31
12,31
13,31
14,31
15,31
16,31
17,31
18,31
19,31
20,31
21,31
22,31
23,31
24,31
25,31
26,31
27,31
28,31
29,31
30,31
31,31
32,31
7,30
8,30
9,30
10,30
11,30
12,30
13,30
14,30
15,30
16,30
17,30
18,30
19,30
20,30
21,30
22,30
23,30
24,30
25,30
26,30
27,30
28,30
29,30
30,30
10,29
11,29
12,29
13,29
14,29
15,29
16,29
17,29
18,29
19,29
20,29
21,29
22,29
23,29
24,29
25,29
26,29
27,29
28,29
29,29
30,29
31,29
8,28
9,28
10,28
11,28
12,28
13,28
14,28
15,28
16,28
17,28
18,28
19,28
20,28
21,28
22,28
23,28
24,28
25,28
26,28
27,28
28,28
29,28
30,28
31,28
8,27
9,27
10,27
11,27
12,27
13,27
14,27
15,27
16,27
17,27
18,27
19,27
20,27
21,27
22,27
23,27
24,27
25,27
26,27
27,27
28,27
29,27
30,27
31,27
7,26
8,26
9,26
10,26
11,26
12,26
13,26
14,26
15,26
16,26
17,26
18,26
19,26
20,26
21,26
22,26
23,26
24,26
25,26
26,26
27,26
28,26
29,26
30,26
31,26
32,26
6,25
7,25
8,25
9,25
10,25
11,25
12,25
13,25
14,25
15,25
16,25
17,25
18,25
19,25
20,25
21,25
22,25
23,25
24,25
25,25
26,25
27,25
28,25
29,25
30,25
31,25
32,25
7,24
8,24
9,24
10,24
11,24
12,24
13,24
14,24
15,24
16,24
17,24
18,24
19,24
20,24
21,24
22,24
23,24
24,24
25,24
26,24
27,24
28,24
29,24
30,24
31,24
32,24
8,23
9,23
10,23
11,23
12,23
13,23
14,23
15,23
16,23
17,23
18,23
19,23
20,23
21,23
22,23
23,23
24,23
25,23
26,23
27,23
28,23
29,23
30,23
31,23
32,23
10,22
14,22
15,22
16,22
17,22
18,22
19,22
20,22
21,22
22,22
23,22
24,22
25,22
26,22
27,22
28,22
29,22
30,22
31,22
32,22
13,21
14,21
15,21
16,21
17,21
18,21
19,21
20,21
21,21
22,21
23,21
24,21
25,21
26,21
27,21
28,21
29,21
30,21
31,21
32,21
11,20
12,20
13,20
14,20
15,20
16,20
17,20
18,20
19,20
20,20
21,20
22,20
23,20
24,20
25,20
26,20
27,20
28,20
29,20
30,20
31,20
32,20
33,20
11,19
12,19
13,19
14,19
15,19
16,19
17,19
18,19
19,19
20,19
21,19
22,19
23,19
24,19
25,19
26,19
27,19
28,19
29,19
30,19
31,19
32,19
33,19
11,18
12,18
13,18
14,18
15,18
16,18
17,18
18,18
19,18
20,18
21,18
22,18
23,18
24,18
25,18
26,18
27,18
28,18
29,18
30,18
31,18
32,18
10,17
11,17
12,17
13,17
14,17
15,17
16,17
17,17
18,17
19,17
20,17
21,17
22,17
23,17
24,17
25,17
26,17
27,17
28,17
29,17
30,17
31,17
32,17
9,16
10,16
11,16
12,16
14,16
15,16
16,16
17,16
18,16
19,16
20,16
21,16
22,16
23,16
24,16
25,16
26,16
27,16
28,16
29,16
30,16
31,16
32,16
8,15
10,15
11,15
12,15
13,15
14,15
15,15
16,15
17,15
18,15
19,15
20,15
21,15
22,15
23,15
24,15
25,15
26,15
27,15
28,15
29,15
30,15
31,15
9,14
10,14
11,14
12,14
13,14
14,14
15,14
16,14
17,14
18,14
19,14
20,14
21,14
22,14
23,14
24,14
25,14
26,14
27,14
28,14
29,14
30,14
31,14
8,13
9,13
10,13
11,13
12,13
13,13
14,13
15,13
16,13
17,13
18,13
19,13
20,13
21,13
22,13
23,13
24,13
25,13
26,13
27,13
28,13
29,13
30,13
31,13
8,12
9,12
10,12
11,12
12,12
13,12
14,12
15,12
16,12
17,12
18,12
19,12
20,12
21,12
22,12
23,12
24,12
25,12
26,12
27,12
28,12
29,12
30,12
4,11
5,11
6,11
7,11
8,11
9,11
10,11
11,11
12,11
13,11
14,11
15,11
16,11
17,11
18,11
19,11
20,11
21,11
22,11
23,11
24,11
25,11
26,11
27,11
28,11
29,11
30,11
31,11
3,10
4,10
5,10
6,10
7,10
8,10
9,10
10,10
11,10
12,10
13,10
14,10
15,10
16,10
17,10
18,10
19,10
20,10
21,10
22,10
23,10
24,10
25,10
26,10
7,9
8,9
9,9
10,9
11,9
12,9
13,9
14,9
15,9
16,9
17,9
18,9
19,9
20,9
21,9
22,9
5,8
6,8
7,8
8,8
9,8
10,8
11,8
12,8
13,8
14,8
15,8
16,8
17,8
18,8
19,8
20,8
21,8
22,8
4,7
5,7
6,7
7,7
8,7
9,7
10,7
11,7
12,7
13,7
14,7
15,7
16,7
17,7
18,7
19,7
20,7
5,6
6,6
7,6
8,6
9,6
10,6
11,6
12,6
13,6
14,6
15,6
16,6
17,6
18,6
6,5
7,5
8,5
10,5
11,5
12,5
13,5
14,5
15,5
16,5
17,5
9,4
10,4
11,4
12,4
13,4
14,4
15,4
8,3
9,3
10,3
11,3
