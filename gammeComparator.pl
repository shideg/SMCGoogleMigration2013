#!/usr/bin/perl -w
#--------------------------------------------------------------------\
# gammeComparator.pl
#
# Compare GAMME csv input file to a capture (copy/paste) of GAMME's
# HTML report to see which accounts it neglected to migrate
#
# Written by Steve HIdeg <hideg@saintmarys.edu>
#
# March 2013
#
# Copyright (C) 2013  Steve Hideg
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see file GPL.txt); if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
#--------------------------------------------------------------------/

use strict;

print <<END_OF_GPL_DISCLAIMER;

gammeComparator version 1, Copyright (C) 2013 Steve Hideg
gammeComparator comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions. See file GPL.txt.

END_OF_GPL_DISCLAIMER



if(scalar(@ARGV) < 2)
	{
	print "Usage: gammeComparator.pl csvFile htmlCaptureFile\n";
	exit;
	}

open CSV, $ARGV[0] or die "Unable to open $ARGV[0]: $!\n";

open CAP, $ARGV[1] or die "Unable to open $ARGV[1]: $!\n";

my %csvs = ();
my %caps = ();


print "CSV:\n----\n";
while(<CSV>)
	{
	chomp;
	# skip commented lines (first non-space character is a #)
	next if($_ =~ /^\s*#/); 
	# skip blank lines
	next if($_ eq '');
	# read a simple list of usernames, one per line
	# or read the GAMME csv control files
	# by ignoring everything after the first @ character on each line
	$_ =~ /([\w|-]+)@?.*/;
	$csvs{$1} = 1;
	print "$1\n";
	}
close CSV;

print "\nReport:\n-------\n";


while(<CAP>)
	{
	chomp;
	# skip commented lines (first non-space character is a #)
	next if($_ =~ /^\s*#/); 
	# read a simple list of usernames, one per line
	# or read the GAMME csv control files
	# by ignoring everything after the first @ character on each line
	$_ =~ /([\w|-]+)@?.*/;
	$caps{$1} = 1;
	print "$1\n";
	}
close CAP;

print "\nDifferences:\n------------\n";


foreach my $csv (keys %csvs)
	{
	if(!exists($caps{$csv}))
		{
		print "$csv\@saintmarys.edu#ZIMBRALOCALPASSWORD, $csv\@saintmarys.edu\n";
		}
	}


