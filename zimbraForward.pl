#!/usr/bin/perl -w

#--------------------------------------------------------------------\
# zimbraForward.pl
#
# Forward zimbra accounts to gmigration.saintmarys.edu
#
# Written by Steve HIdeg <hideg@saintmarys.edu>
#
# Jan 2013
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

use Time::Local;

print <<END_OF_GPL_DISCLAIMER;
zimbraForward version 1, Copyright (C) 2013 Steve Hideg
zimbraForward comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions. See file GPL.txt.

END_OF_GPL_DISCLAIMER

# BE SURE TO ADJUST PATHS TO THESE FOR YOUR OWN ENVIRONMENT
require '/zimbraUtils.pl';
require '/miscUtils.pl';


# BE SURE TO ADJUST PATHS TO THESE FOR YOUR OWN ENVIRONMENT
# path to export containing directory
my $ZIMBRA_EXPORT_HOME = '/home/hideg/tasks/google/zimbraExport';

# path to contacts export directory containing user data
my $ZIMBRA_EXPORT_USERS = $ZIMBRA_EXPORT_HOME . '/users';

# path to contacts export directory containing logs
my $ZIMBRA_EXPORT_LOGS = $ZIMBRA_EXPORT_HOME . '/logs';

if($#ARGV == -1)
	{
	print "Usage: zimbraForward.pl username\n";
	print "Or specify one username per line. End with ctrl-D:\n";
	# This will work manually or with input redirection from a file with <
	# e.g. googleAppify < data.txt
	while(<STDIN>)
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
		push @ARGV,$1;
		}
	}


# set number of seconds since epoch for start of this run
my $runStartSec = timelocal((localtime)[0,1,2,3,4,5]);
# date/time stamp for start of this attempt
my $currentTime = localtime;

my ($log,$logPath) = createTimeStampedLogFile('forwarding',$ZIMBRA_EXPORT_LOGS); # miscUtils.pl	
print "Created log file $logPath\n";

printLC ($log,"************************************************************\n");
printLC ($log,"Zimbra Forwarding of users\n");


printLC ($log,"Started $currentTime\n\n");


# number of users processed in this run
my $count = 0;

foreach my $u (@ARGV)
	{
			
	if($u !~/^restored_/)
		{
		
		printLC ($log, "\n$u\n");
		zimbra_forwardToGmigration($log,$u);	
		

		$count++;
		}
	}



printLC ($log, "\n************************************************************\n");
printLC ($log, "\n$count accounts forwarded.\n");




# record end & elapsed time
# get the current seconds and date/time stamp for the finish of this attempt
my $runStopSec = timelocal((localtime)[0,1,2,3,4,5]);
$currentTime = localtime;
printLC ($log, "Run completed at: $currentTime\n");
my $runElapsedTime = hhmmss($runStopSec - $runStartSec);
printLC ($log, "Run Elapsed Time: $runElapsedTime\n\n");

# close log file
close $log;			


exit;




