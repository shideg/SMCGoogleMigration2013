#!/usr/bin/perl -w

#--------------------------------------------------------------------\
# zimbraExport.pl
#
# Export address books, calendars, and signatures from Zimbra.
# Lock Zimbra accounts after export.
#
# Written by Steve HIdeg <hideg@saintmarys.edu>
#
# December 2012 - Jan 2013
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
zimbraExport version 1, Copyright (C) 2013 Steve Hideg
zimbraExport comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions. See file GPL.txt.

END_OF_GPL_DISCLAIMER

# BE SURE TO ADJUST PATHS TO THESE FOR YOUR OWN ENVIRONMENT
require '/zimbraUtils.pl';
require '/miscUtils.pl';
require '/adUtils.pl';
require '/exportAdUtils.pl';


# path to export containing directory
my $ZIMBRA_EXPORT_HOME = '/home/hideg/tasks/google/zimbraExport';

# path to contacts export directory containing user data
my $ZIMBRA_EXPORT_USERS = $ZIMBRA_EXPORT_HOME . '/users';

# path to contacts export directory containing logs
my $ZIMBRA_EXPORT_LOGS = $ZIMBRA_EXPORT_HOME . '/logs';

my @usernames = ();

if($#ARGV == -1)
	{
	print "Usage: zimbraExport.pl inputfile\n";
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


# ldap connection to AD (passed to various routines)
my $ad = AD_setupAdminLDAP(); # adUtils.pl

# set number of seconds since epoch for start of this run
my $runStartSec = timelocal((localtime)[0,1,2,3,4,5]);
# date/time stamp for start of this attempt
my $currentTime = localtime;

print "ZIMBRA DATA EXPORT\n";
print "Started $currentTime\n\n";


# number of users processed in this run
my $count = 0;

foreach my $u (@usernames)
	{	

	print "\n************************************************************\n";
	print "Zimbra Data Export for user $u\n";
	
	my ($log,$logPath) = createTimeStampedLogFile($u,$ZIMBRA_EXPORT_LOGS); # miscUtils.pl
	
	print "Created log file $logPath\n";
	
	
	# set number of seconds since epoch for start of this attempt
	my $userStartSec = timelocal((localtime)[0,1,2,3,4,5]);
	# date/time stamp for start of this attempt
	$currentTime = localtime;

	print $log "\n************************************************************\n";
	print $log "Zimbra Data Export for user $u\n\n";
	printLC ($log,"Starting $currentTime\n\n"); # miscUtils.pl
	
	
	printLC ($log,"Determining report message sender address.\n"); # miscUtils.pl
	my $sender = exportAD_determineReportSender($ad,$log,$u);
	printLC ($log,"Reports will be sent from $sender.\n"); # miscUtils.pl

	printLC ($log, "\nUnlocking Zimbra Account\n"); # miscUtils.pl
	zimbra_setAccountStatus($log,$u,'active');
	
	
	printLC ($log,"Getting folder names from Zimbra...\n"); # miscUtils.pl
	# get a list of all folders for this user
	my @folderPathLines = ();
	my $result = zimbra_getFolderPathLines($u,\@folderPathLines); # zimbraUtils.pl

	if(lc($result) ne 'ok')
		{
		printLC ($log, " Failed:\n"); # miscUtils.pl
		printLC ($log, "  $result\n"); # miscUtils.pl
		close $log;
					
		print "This info was also written to $logPath\n";
		
		next;
		}
	
	printLC ($log, "\n------------------------------------------------------------\n"); # miscUtils.pl
	printLC ($log, "Exporting Contacts\n\n"); # miscUtils.pl

	zimbra_exportContactsFolders($log,$u,$ad,$sender,@folderPathLines); # zimbraUtils.pl

	# record end & elapsed time
	# get the current seconds and date/time stamp for the finish of this attempt
	my $contactsStopSec = timelocal((localtime)[0,1,2,3,4,5]);
	$currentTime = localtime;
	printLC ($log, "\nContacts export completed at: $currentTime\n"); # miscUtils.pl
	my $contactsElapsedTime = hhmmss($contactsStopSec - $userStartSec);
	printLC ($log, "Contacts export elapsed time: $contactsElapsedTime\n"); # miscUtils.pl

	printLC ($log, "\n------------------------------------------------------------\n"); # miscUtils.pl
	printLC ($log, "Exporting Calendars\n\n"); # miscUtils.pl
	# record start time
	# get the current seconds and date/time stamp for the finish of this attempt
	my $calendarsStartSec = timelocal((localtime)[0,1,2,3,4,5]);
	$currentTime = localtime;
	printLC ($log,"Starting $currentTime\n\n"); # miscUtils.pl

	zimbra_exportCalendars($log,$u,$ad,$sender,@folderPathLines); # zimbraUtils.pl

	# record end & elapsed time
	# get the current seconds and date/time stamp for the finish of this attempt
	my $calendarsStopSec = timelocal((localtime)[0,1,2,3,4,5]);
	$currentTime = localtime;
	printLC ($log, "\nCalendars export completed at: $currentTime\n"); # miscUtils.pl
	my $calendarsElapsedTime = hhmmss($calendarsStopSec - $calendarsStartSec);
	printLC ($log, "Calendars export elapsed time: $calendarsElapsedTime\n"); # miscUtils.pl

	printLC ($log, "\n------------------------------------------------------------\n"); # miscUtils.pl
	printLC ($log, "Transferring Signature\n\n"); # miscUtils.pl
	# record start time
	# get the current seconds and date/time stamp for the finish of this attempt
	my $signatureStartSec = timelocal((localtime)[0,1,2,3,4,5]);
	$currentTime = localtime;
	printLC ($log,"Starting $currentTime\n\n"); # miscUtils.pl

	# DEPRECATED in favor of zimbra_reportSignatures
	# zimbra_transferSignatureToGoogle($log,$u,$sender); # zimbraUtils.pl

	zimbra_reportSignatures($log,$u,$sender); # zimbraUtils.pl

	# record end & elapsed time
	# get the current seconds and date/time stamp for the finish of this attempt
	my $signatureStopSec = timelocal((localtime)[0,1,2,3,4,5]);
	$currentTime = localtime;
	printLC ($log, "\nSignature transfer completed at: $currentTime\n"); # miscUtils.pl
	my $signatureElapsedTime = hhmmss($signatureStopSec - $signatureStartSec);
	printLC ($log, "Signature transfer elapsed time: $signatureElapsedTime\n"); # miscUtils.pl

	printLC ($log, "\n------------------------------------------------------------\n"); # miscUtils.pl
	printLC ($log, "Locking Zimbra Account\n"); # miscUtils.pl
	
	zimbra_setAccountStatus($log,$u,'locked'); # zimbraUtils.pl

	printLC ($log, "\n------------------------------------------------------------\n"); # miscUtils.pl
	printLC ($log, "Recording in AD\n"); # miscUtils.pl
	
	if(my $res = AD_ldap_addAcctDescValue($ad,$u,'googleapps',"Migrated to Google Apps")) # adUtils.pl
		{
		printLC ($log, " $res\n"); # miscUtils.pl
		}
	printLC ($log, "Adding to group GoogleAppsMigrated\n"); # miscUtils.pl
	my $res2 = exportAD_addUsertoGoogleAppsMigrated($ad,$u); # exportAdUtils.pl
	printLC ($log, " $res2\n"); # miscUtils.pl
	
	# record end & elapsed time for user
	# get the current seconds and date/time stamp for the finish of this attempt
	my $userStopSec = timelocal((localtime)[0,1,2,3,4,5]);
	$currentTime = localtime;
	printLC ($log, "\n\nExport for user $u completed at: $currentTime\n"); # miscUtils.pl
	my $userElapsedTime = hhmmss($userStopSec - $userStartSec);
	printLC ($log, "User $u data export elapsed time: $userElapsedTime\n"); # miscUtils.pl

	# close log file
	close $log;			
	$count++;
	} # foreach my $u (@usernames)



print "\n************************************************************\n";
print "\n$count accounts checked.\n";

# record end & elapsed time
# get the current seconds and date/time stamp for the finish of this attempt
my $runStopSec = timelocal((localtime)[0,1,2,3,4,5]);
$currentTime = localtime;
print "Run completed at: $currentTime\n";
my $runElapsedTime = hhmmss($runStopSec - $runStartSec);
print "Run Elapsed Time: $runElapsedTime\n\n";

$ad->unbind;

exit;




