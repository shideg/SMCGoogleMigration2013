#!/usr/bin/perl -w
#--------------------------------------------------------------------\
# splitICS.pl
#
# Quick-and-dirty script to analyze the specified iCalendar (.ics) file,
# report number of events to user. User specifies number of events per
# output file. Creates output files containint specified number events
# (or fewer for the last file). Output files have the same name as the
# input file plus "-s<number>" plus ".ics".
#
# This was created to split up calendars exported from Zimbra that were
# seemingly too large to import into Google Apps.
#
# Written by Steve Hideg <hideg@saintmarys.edu>
#
# May 2013
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

use POSIX qw(ceil);

# BE SURE TO ADJUST PATHS TO THESE FOR YOUR OWN ENVIRONMENT

print <<END_OF_GPL_DISCLAIMER;
Gnomovision version 1, Copyright (C) 2013 Steve Hideg
Gnomovision comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions. See file GPL.txt.

END_OF_GPL_DISCLAIMER

if($#ARGV == -1)
	{
	print "Usage: splitICS.pl inputfile\n";
	exit;
	}
my $inputPath = shift @ARGV;

# make sure input file has .ics extension
my $path;
if($inputPath =~ /^(.*)\.ics$/)
	{
	# grab the path before the extension to use as the basis for output file paths
	$path = $1;
	
	# NOT NEEDED
	# escape any non-escaped spaces...
	# put a backslash in front of each space
#	$path =~ s/ /\\ /g;
	# remove redundant backslashes (in case spaces were already escaped)
#	$path =~ s/\\\\/\\/g;
	}
else
	{
	print "Specified file does not have .ics extension.\n";
	exit;
	}

open INFILE, $inputPath or die "Unable to open $inputPath: $!";

my $topMatter;
my $bottomMatter;
my @vevents = ();

# ZImbra ICS files seem to consist of some top matter defining the calendar (starting with "BEGIN:VCALENDAR"),
# then a series of event definitions ("BEGIN:VEVENT" ... "END:VEVENT"_
# then some bottom matter (typically one line "END:VCALENDAR")

# Extract these sections into variables $topMatter, $bottomMatter, and array @vevents
# note that we are preserving the line endings in the file and just passing them onto the output files

my $searchMode = 'topmatter';
my $eventIndex = -1;


while (<INFILE>)
	{
	if($searchMode eq 'topmatter')
		{
		if($_ =~ /^BEGIN:VEVENT/)
			{
			# switch to event mode
			$searchMode = 'event';
			$eventIndex++;
			$vevents[$eventIndex] .= $_;
			}
		else
			{
			# still in topmatter mode
			$topMatter .= $_;
			}
		}
	elsif($searchMode eq 'event')
		{
		$vevents[$eventIndex] .= $_;			
		if($_ =~ /^END:VEVENT/)
			{
			# switch to nextThing search mode
			$searchMode = 'nextThing';
			}
		}
	elsif($searchMode eq 'nextThing')
		{
		if($_ =~ /^BEGIN:VEVENT/)
			{
			# switch to event mode
			$searchMode = 'event';
			$eventIndex++;
			$vevents[$eventIndex] .= $_;
			}
		else
			{
			$bottomMatter .= $_
			}
		}

	}

close INFILE;

$_ = '';

my $numberOfEvents = $eventIndex + 1;
my $eventsPerFile = 1000;

print "$numberOfEvents events found. How many per file? [$eventsPerFile] ";

my $a;

$a = <>;
chomp($a);
if($a ne '')
	{
	if($a !~ /^\d+$/)
		{
		exit;
		}
	$eventsPerFile = $a;
	}


my $numberOfFiles = ceil($numberOfEvents/$eventsPerFile);

print "This will create $numberOfFiles files. Proceed? [y] ";
$a = <>;
chomp($a);
if($a ne '')
	{
	if(lc($a) ne 'y')
		{
		exit;
		}
	}

my $fileCounter = 0;
my $fileEventCount = 1;

foreach my $vevent (@vevents)
	{
	if($fileEventCount == 1)
		{
		$fileCounter++;
		# create a new output file
		# filename will be the input file's path, plus "-s<number>" plus .ics
		# e.g. /home/hideg/steve-s1.ics
		my $outFilePath = $path . '-s' . $fileCounter . '.ics';
		print "$outFilePath\n";
		open OUTFILE, "> $outFilePath" or
			die "Unable to create $outFilePath: $!\n";

		# print the top-matter of the ics file
		print OUTFILE $topMatter;

		# print this event
		print OUTFILE $vevent;
		
		$fileEventCount++;
		}
	elsif($fileEventCount < $eventsPerFile)
		{
		# print this event
		print OUTFILE $vevent;

		$fileEventCount++;
		}
	else
		{
		
		print " $fileEventCount events\n";
		
		# last event for this file
		# print this event
		print OUTFILE $vevent;

		# print the bottom-matter
		print OUTFILE $bottomMatter;

		# close the file
		close OUTFILE;

		# reset the event counter
		$fileEventCount = 1;
		}
	}

# if we made it here, we've written the last event we have
# we still need to write bottom matter and close the last file

$fileEventCount--;
print " $fileEventCount events\n";


# print the bottom-matter
print OUTFILE $bottomMatter;

# close the file
close OUTFILE;

exit;
