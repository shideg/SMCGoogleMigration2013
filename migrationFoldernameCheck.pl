#!/usr/bin/perl -w
#--------------------------------------------------------------------\
# migrationFoldernameCheck.pl
#
# Pre-flight a list of accounts to be migrated
# Make sure they aren't using illegal folder names.
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
migrationFoldernameCheck version 1, Copyright (C) 2013 Steve Hideg
migrationFoldernameCheck comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions. See file GPL.txt.

END_OF_GPL_DISCLAIMER

# BE SURE TO ADJUST PATHS TO THESE FOR YOUR OWN ENVIRONMENT
require '/zimbraUtils.pl';


my @usernames = ();

if($#ARGV == -1)
	{
	print "Usage: migrationFoldernameCheck.pl inputfile\n";
	print "Enter usernames separated by spaces: ";
	
	my $in = <>;
	chomp $in;
	
	@usernames = split / /,$in;

	}
else
	{
	my $inputPath = $ARGV[0];

	open INFILE, $inputPath or die "Unable to open $inputPath: $!";

	while (<INFILE>)
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
		my $u = $1;
		if($u !~/^restored_/)
			{
			push @usernames, $u;
			}
		}
	}

if(scalar(@usernames) == 0)
	{
	print "No users specified.\n";
	exit;
	}

foreach my $u (@usernames)
	{
	# get a list of all folders for this user
	my @folderPathLines = ();
	my $result = zimbra_getFolderPathLines($u,\@folderPathLines); # zimbraUtils.pl

	print "\n$u\n";


	if(lc($result) ne 'ok')
		{
		print " Failed to retrieve list of Zimbra folders:\n";
		print "  $result\n";
		
		next;
		}
	
# 	foreach my $line (@folderPathLines)
# 		{
# 		if($line =~/^\s+\d+\s+mess\s+\d+\s+(\d+)\s+\/(.+)/)
# 			{
# 			print " $line\n";
# 			}
#		}
	
	zimbra_evaluateMailFolders(\@folderPathLines); # zimbraUtils.pl


	} # foreach my $u (@usernames)