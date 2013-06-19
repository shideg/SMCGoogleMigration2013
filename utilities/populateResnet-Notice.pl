#!/usr/bin/perl -w
#--------------------------------------------------------------------\
# populateResnet-Notice.pl
#
# Use input from text file or GAMME csv control file to create
# the commands to send to listserv to populate the Resnet-Notice mailing list
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
populateResnet-Notice version 1, Copyright (C) 2013 Steve Hideg
populateResnet-Notice comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions. See file GPL.txt.

END_OF_GPL_DISCLAIMER

my @usernames = ();

if($#ARGV == -1)
	{
	print "Usage: populateResnet-Notice inputfile\n";
	exit;
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

print <<END_OF_TOP;
PUTALL RESNET-NOTICE.list PW=***REDACTED***

*
* ResNet Notices
*
* .HH ON
* Reply-to= Sender
* Subscription= Closed
* Owner= resnet\@saintmarys.edu (ResNet)
* Owner= khausman\@saintmarys.edu (Kathy Hausmann)
* Owner= hideg\@saintmarys.edu (Steve Hideg)
* Owner= listmgr\@saintmarys.edu
* Send= Owner
* Default-Options= NoPost
* Ack= Yes
* Notebook= No
* Change-log= No
* Notify= No
* Attachments= Yes
* Confidential= Yes
* .HH OFF
*
END_OF_TOP

print "hideg\@saintmarys.edu\n";

foreach my $u (@usernames)
	{
	print "$u\@saintmarys.edu\n";
	}

exit;
