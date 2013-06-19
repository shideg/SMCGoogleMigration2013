#!/usr/bin/perl -w

#--------------------------------------------------------------------\
# zimbraUtils.pl
#
# Set of subroutines for accessing acccount information on Zimbra
#
# Written by Steve Hideg <hideg@saintmarys.edu>
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

# BE SURE TO ADJUST PATHS TO THESE FOR YOUR OWN ENVIRONMENT
require 'miscUtils.pl';
require 'exportAdUtils.pl';


#use URI::Escape;
use List::Util qw[min max];
use Class::Struct;
use MIME::Lite;

# See http://search.cpan.org/~makamaka/Text-CSV-1.21/lib/Text/CSV.pm
use Text::CSV;

# See http://stackoverflow.com/questions/3695105/parsing-an-array-encoded-in-json-through-perl
use JSON;


# ssh to zimbra box string
my $ZIMBRA_SSH = 'ssh zimbra@zimbra';

# path to the zmprov program
my $ZMPROV = '/opt/zimbra/bin/zmprov';

# path to the zmmailbox program
my $ZMMAILBOX = '/opt/zimbra/bin/zmmailbox';
# zmmailbox -z-m hideg@saintmarys.edu gaf

# path to export containing directory
my $ZIMBRA_EXPORT_HOME = '/home/hideg/tasks/google/zimbraExport';

# path to contacts export directory containing user data
my $ZIMBRA_EXPORT_USERS = $ZIMBRA_EXPORT_HOME . '/users';

# path to contacts export directory containing logs
my $ZIMBRA_EXPORT_LOGS = $ZIMBRA_EXPORT_USERS . '/logs';


struct ContactsFolderInfo => {		# create a definition for a contact folder
									# see page 456 of Perl Cookbook "Using Classes as Structs"
	name				=> '$',		# name as shown in zmmailbox (without the leading /)
	count				=> '$',		# number of items the folder contains
	id					=> '$',		# Zimbra ID number of the folder (ID of the ORIGINAL folder, for subscribed folders)
	type				=> '$',		# string indicating type: owned|subscribed
	url					=> '$',		# URL for retrieval via Zimbra's REST interface
	exportFilenameRoot	=> '$',		# unique file name root of export files
	exportFilename		=> '$',		# file name of Thunderbird-formatted export csv file to me mailed to user (<exportFilenameRoot>.csv)
	zExportFilename		=> '$',		# file name of Zimbra-formated export csv to obtain group member data (<exportFilenameRoot>ZIMBRA.csv)
	ownerUsername		=> '$',		# for a subscribed folder, the username of the owner of the folder
	ownerDisplayName	=> '$',		# for a subscribed folder, the display name of the owner of the folder
	columnMap			=> '%',		# column position of certain data cells needed for analysis of Thunderbird-formatted export
	zColumnMap			=> '%',		# column position of certain data cells needed for analysis of Zimbra-formatted export
	msgHTML				=> '$'		# HTML text describing this export to be included in a message to the user
};

struct CalendarInfo 	=> {		# create a definition for a calendar
									# see page 456 of Perl Cookbook "Using Classes as Structs"
	name				=> '$',		# name as shown in zmmailbox (without the leading /)
	count				=> '$',		# number of items the folder contains
	id					=> '$',		# Zimbra ID number of the folder (ID of the ORIGINAL folder, for subscribed folders)
	type				=> '$',		# string indicating type: owned|subscribed|external
	url					=> '$',		# URL for retrieval via Zimbra's REST interface
	exportFilenameRoot	=> '$',		# unique file name root of export files
	exportFilename		=> '$',		# file name of ics file to me mailed to user (<exportFilenameRoot>.ics)
	ownerUsername		=> '$',		# for a subscribed folder, the username of the owner of the folder
	ownerDisplayName	=> '$',		# for a subscribed folder, the display name of the owner of the folder
	msgHTML				=> '$'		# HTML text describing this export to be included in a message to the user
};



# test/debug printing
sub tp {
	my $thing = shift;
	print "$thing\n";
	}





#--------------------------------------------------------------------\
# zimbra_getFolderPathLines
#
# SSH to Zimbra server and issue the zmmailbox gaf command to get a
# list of the user's folders. Put each folder listing line in an array
# element.
#
# Folder types:
# cont
# task
# appo
# conv
# docu
# wiki
#--------------------------------------------------------------------/

sub zimbra_getFolderPathLines {

my $u = shift;
my $arrayRef = shift;

# construct the command
my $cmd = sprintf("%s '%s -z-m \"%s\@saintmarys.edu\" gaf' 2>&1",$ZIMBRA_SSH,$ZMMAILBOX,$u);

my $result = `$cmd`;

if($result =~ /ERROR/)
	{
	chomp $result;
	return $result;
	}
else
	{
	my @lines = split /\n/,$result;
	foreach my $line (@lines)
		{
		if($line =~/^\s+(\d+)\s+(\w+)\s+(\d+)\s+(\d+)\s+(.+)/)
			{
			push @$arrayRef, $line;
			}
		}
	return 'ok';
	}

} # sub zimbra_getFolderPathLines
#--------------------------------------------------------------------/
#--------------------------------------------------------------------\
# zimbra_getDisplayName
# 
# Get the displayname for the account on Zimbra
#
#--------------------------------------------------------------------/

sub zimbra_getDisplayName {

my $u = shift;

# construct the command
my $cmd = sprintf("%s '%s ga \"%s\@saintmarys.edu\" displayName | grep displayName' 2>&1",$ZIMBRA_SSH,$ZMPROV,$u);

my $result = `$cmd`;

if($result =~ /ERROR/)
	{
	chomp $result;
	return $result;
	}
else
	{
	my @lines = split /\n/,$result;
	# should only be one line
	my $line = $lines[0];
	if($line =~/displayName: (.*)$/)
		{
		return $1
		}
	else
		{
		return 'unknown';
		}
	}

} # sub zimbra_getDisplayName
#--------------------------------------------------------------------/



#--------------------------------------------------------------------\
# zimbra_evaluateMailFolders
# 
# Perform some quality checks on Zimbra foldernames.
# Reference to an array containing lines from the zmmailbox gaf 
# folder listing is passed to to this.
#
# Used in pre-flight script migrationFoldernameCheck.pl
#--------------------------------------------------------------------/

sub zimbra_evaluateMailFolders {

my $linesRef = shift;

my @emptyFolder = ();
my @leadingSpaces = ();
my @trailingSpaces = ();
my @illegalCharacterCaret = ();
my @illegalName = ();


foreach my $line (@$linesRef)
	{
	if($line =~/^\s+\d+\s+mess\s+\d+\s+(\d+)\s+\/(.+)/)
		{
		my $messCount = $1;
		my $folderName = $2;
		if($messCount == 0)
			{
			push @emptyFolder, $folderName;
			}
		else
			{
			if($folderName =~ /^\s+/)
				{
				# Leading spaces in name
				push @leadingSpaces, $folderName;
				}
			if($folderName =~ /\s+$/)
				{
				# Trailing spaces in name
				push @trailingSpaces, $folderName;
				}
			if($folderName =~ /\^/)
				{
				# Illegal caret charecter ^ in name
				push @illegalCharacterCaret, $folderName;
				}
			if($folderName =~ /^\s*(|unread|chat|muted|spam|popped|contactcsv)\s*$/i)
				{
				# Illegal/reserved name
				# note that this ignores leading and trailing spaces, if any
				# since the name would be illegal once those conditions are corrected
				push @illegalName, $folderName;
				}
			} # else, if($messCount == 0)
		}
	}


if(scalar(@leadingSpaces))
	{
	print "\nLeading Spaces in Name:\n";
	foreach my $name (@leadingSpaces)
		{
		print "  ###$name###\n";
		}
	}

if(scalar(@trailingSpaces))
	{
	print "\nTrailing Spaces in Name:\n";
	foreach my $name (@trailingSpaces)
		{
		print "  ###$name###\n";
		}
	}

if(scalar(@illegalCharacterCaret))
	{
	print "\nIllegal ^ character in Name:\n";
	foreach my $name (@illegalCharacterCaret)
		{
		print "  ###$name###\n";
		}
	}

if(scalar(@illegalName))
	{
	print "\nIllegal Name:\n";
	foreach my $name (@illegalName)
		{
		print "  ###$name###\n";
		}
	}



} # sub zimbra_evaluateMailFolders
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# zimbra_folderCountsIDs
#
# Extract names of contacts folders from the folder path lines array
# Put message counts into a referenced hash with folder names as keys.
# Put folder ID numbers into a referenced hash with folder names as keys.
#--------------------------------------------------------------------/

sub zimbra_folderCountsIDs {

my $linesRef = shift;
my $folderType = shift; # cont|task|appo|conv|docu|wiki
my $contactsFolderCountRef = shift;
my $contactsFolderIDRef = shift;

foreach my $line (@$linesRef)
	{
	if($line =~/^\s+(\d+)\s+$folderType\s+\d+\s+(\d+)\s+\/(.+)/)
		{
		my $id = $1;
		my $messCount = $2;
		my $folderName = $3;
		$contactsFolderCountRef->{$folderName} = $messCount;
		$contactsFolderIDRef->{$folderName} = $id;
		}
	}

} # sub zimbra_folderCountsIDs
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# zimbra_sortFoldersByHierarchy
#
# Return a list of folders from the specified list, sorted by hierarchy.
# Hierarchy is determined by number of slashes in the path name
#--------------------------------------------------------------------/

sub zimbra_sortFoldersByHierarchy {

my %numSlashes = ();

my $maxCount = 0;

foreach my $f (@_)
	{
	my $count = ($f =~ tr/\//\//);
	$numSlashes{$f} = $count;
	$maxCount = max($maxCount,$count);
	}

my @sorted = ();
# put them in some sort of low-to-high order
for (my $i=0; $i<=$maxCount; $i++)
	{
	foreach my $key (sort((keys %numSlashes)))
		{
		if ($numSlashes{$key} == $i)
			{
			push @sorted, $key;
			$numSlashes{$key} = 0; # so we don't reuse it
			}
		}
	}

return @sorted;

} # sub zimbra_sortFoldersByHierarchy
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# zimbra_determineUniqueFolderName
#
# Determine a unique foldername based on specified name and list of 
# names in use.
#
# Proposed name should already be cleaned up from illegal characters and
# reserved names by the caller. This routine merely ensures uniqueness
# based on the contents in $usedNamesRef array
#--------------------------------------------------------------------/

sub zimbra_determineUniqueFolderName {

my $proposedName = shift;
my $usedNamesRef = shift;


# check if the name collides
my $collision = 0;
foreach my $un (@$usedNamesRef)
	{
	if(lc($proposedName) eq lc($un))
		{
		$collision = 1;
		last;
		}
	}

# if there are no collisions, return the proposed name
push @$usedNamesRef, $proposedName;
return $proposedName if ($collision == 0);

# iterate through appending an dash and an integer to the name until we find something unique
my $append = 1;
my $newName = '';
while($collision != 0)
	{
	$newName = $proposedName . '-' . $append;
	$collision = 0;
	foreach my $un (@$usedNamesRef)
		{
		if(lc($newName) eq lc($un))
			{
			$collision = 1;
			last;
			}
		}
	$append++;
	}

push @$usedNamesRef, $newName;
return $newName;


} # sub zimbra_determineUniqueFolderName
#--------------------------------------------------------------------/





#--------------------------------------------------------------------\
# zimbra_exportContactsFolder
#
# Using the curl command, exports a contacts folder in csv format:
#  For the specified user $u,
#  At the specified URL $folderURL,
#  Redirecting it to a file $exportFolderName in a directory for the user $u
#  Specific csv format specified by $csvFormat
#
#--------------------------------------------------------------------/

sub zimbra_exportContactsFolder {

my $log = shift;
my $u = shift;
my $folderURL = shift;
my $exportFolderName= shift;
my $csvFormat = shift; # thunderbird-csv | zimbra-csv (there are others, but we don't use them)

# define a path for the exported data
my $outputPath = "$ZIMBRA_EXPORT_USERS/$u/$exportFolderName";

printLC($log, " Exporting $folderURL\n   to $outputPath...\n"); # miscUtils.pl

# construct the command
#	http://wiki.zimbra.com/wiki/ZCS_6.0:Zimbra_REST_API_Reference:Get_Contacts
# Assumes the URL comes in with an ID parameter (e.g. ?id=72510), so our parameters
# are appended with an ampersand &
my $URL = "$folderURL&fmt=csv&csvfmt=$csvFormat";
printLC($log, "  URL: $URL\n"); # miscUtils.pl


my $cmd = "curl -s -S -u $u:LOCALZIMBRAPASSWORD \"$URL\" > \"$outputPath\"";
#print "\nusing $cmd\n";

open (RESP, "$cmd |") or die "Can't run command: $!\n";

my $response;
while(<RESP>)
	{
	chomp;
	$response .= $_;
	}
close RESP;

if((defined($response)) && ($response ne ''))
	{
	printLC($log, " $response\n"); # miscUtils.pl
	return 0;
	}
else
	{
	printLC($log, " Export done.\n"); # miscUtils.pl
	return 1;
	}



} # sub zimbra_exportContactsFolder
#--------------------------------------------------------------------/



#--------------------------------------------------------------------\
# zimbra_exportContactsFolders
#
# If the specified user has contacts folders, this routine will process
# them and determine which ones are to be exported, construct and send
# HTML-formatted email to the user with exported contacts folders as
# attachments.
# Exports each contacts folder twice in two formats:
#  thunderbird-csv (for import by user into Google Apps)
#  zimbra-csv (for extraction of group data to be listed in email message)
# 
#--------------------------------------------------------------------/

sub zimbra_exportContactsFolders {

my $log = shift;			# file handle for log file
my $u = shift;				# username
my $ad = shift;				# LDAP connection to Active Directory
my $sender = shift;			# sender address of report email
my @folderPathLines = @_;	# folder path lines from Zimbra

my $messageHTML = ''; 	# email message body
my $outputDir = ''; # directory for user's exported data

my @contactsFolder = (); # array of ContactsFolderInfo objects
my @usedExportNames = (); # array of csv filenames (redundant with exportFilenameRoot in ContactsFolderInfo struct)

my %contactsFoldersCounts = ();
my %contactsFoldersIDs = ();

# gather the names of folders that are address books/contacts
printLC ($log, "Finding contacts folders...\n"); # miscUtils.pl
zimbra_folderCountsIDs(\@folderPathLines,'cont',\%contactsFoldersCounts,\%contactsFoldersIDs); # zimbraUtils.pl

# A series of counters for types and counts
my $ownedCount = 0;
my $ownedEmptyCount = 0;
my $subscribedCount = 0;
my $subscribedEmptyCount = 0;


if(scalar(keys(%contactsFoldersCounts)) > 0 )
	{
	# User has contacts folders
	printLC ($log, scalar(keys(%contactsFoldersCounts)) . " contacts folders found.\n"); # miscUtils.pl
	
	# create directory for user
	# define a path for the exported data
	$outputDir = "$ZIMBRA_EXPORT_USERS/$u";
	# create this directory if it doesn't exist
	if(!-d $outputDir)
		{
		printLC ($log, "Creating $outputDir\n"); # miscUtils.pl
		mkdir $outputDir or die "can't create $outputDir: $!\n";
		}
	else
		{
		printLC ($log, "$outputDir exists.\n"); # miscUtils.pl
		}
		
	printLC($log, "\nProcessing contacts folders...\n"); # miscUtils.pl
	my @sortedFolderNames = zimbra_sortFoldersByHierarchy(keys(%contactsFoldersCounts)); # zimbraUtils.pl
	
	foreach my $sfn (@sortedFolderNames)
		{
		printLC ($log, "\nProcessing $sfn\n"); # miscUtils.pl
		# append a new ContactsFolderInfo object onto the contactsFolder array
		push @contactsFolder, ContactsFolderInfo->new();
		# simplify typing
		my $lcf = $#contactsFolder;
		# store stuff in the object...
		# name
		$contactsFolder[$lcf]->name($sfn);
		# item count
		printLC ($log, " Items: $contactsFoldersCounts{$sfn}\n"); # miscUtils.pl
		$contactsFolder[$lcf]->count($contactsFoldersCounts{$sfn});

		# determine the type of folder this is
		if($sfn =~ /.*\((\w+)\@saintmarys\.edu:(\d+)\)/)
			{
			# type is subscribed
			$contactsFolder[$lcf]->type('subscribed');
			printLC ($log, " Type: subscribed\n"); # miscUtils.pl
			
			# update counter
			if($contactsFoldersCounts{$sfn} > 0)
				{$subscribedCount++;}
			else
				{$subscribedEmptyCount++;}
		
			# username of the owner
			my $ownerUsername = $1;
			printLC ($log, " Owner: $ownerUsername\n"); # miscUtils.pl
			$contactsFolder[$lcf]->ownerUsername($ownerUsername);
			# displayname of the owner, from AD
			my $ownerDisplayName = '';
			if(!($ownerDisplayName = exportAD_geSingleValuedAtt($ad,$log,$ownerUsername,'displayName'))) # exportAdUtils
				{
				# if the owner's AD object doesn't have a displayName, try to get it from Zimbra
				$ownerDisplayName = zimbra_getDisplayName($ownerUsername); # zimbraUtils.pl
				}
			$contactsFolder[$lcf]->ownerDisplayName($ownerDisplayName);
			printLC ($log, " Owner Name: $ownerDisplayName\n"); # miscUtils.pl
			# Zimbra ID number of the folder
			$contactsFolder[$lcf]->id($2);
			printLC ($log, " ID: $2\n"); # miscUtils.pl
			# URL to the folder using the ID number (does not include fmt and csvfmt parameters)
			my $url = "http://zimbra.saintmarys.edu/user/$ownerUsername/?id=$2";
			$contactsFolder[$lcf]->url($url);
			printLC ($log, " URL: $url\n"); # miscUtils.pl
			}
		else
			{
			# type is owned
			$contactsFolder[$lcf]->type('owned');
			printLC ($log, " Type: owned\n"); # miscUtils.pl

			# update counter
			if($contactsFoldersCounts{$sfn} > 0)
				{$ownedCount++;}
			else
				{$ownedEmptyCount++;}

			# Zimbra ID number of the folder
			$contactsFolder[$lcf]->id($contactsFoldersIDs{$sfn});
			printLC ($log, " ID: $contactsFoldersIDs{$sfn}\n"); # miscUtils.pl
			# URL to the folder using the ID number (does not include fmt and csvfmt parameters)
			my $url = "http://zimbra.saintmarys.edu/user/$u/?id=$contactsFoldersIDs{$sfn}";
			$contactsFolder[$lcf]->url($url);
			printLC ($log, " URL: $url\n"); # miscUtils.pl
			} # else, if($sfn =~ /.*\((\w+)\@saintmarys.edu:(\d+)\)/)

		# output filename
		my $temp = $sfn;
		# change all slashes to dashes
		$temp =~ s/\//-/g;
		# remove leading spaces
		$temp =~ s/^\s+//;
		# remove trailing spaces
		$temp =~ s/\s+$//;
		# change spaces to underscores
		$temp =~ s/\s/_/g;
		# remove single-quotes
		$temp =~ s/'//g;
		# remove double-quotes
		$temp =~ s/"//g;
		# change caret ^ to _
		$temp =~ s/\^/_/g;
		# munge subscribed folder
		# e.g. at this point we'd have Kathy_Hausmanns_Cool_People_(khausman@saintmarys.edu:72501)
		#      the result should be Kathy_Hausmanns_Cool_People(khausman)
		$temp =~ s/_?\((.+)\@saintmarys\.edu:\d+\)/($1)/;
	
		# avoid filename collisions by checking for existing filenames in the array
		my $exportFilenameRoot = zimbra_determineUniqueFolderName($temp,\@usedExportNames);
		$contactsFolder[$lcf]->exportFilenameRoot($exportFilenameRoot);
		printLC ($log, " Filename Root: $exportFilenameRoot\n"); # miscUtils.pl

		# construct export names from the root
		my $exportFilename = $exportFilenameRoot . '.csv';
		$contactsFolder[$lcf]->exportFilename($exportFilename);
		printLC ($log, " Export Filename: $exportFilename\n"); # miscUtils.pl
		my $zExportFilename = $exportFilenameRoot . 'ZIMBRA.csv';
		$contactsFolder[$lcf]->zExportFilename($zExportFilename);
		printLC ($log, " Zimbra Export Filename: $zExportFilename\n"); # miscUtils.pl
	
	
		if($contactsFolder[$lcf]->count() > 0)
			{
			# non-empty contacts folder
			# download the contacts folders
			# Thunderbird format for import
			if(!zimbra_exportContactsFolder($log,$u,$contactsFolder[$lcf]->url(),$contactsFolder[$lcf]->exportFilename(),'thunderbird-csv'))
				{
				printLC ($log, " CANNOT PROCCESS FOLDER. Skipping...\n"); # miscUtils.pl
				next;
				}
			# Zimbra format for group extraction
			if(!zimbra_exportContactsFolder($log,$u,$contactsFolder[$lcf]->url(),$contactsFolder[$lcf]->zExportFilename(),'zimbra-csv'))
				{
				printLC ($log, " CANNOT PROCCESS FOLDER. Skipping...\n"); # miscUtils.pl
				next;
				}

			# analyze (non-empty) address book and generate report to user (stored in msgHTML in struct)
			zimbra_analyzeAddressBookExport($log,$outputDir,$contactsFolder[$lcf]);

			} # if($contactsFolder[$lcf]->count() > 0)
		else
			{
			# nothing to download
			printLC ($log, " Empty folder. Skipping...\n"); # miscUtils.pl		
			} # else, if($contactsFolder[$lcf]->count() > 0)
		} # foreach my $sfn (@sortedFolderNames)
	
	# construct the HTML email message	
	$messageHTML = <<END_OF_HTML1;
<html lang="en">
<head>
	<meta charset="utf-8" />
	<title>Contacts Export Report</title>
	<meta name="generator" content="BBEdit 10.5" />
</head>
<body style="word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space; font: .75em 'Lucida Grande', Lucida, Verdana, sans-serif">
<img src="http://sites.saintmarys.edu/~hd/googleapps.jpeg" width="475" height="68" alt="googleapps">
<h2><img src="http://sites.saintmarys.edu/~hd/zimbralogo.jpeg" width="100" height="23" alt="zimbralogo"><span style="color: #928">Zimbra Address Book Export</span></h2>
<h3>Export Report for user <span style="color:#444"><strong>$u</strong></span></h3>
<hr align="left">
<p>Your address books from Zimbra were exported as CSV files and have been sent as attachments with this message.
<br>
For instructions on how to import these contacts into Google Apps, please	
visit <a href="https://sites.google.com/a/saintmarys.edu/googleapps/zimbra-imports" target="_blank">Importing Zimbra Calendars and Contacts into Google</a>.
<br>
(You will need to be logged into your Google Apps account to access these instructions.)</p>
<p>If you do not wish to import any of your address books from Zimbra into Google Apps, you can simply ignore or delete this message.</p>
<p>Specific information about Google Contacts, including creating contacts and contact groups, can be found <a href=\"https://sites.google.com/a/saintmarys.edu/googleapps/your-first-days-3\" target=\"_blank\">here</a>.</p>


END_OF_HTML1

	# owned, non-empty address books
	if($ownedCount > 0)
		{
		$messageHTML .= "<hr align=\"left\">\n";
		$messageHTML .= "<h3>Address Books Created by You</h3>\n";
		$messageHTML .= "<p>The following address books created by you have been found in Zimbra and were exported.</p>\n";
		$messageHTML .= "<p>These address books have been sent as attachments to this message.</p>\n";
		$messageHTML .= "<ol>\n";
		foreach my $theCF (@contactsFolder)
			{
			if(($theCF->type() eq 'owned') && ($theCF->count() > 0))
				{
				$messageHTML .= $theCF->msgHTML();
				}
			}
		$messageHTML .= "</ol>\n";
		} # if($ownedCount > 0)

	# subscribed, non-empty address books
	if($subscribedCount > 0)
		{
		$messageHTML .= "<hr align=\"left\">\n";
		$messageHTML .= "<h3>Address Books Created and Shared by Others</h3>\n";
		$messageHTML .= "<p>The following <em>shared</em> address books have been found in Zimbra. These were created and shared with you by another user.<br>We are providing you with a <em>copy</em> of this data for your convenience. <br>Google Apps does not provide shared address books in this manner.</p>\n";
		$messageHTML .= "<p>These address books have been sent as attachments to this message.</p>\n";
		$messageHTML .= "<ol>\n";
		foreach my $theCF (@contactsFolder)
			{
			if(($theCF->type() eq 'subscribed') && ($theCF->count() > 0))
				{
				$messageHTML .= $theCF->msgHTML();
				}
			}
		$messageHTML .= "</ol>\n";
		} # if($subscribedCount > 0)

	# owned, empty address books
	if($ownedEmptyCount > 0)
		{
		$messageHTML .= "<hr align=\"left\">\n";
		$messageHTML .= "<h3>Empty Address Books</h3>\n";
		$messageHTML .= "<p>The following empty address books created by you have been found in Zimbra. They contain no data and were not exported.</p>\n";
		$messageHTML .= "<ol>\n";
		foreach my $theCF (@contactsFolder)
			{
			if(($theCF->type() eq 'owned') && ($theCF->count() == 0))
				{
				$messageHTML .= '<li><strong>' . $theCF->name() . "</strong></li>\n";
				}
			}
		$messageHTML .= "</ol>\n";
		} # if($ownedEmptyCount > 0)

	# subscribed, empty address books
	if($subscribedEmptyCount > 0)
		{
		$messageHTML .= "<hr align=\"left\">\n";
		$messageHTML .= "<h3>Empty Address Books Created by Others</h3>\n";
		$messageHTML .= "<p>The following empty <em>shared</em> address books have been found in Zimbra. They contain no data and were not exported.</p>\n";
		$messageHTML .= "<ol>\n";
		foreach my $theCF (@contactsFolder)
			{
			if(($theCF->type() eq 'subscribed') && ($theCF->count() == 0))
				{
				# clean up any owner information from the name we send to the user
				my $temp = $theCF->name();
				$temp =~ s/ \(.+\@saintmarys\.edu:\d+\)$//;
				$messageHTML .= '<li><strong>' . $temp . "</strong></li>\n";
				}
			}
		$messageHTML .= "</ol>\n";
		} # if($subscribedEmptyCount > 0)



	
	} # if(scalar(keys((%contactsFolders)) > 0 ))
else
	{
	# no contacts folders found
	printLC ($log, "No contacts folders found.\n"); # miscUtils.pl
	# email user advising them of this?
	# we never enountered this because every user has "emailed contacts"???

	}

$messageHTML .= <<END_OF_HTML2;
<br>
<hr align="left">
<p><em>This message is generated automatically by software.</em></p>
<p>Specific information about Google Contacts, including creating contacts and contact groups, can be found <a href=\"https://sites.google.com/a/saintmarys.edu/googleapps/your-first-days-3\" target=\"_blank\">here</a>.</p>
<p>If you have any questions or problems, please consult <a href="https://sites.google.com/a/saintmarys.edu/googleapps/" target="_blank">Saint Mary's College online Google Apps documentation</a>.</p>
<hr align="left">
<div style="color: #666; font-size: 80%;">
<p><em>Export software written by Steve Hideg</em><br>&copy;2013, Saint Mary's College, Notre Dame, IN</p>
</div>
</body>
</html>
END_OF_HTML2


my $recipient = $u . '@saintmarys.edu';

printLC ($log, "\nSending email report to $recipient from $sender\n"); # miscUtils.pl
my $message = MIME::Lite->new
	(
	Subject => "Zimbra Contacts Export: $u",
	From 	=> $sender,
	To		=> $recipient,
	Bcc		=> 'beta@gmigration.saintmarys.edu',
	Type	=> 'text/html',
	Data	=> $messageHTML
	);

# attach the exported address books
foreach my $cf (@contactsFolder)
	{
	# obviously, only non-empty address books
	if ($cf->count() > 0)
		{
		my $attPath = "$outputDir/" . $cf->exportFilename();
		my $attName = $cf->exportFilename();
		$message->attach(
			Type => 'text/csv',
			Path => $attPath,
			Filename => $attName,
			Disposition => 'attachment'
			);
		} # if ($cf->count() > 0)
	} # foreach my $cf (@contactsFolder)

	$message->send();  



} # sub zimbra_exportContactsFolders
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# zimbra_analyzeAddressBookExport
#
# Analyze the specified address book.
# Put the resulting HTML-formatted report into the msgHTML member of
# the specified ContactsFolderInfo struct
#--------------------------------------------------------------------/

sub zimbra_analyzeAddressBookExport {

my $log = shift;
# containing folder
my $outputDir= shift;
# address book struct
my $cf = shift;

# temporary holder for msgHTML
my $mh = '';

# clean up any owner information from the name we send to the user
my $temp = $cf->name();
printLC ($log, " Analyzing $temp\n"); # miscUtils.pl

$temp =~ s/ \(.+\@saintmarys\.edu:\d+\)$//;
printLC ($log, " Cleaned name: $temp\n"); # miscUtils.pl


$mh .= '<li><strong>' . $temp . "</strong>\n";

if($temp =~ /^zmail_/)
	{
	$mh .= "<br>Note: <em>This address book was transfered in 2010 during our emergency switchover between Zimbra servers due to weather-related server damage and likely contains legacy data</em>\n";
	}
elsif($temp =~ /^aegis_/)
	{
	$mh .= "<br>Note: <em>This address book was transfered in 2007 during our switchover from the Aegis (iPlanet) messaging server and Zimbra, and likely contains legacy data</em>\n";
	}

# If this is the Emailed Contacts folder, provide some explanatory text
if($cf->name() eq 'Emailed Contacts')
	{
	$mh .= "	<br>Note: <em>Emailed Contacts is an automatically generated list by Zimbra that records all email addresses you've sent to (regardless of whether the addresses were correct or not).\n";
	$mh .= "	This address book aids in the auto-completion of addresses when composing messages. A similar feature exists in Google. If you import this address book, you will help Google with its autocompletion function, but it is not absolutely necessary.\n";
	$mh .= "	If your Emailed Contacts address book contains invalid email addresses, those will be used in autocomplete functions as well as correct ones. Neither Zimbra nor Google have a way to identify incorrect addresses.</em>\n";
	}



$mh .= " <ul>\n";
$mh .= ' <li><strong>Exported as: </strong>' . $cf->exportFilename() . " <em>(See attachment)</em></li>\n";
$mh .= ' <li><strong>Number of Entries: </strong>' . $cf->count() . "</li>\n";

# if this folder is subscribed, list the owner of the folder
if($cf->type() eq 'subscribed')
	{
	$mh .= ' <li><strong>Owner: </strong>' . $cf->ownerUsername() . '@saintmarys.edu';
	if(defined($cf->ownerDisplayName()))
		{
		$mh .= ' (' . $cf->ownerDisplayName() . ')';
		}
	$mh .= "</li>\n";
	}

# analyze the export for possible invalid/group entries
my $gh = zimbra_checkForAddressBookGroups($log,$outputDir,$cf->exportFilename(),$cf->zExportFilename());
if($gh ne '')
	{
	$mh .= " <li><strong>Invalid Entries: </strong>(Entries have insufficient data. They will import to Google, but will have no email address associated with them.)\n";
	$mh .= " <br>The following entries were probably greated as &quot;Contact Groups&quot; in Zimbra. We have attempted to extract email information on the members of these groups.\n";
	$mh .= " You can create new groups in the Contacts section of Google Apps and populate them with any members listed here.\n";
	$mh .= " <br>Specific information about Google Contacts, including creating contacts and contact groups, can be found <a href=\"https://sites.google.com/a/saintmarys.edu/googleapps/your-first-days-3\" target=\"_blank\">here</a>.\n";
	$mh .= "  <ul>\n";
	$mh .= $gh;
	$mh .= "  </ul>\n";
	$mh .= " </li>\n";
	}

$mh .= " </ul>\n";
$mh .= "</li><br>\n";

			
# set this contact folder object's msgHTML member
$cf->msgHTML($mh);

} # sub zimbra_analyzeAddressBookExport
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# zimbra_checkForAddressBookGroups
#
# Analyze the specified Thunderbird export file to see if any entries are groups.
# Obtain group members (if any) from corresponding Zimbra export file
#--------------------------------------------------------------------/

sub zimbra_checkForAddressBookGroups {

my $log = shift;
my $folderPath = shift; # path to folder containing user's export files
my $tName = shift; 		# filename of Thunderbird-format export
my $zName = shift; 		# filename of Zimbra-format export

# path to Thunderbird-format export file
my $tPath = "$folderPath/$tName";
# path to Zimbra-format export file
my $zPath = "$folderPath/$zName";


my %tMap = ();	# column locations of data of interest in Thunderbird file
my %zMap = ();	# column locations of data of interest in Zimbra file

# create a Text::CSV object
my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

# open the Thunderbird file for reading
open my $texp, "<:encoding(utf8)", $tPath or die "Unable to open $tPath: $!";

my @tRows = ();

# read all rows
while ( my $row = $csv->getline( $texp ) )
	{
	push @tRows, $row;
	}

# close the Thunderbird file
close $texp;

# get the header row
my $tHeader = shift(@tRows);

# map out pertinent column locations in the thunderbird file
my $tCollCount = scalar(@$tHeader);
for(my $i=0; $i<$tCollCount; $i++)
	{
	if(lc($tHeader->[$i]) eq 'nickname')
		{
		$tMap{'nickname'} = $i;
		}
	elsif(lc($tHeader->[$i]) eq 'primary email')
		{
		$tMap{'primaryemail'} = $i;
		}
	elsif(lc($tHeader->[$i]) eq 'secondary email')
		{
		$tMap{'secondaryemail'} = $i;
		}
	elsif(lc($tHeader->[$i]) eq 'first name')
		{
		$tMap{'firstname'} = $i;
		}
	elsif(lc($tHeader->[$i]) eq 'last name')
		{
		$tMap{'lastname'} = $i;
		}
	}


# open the Zimbra file for reading
open my $zexp, "<:encoding(utf8)", $zPath or die "Unable to open $zPath: $!";

my @zRows = ();

# read all rows
while ( my $row = $csv->getline( $zexp ) )
	{
	push @zRows, $row;
	}

# close the Zimbra file
close $zexp;

# get the header row
my $zHeader = shift(@zRows);

# map out pertinent column locations in the zimbra file
my $zCollCount = scalar(@$zHeader);
for(my $i=0; $i<$zCollCount; $i++)
	{
	if(lc($zHeader->[$i]) eq 'nickname')
		{
		$zMap{'nickname'} = $i;
		}
	elsif(lc($zHeader->[$i]) eq 'dlist')
		{
		$zMap{'dlist'} = $i;
		}
	}

# message HTML, empty string if we find no groups
my $mh = '';

if(!defined($zMap{'dlist'}))
	{
	# no 'dlist' column header found, so this address book apparently has no groups
	return $mh;
	}

# look for rows that have neither primaryemail nor secondaryemail
for (my $i=0; $i<=$#tRows; $i++)
	{
	my $tRow = $tRows[$i];
	my $zRow = $zRows[$i];
	if(($tRow->[$tMap{'primaryemail'}] eq '') && ($tRow->[$tMap{'secondaryemail'}] eq ''))
		{
		
		# look for data in the dlist column, if it exists
		# this contains a comma, separated list of "First Last <email>" entries
		if(defined($zMap{'dlist'}) && ($zRow->[$zMap{'dlist'}] ne ''))
			{
			# entry has stuff in the dlist column so we report it
		
			# make an aggregate name from firstname, lastname and nickname
			my $groupName = join(' ',$tRow->[$tMap{'firstname'}],$tRow->[$tMap{'lastname'}],$tRow->[$tMap{'nickname'}]);
			# remove leading spaces
			$groupName =~ s/^\s+//;
			# remove trailing spaces
			$groupName =~ s/\s+$//;
		
			printLC ($log, "  Group?: $groupName\n"); # miscUtils.pl

			$mh .= "    <li><strong>Entry/Group: </strong>&quot;$groupName&quot;\n";


			$mh .= "      <ul style=\"list-style-type: none;\">\n";		

			# put the dlist into a temporary variable
			my $dlistData = $zRow->[$zMap{'dlist'}];
				
			# put all email addresses inside angle-brackets for easier parsing
			$dlistData =~ s/(\S+\@[\w\.]+),/<$1>,/g;
			$dlistData =~ s/ (\S+\@[\w\.]+)$/ <$1>/g;
			
			# split the entries into an array
			my @dlist = split />, /,$dlistData;

			# array to hold the result member list
			my @members = ();

			for(my $i=0; $i<=$#dlist; $i++)
				{
				# restore the trailing >
				if($dlist[$i] !~ />$/)
					{
					$dlist[$i] .= '>';
					}
				push @members, zimbra_splitAddresses($dlist[$i]);
				}

			foreach my $m (@members)
				{
				# clean up the member entry for HTML display (change < into &lt;, change > into &gt;)
				printLC ($log, "   $m\n"); # miscUtils.pl
				$m =~ s/</&lt;/g;
				$m =~ s/>/&gt;/g;
				# change . into &#46; so Spamcan won't block messages containing addresses with invalid domains
				# (see ginny@mrterryc.com in agair export)
				$m =~ s/\./&#46;/g;
				$mh .= "      <li>$m</li>\n";
				}
			$mh .= "      </ul>\n";		
			$mh .= "    </li>\n";
			} # if($zRow->[$zMap{'dlist'}] ne '')
		else
			{
			# no dlist data
			# This is likely just a simple entry without an email address, so we do nothing
			}
		} # if(($tRow->[$tMap{'primaryemail'}] eq '') && ($tRow->[$tMap{'secondaryemail'}] eq ''))
	}

return $mh;

} # sub zimbra_checkForAddressBookGroups
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# zimbra_splitAddresses
#
# Feeble attempt at parsing and splitting out members of the "dlist"
# field in Zimbra-formatted address book csv files
#--------------------------------------------------------------------/
sub zimbra_splitAddresses {

my $data = shift;

print "zimbra_splitAddresses: $data\n";

my @data2 = split /,/,$data;

if(scalar(@data2) == 1)
	{
	# remove leading spaces
	$data =~ s/^\s+//;
	# remove trailing spaces
	$data =~ s/\s+$//;
	return ($data);
	}
elsif(scalar(@data2) == 2)
	{
	# if both elements contain at least one email address, they must be further analyzed
	if(($data2[0] =~ /\@/) && ($data2[1] =~ /\@/))
		{
		return (zimbra_splitAddresses($data2[0]),zimbra_splitAddresses($data2[1]));
		}
	else
		{
		# otherwise, the member likely has an embedded comma, return it
		# remove leading spaces
		$data =~ s/^\s+//;
		# remove trailing spaces
		$data =~ s/\s+$//;
		return ($data);
		}
	}
else
	{
	# we have more than two fields upon splitting with a comma
	# give up and return the list
	return(@data2);
	}

} # sub zimbra_splitAddresses
#--------------------------------------------------------------------/




#--------------------------------------------------------------------\
# zimbra_exportCalendars
#
# If the specified user has calendars, this routine will process
# them and determine which ones are to be exported, construct and send
# HTML-formatted email to the user with exported calendars as
# attachments.
#
# If the user is subscribed to calendars, those are listed in the email
# along with the owner's email address.
# If the user has shared calendars, the sharing privileges are listed
# for such calendars.
#--------------------------------------------------------------------/

sub zimbra_exportCalendars {

my $log = shift;			# file handle for log file
my $u = shift;				# username
my $ad = shift;				# LDAP connection to Active Directory
my $sender = shift;			# sender address of report email
my @folderPathLines = @_;	# folder path lines from Zimbra

my $messageHTML = ''; 	# email message body
my $outputDir = ''; # directory for user's exported data

my @calendar = (); # array of CalendarInfo objects
my @usedExportNames = (); # array of csv filenames (redundant with exportFilenameRoot in ContactsFolderInfo struct)

my %calendarsCounts = ();
my %calendarsIDs = ();
# gather the names of folders that are address books/contacts
printLC ($log, "Finding calendars...\n"); # miscUtils.pl
zimbra_folderCountsIDs(\@folderPathLines,'appo',\%calendarsCounts,\%calendarsIDs); # zimbraUtils.pl

# A series of counters for types and counts
my $ownedCount = 0;
my $ownedEmptyCount = 0;
my $subscribedCount = 0;
my $subscribedEmptyCount = 0;
my $externalCount = 0;

if(scalar(keys(%calendarsCounts)) > 0 )
	{
	# User has calendar folders
	printLC ($log, scalar(keys(%calendarsCounts)) . " calendars found.\n"); # miscUtils.pl

	# create directory for user
	# define a path for the exported data
	$outputDir = "$ZIMBRA_EXPORT_USERS/$u";
	# create this directory if it doesn't exist
	if(!-d $outputDir)
		{
		printLC ($log, "Creating $outputDir\n"); # miscUtils.pl
		mkdir $outputDir or die "can't create $outputDir: $!\n";
		}
	else
		{
		printLC ($log, "$outputDir exists.\n"); # miscUtils.pl
		}
		
	printLC($log, "\nProcessing calendars...\n"); # miscUtils.pl

	my @sortedFolderNames = zimbra_sortFoldersByHierarchy(keys(%calendarsCounts)); # zimbraUtils.pl
	
	foreach my $sfn (@sortedFolderNames)
		{
		printLC ($log, "\nProcessing $sfn\n"); # miscUtils.pl
		# append a new CalendarInfo object onto the calendar array
		push @calendar, CalendarInfo->new();
		# simplify typing
		my $lcf = $#calendar;
		# store stuff in the object...
		# name
		$calendar[$lcf]->name($sfn);
		# item count
		printLC ($log, " Items: $calendarsCounts{$sfn}\n"); # miscUtils.pl
		$calendar[$lcf]->count($calendarsCounts{$sfn});

		# determine the type of folder this is
		if($sfn =~ /.*\((\w+)\@saintmarys\.edu:(\d+)\)/)
			{
			# type
			$calendar[$lcf]->type('subscribed');
			printLC ($log, " Type: subscribed\n"); # miscUtils.pl
			
			# update counter
			if($calendarsCounts{$sfn} > 0)
				{$subscribedCount++;}
			else
				{$subscribedEmptyCount++;}
		
			# username of the owner
			my $ownerUsername = $1;
			printLC ($log, " Owner: $ownerUsername\n"); # miscUtils.pl
			$calendar[$lcf]->ownerUsername($ownerUsername);
			# displayname of the owner, from AD
			my $ownerDisplayName = '';
			if(!($ownerDisplayName = exportAD_geSingleValuedAtt($ad,$log,$ownerUsername,'displayName'))) # exportAdUtils
				{
				# if the owner's AD object doesn't have a displayName, try to get it from Zimbra
				$ownerDisplayName = zimbra_getDisplayName($ownerUsername); # zimbraUtils.pl
				}
			$calendar[$lcf]->ownerDisplayName($ownerDisplayName);
			printLC ($log, " Owner Name: $ownerDisplayName\n"); # miscUtils.pl
			# Zimbra ID number of the folder
			$calendar[$lcf]->id($2);
			printLC ($log, " ID: $2\n"); # miscUtils.pl
			# URL to the folder using the ID number (does not include fmt and csvfmt parameters)
			my $url = "http://zimbra.saintmarys.edu/user/$ownerUsername/?id=$2";
			$calendar[$lcf]->url($url);
			printLC ($log, " URL: $url\n"); # miscUtils.pl
			}
		# discovered that some people have calendars shared from other services
		# assume that the part in parentheses is either an http or https URL
		elsif($sfn =~ /(.*)\((https?:\/\/.+)\)$/)
			{
			# type
			$calendar[$lcf]->type('external');
			printLC ($log, " Type: external\n"); # miscUtils.pl

			# parse our a clean name and (presumably) URL from the foldername
			printLC ($log, " Name: $1\n");
			$calendar[$lcf]->name($1);
			printLC ($log, " URL: $2\n");
			$calendar[$lcf]->url($2);
			
			# update counter, don't worry about number of events. I don't necessarily believe what Zimbra reports about external calendars
			$externalCount++;			
		
			}
		
		else
			{
			# type
			$calendar[$lcf]->type('owned');
			printLC ($log, " Type: owned\n"); # miscUtils.pl

			# update counter
			if($calendarsCounts{$sfn} > 0)
				{$ownedCount++;}
			else
				{$ownedEmptyCount++;}
			# Zimbra ID number of the folder
			$calendar[$lcf]->id($calendarsIDs{$sfn});
			printLC ($log, " ID: $calendarsIDs{$sfn}\n"); # miscUtils.pl
			# URL to the folder using the ID number (does not include fmt and csvfmt parameters)
			my $url = "http://zimbra.saintmarys.edu/user/$u/?id=$calendarsIDs{$sfn}";
			$calendar[$lcf]->url($url);
			printLC ($log, " URL: $url\n"); # miscUtils.pl
			
			$calendar[$lcf]->ownerUsername($u);
			
			} # else, if($sfn =~ /.*\((\w+)\@saintmarys.edu:(\d+)\)/)

		# output filename
		my $temp = $sfn;
		# change all slashes to dashes
		$temp =~ s/\//-/g;
		# remove leading spaces
		$temp =~ s/^\s+//;
		# remove trailing spaces
		$temp =~ s/\s+$//;
		# change spaces to underscores
		$temp =~ s/\s/_/g;
		# remove single-quotes
		$temp =~ s/'//g;
		# remove double-quotes
		$temp =~ s/"//g;
		# change caret ^ to _
		$temp =~ s/\^/_/g;
		# munge subscribed folder
		# e.g. at this point we'd have Kathy_Hausmanns_Cool_People_(khausman@saintmarys.edu:72501)
		#      the result should be Kathy_Hausmanns_Cool_People(khausman)
		$temp =~ s/_?\((.+)\@saintmarys\.edu:\d+\)/($1)/;
	
		# avoid filename collisions by checking for existing filenames in the array
		my $exportFilenameRoot = zimbra_determineUniqueFolderName($temp,\@usedExportNames);
		$calendar[$lcf]->exportFilenameRoot($exportFilenameRoot);
		printLC ($log, " Filename Root: $exportFilenameRoot\n"); # miscUtils.pl

		# construct export names from the root
		my $exportFilename = $exportFilenameRoot . '.ics';
		$calendar[$lcf]->exportFilename($exportFilename);
		printLC ($log, " Export Filename: $exportFilename\n"); # miscUtils.pl

		if(($calendar[$lcf]->count() > 0) && ($calendar[$lcf]->type() eq 'owned'))
			{
			# download the calendar
			if(!zimbra_exportCalendar($log,$u,$calendar[$lcf]->url(),$calendar[$lcf]->exportFilename()))
				{
				printLC ($log, " CANNOT PROCCESS CALENDAR. Skipping...\n"); # miscUtils.pl
				next;
				}
			# analyze (non-empty) calendar and generate report to user (stored in msgHTML in struct)
			zimbra_analyzeCalendarExport($log,$ad, $outputDir,$calendar[$lcf]);

			} # if($calendar[$lcf]->count() > 0)
		else
			{
			# nothing to download
			printLC ($log, " Empty calendar. Skipping...\n"); # miscUtils.pl		
			} # else, if($calendar[$lcf]->count() > 0)
		} # foreach my $sfn (@sortedFolderNames)

	# construct the HTML email message	
	$messageHTML = <<END_OF_HTML1;
<html lang="en">
<head>
	<meta charset="utf-8" />
	<title>Calendar Export Report</title>
	<meta name="generator" content="BBEdit 10.5" />
</head>
<body style="word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space; font: .75em 'Lucida Grande', Lucida, Verdana, sans-serif">
<img src="http://sites.saintmarys.edu/~hd/googleapps.jpeg" width="475" height="68" alt="googleapps">
<h2><img src="http://sites.saintmarys.edu/~hd/zimbralogo.jpeg" width="100" height="23" alt="zimbralogo"><span style="color: green">Zimbra Calendar Export</span></h2>
<h3>Export Report for user <span style="color:#444"><strong>$u</strong></span></h3>
<hr align="left">
<p>Your calendars from Zimbra were exported as ICS files and have been sent as attachments with this message.
<br>
For instructions on how to import these contacts into Google Apps, please	
visit <a href="https://sites.google.com/a/saintmarys.edu/googleapps/zimbra-imports" target="_blank">Importing Zimbra Calendars and Contacts into Google</a>.
<br>
(You will need to be logged into your Google Apps account to access these instructions.)</p>
<p>If you do not wish to import any of your calendars from Zimbra into Google Apps, you can simply ignore or delete this message.</p>
<p>Specific information about Google Calendar, including sharing calendars and calendar delegation, can be found <a href="https://sites.google.com/a/saintmarys.edu/googleapps/your-first-days-2" target="_blank">here</a>.</p>
<p>If you have shared a calendar in Zimbra with someone, and you are unsure which permission settings you should use in Google, here is a comparison of what the Zimbra settings were to what the Google settings are:
    <ul>
    	<li>A Zimbra <em>Viewer</em> is the same as <em>See all event details</em> access in Google</li>
    	<li>A Zimbra <em>Manager</em> is the same as <em>Make changes to events</em> access in Google</li>
    	<li>A Zimbra <em>Admin</em> is the same as <em>Make changes AND manage sharing</em> access in Google</li>
    	<li>Zimbra had an option for <em>Public (view only, no password required)</em> sharing. In Google, you can <em>Make this calendar public</em> but it only allows others to <em>See only free/busy (hide details)</em>.</li>
    	<li>Zimbra had an option for <em>External guests (view only)</em> sharing. In Google, you can share a calendar with specific non-saintmarys addresses, but they will only be able to <em>See only free/busy (hide details)</em>.

    </ul>
</p>
END_OF_HTML1

	# owned, non-empty calendars
	if($ownedCount > 0)
		{
		$messageHTML .= "<hr align=\"left\">\n";
		$messageHTML .= "<h3>Calendars Created By You</h3>\n";
		$messageHTML .= "<p>The following calendars created by you have been found in Zimbra and were exported.</p>\n";
		$messageHTML .= "<p>These calendars have been sent as attachments to this message.</p>\n";
		$messageHTML .= "<ol>\n";
		foreach my $theC (@calendar)
			{
			if(($theC->type() eq 'owned') && ($theC->count() > 0))
				{
				$messageHTML .= $theC->msgHTML();
				}
			}
		$messageHTML .= "</ol>\n";
		} # if($ownedCount > 0)

	# subscribed, non-empty calendars
	if($subscribedCount > 0)
		{
		$messageHTML .= "<hr align=\"left\">\n";
		$messageHTML .= "<h3>Calendars Created and Shared by Others</h3>\n";
		$messageHTML .= "<p>The following <em>shared</em> calendars have been found in Zimbra. These were created and shared with you by another user.<br>You should ask the owners to share their calendars with you after they have imported them or re-created them in Google Apps.</p>\n";
		$messageHTML .= "<p>Specific information about Google Calendar, including sharing calendars and calendar delegation, can be found <a href=\"https://sites.google.com/a/saintmarys.edu/googleapps/your-first-days-2\" target=\"_blank\">here</a>.</p>\n";
		$messageHTML .= "<ol>\n";
		foreach my $theC (@calendar)
			{
			if(($theC->type() eq 'subscribed') && ($theC->count() > 0))
				{
				# clean up any owner information from the name we send to the user
				my $temp = $theC->name();
				$temp =~ s/ \(.+\@saintmarys\.edu:\d+\)$//;
				$messageHTML .= '<li><strong>' . $temp . "</strong></li>\n";
				}
			}
		$messageHTML .= "</ol>\n";
		} # if($subscribedCount > 0)


	# external calendars
	if($externalCount > 0)
		{
		$messageHTML .= "<hr align=\"left\">\n";
		$messageHTML .= "<h3>Calendars Created and Shared by Others ON OTHER SERVICES</h3>\n";
		$messageHTML .= "<p>The following <em>shared</em> calendars have been found in Zimbra. These were created and shared with you by another user on a service <em>external to Zimbra</em>.<br>You <em>may</em> be able to re-subscribe to them in Google Apps. You may need to ask the owners to share their calendars with you again.</p>\n";
		$messageHTML .= "<p>Specific information about Google Calendar, including sharing calendars and calendar delegation, can be found <a href=\"https://sites.google.com/a/saintmarys.edu/googleapps/your-first-days-2\" target=\"_blank\">here</a>.</p>\n";
		$messageHTML .= "<ol>\n";
		foreach my $theC (@calendar)
			{
			if($theC->type() eq 'external')
				{
				$messageHTML .= '<li><strong>' . $theC->name() . '</strong><br>URL: ' . $theC->url() . "</li><br>\n";
				}
			}
		$messageHTML .= "</ol>\n";
		} # if($subscribedCount > 0)


	# owned, empty calendars
	if($ownedEmptyCount > 0)
		{
		$messageHTML .= "<hr align=\"left\">\n";
		$messageHTML .= "<h3>Empty Calendars</h3>\n";
		$messageHTML .= "<p>The following empty calendars created by you have been found in Zimbra. They contain no data and were not exported.</p>\n";
		$messageHTML .= "<ol>\n";
		foreach my $theC (@calendar)
			{
			if(($theC->type() eq 'owned') && ($theC->count() == 0))
				{
				$messageHTML .= '<li><strong>' . $theC->name() . "</strong></li>\n";
				}
			}
		$messageHTML .= "</ol>\n";
		} # if($ownedEmptyCount > 0)

	# subscribed, empty calendars
	if($subscribedEmptyCount > 0)
		{
		$messageHTML .= "<hr align=\"left\">\n";
		$messageHTML .= "<h3>Empty Calendars Created by Others</h3>\n";
		$messageHTML .= "<p>The following empty <em>shared</em> calendars have been found in Zimbra. They contain no data and were not exported.</p>\n";
		$messageHTML .= "<ol>\n";
		foreach my $theC (@calendar)
			{
			if(($theC->type() eq 'subscribed') && ($theC->count() == 0))
				{
				# clean up any owner information from the name we send to the user
				my $temp = $theC->name();
				$temp =~ s/ \(.+\@saintmarys\.edu:\d+\)$//;
				$messageHTML .= '<li><strong>' . $temp . "</strong></li>\n";
				}
			}
		$messageHTML .= "</ol>\n";
		} # if($subscribedEmptyCount > 0)

	} # if(scalar(keys(%calendarsCounts)) > 0 )
else
	{
	# no contacts folders found
	printLC ($log, "No contacts folders found.\n"); # miscUtils.pl
	# email user advising them of this?
	# evidently every user has at least one ('Calendar')

	}




$messageHTML .= <<END_OF_HTML2;
<br>
<hr align="left">
<p><em>This message is generated automatically by software.</em></p>
<p>Specific information about Google Calendar, including sharing calendars and calendar delegation, can be found <a href="https://sites.google.com/a/saintmarys.edu/googleapps/your-first-days-2" target="_blank">here</a>.</p>
<p>If you have any questions or problems, please consult <a href="https://sites.google.com/a/saintmarys.edu/googleapps/" target="_blank">Saint Mary's College online Google Apps documentation</a>.</p>
<hr align="left">
<div style="color: #666; font-size: 80%;">
<p><em>Export software written by Steve Hideg</em><br>&copy;2013, Saint Mary's College, Notre Dame, IN</p>
</div>
</body>
</html>
END_OF_HTML2

my $recipient = $u . '@saintmarys.edu';

printLC ($log, "\nSending email report to $recipient from $sender\n"); # miscUtils.pl
my $message = MIME::Lite->new
	(
	Subject => "Zimbra Calendar Export: $u",
	From 	=> $sender,
	To		=> $recipient,
	Bcc		=> 'beta@gmigration.saintmarys.edu',
	Type	=> 'text/html',
	Data	=> $messageHTML
	);

# attach the exported calendars
foreach my $c (@calendar)
	{
	# only non-empty owned calendars
	if (($c->count() > 0) && ($c->type() eq 'owned'))
		{
		my $attPath = "$outputDir/" . $c->exportFilename();
		my $attName = $c->exportFilename();
		$message->attach(
			Type => 'text/plain',
			Path => $attPath,
			Filename => $attName,
			Disposition => 'attachment'
			);
		} # if ($c->count() > 0)
	} # foreach my $c (@contactsFolder)

	$message->send();  




} # sub zimbra_exportCalendars
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# zimbra_exportCalendar
#
# Using the curl command, exports a calendar in iCalendar format:
#  For the specified user $u,
#  At the specified URL $folderURL,
#  Redirecting it to a file $exportFolderName in a directory for the user $u
#--------------------------------------------------------------------/

sub zimbra_exportCalendar {

my $log = shift;
my $u = shift;
my $folderURL = shift;
my $exportFolderName= shift;

# define a path for the exported data
my $outputPath = "$ZIMBRA_EXPORT_USERS/$u/$exportFolderName";

printLC($log, " Exporting $folderURL\n   to $outputPath\n"); # miscUtils.pl

# construct the command
#	http://wiki.zimbra.com/wiki/ZCS_6.0:Zimbra_REST_API_Reference:Get_Calendar
# Assumes the URL comes in with an ID parameter (e.g. ?id=72510), so our parameters
# are appended with an ampersand &
my $URL = "$folderURL&fmt=ics";
printLC($log, "  URL: $URL\n"); # miscUtils.pl


my $cmd = "curl -s -S -u $u:LOCALZIMBRAPASSWORD \"$URL\" > \"$outputPath\"";
#print "\nusing $cmd\n";

open (RESP, "$cmd |") or die "Can't run command: $!\n";

my $response;
while(<RESP>)
	{
	chomp;
	$response .= $_;
	}
close RESP;

if((defined($response)) && ($response ne ''))
	{
	printLC($log, " $response\n"); # miscUtils.pl
	return 0;
	}
else
	{
	printLC($log, " Done\n"); # miscUtils.pl
	return 1;
	}



} # sub zimbra_exportCalendar
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# zimbra_analyzeCalendarExport
#
# Analyze the specified calendar.
# Put the resulting HTML-formatted report into the msgHTML member of
# the specified struct
#--------------------------------------------------------------------/

sub zimbra_analyzeCalendarExport {

my $log = shift;
my $ad = shift;
# containing folder
my $outputDir= shift;
# calendar struct
my $c = shift;

# temporary holder for msgHTML
my $mh = '';

# clean up any owner information from the name we send to the user
my $temp = $c->name();
printLC ($log, " Analyzing $temp\n"); # miscUtils.pl
$temp =~ s/ \(.+\@saintmarys\.edu:\d+\)$//;
printLC ($log, " Cleaned name: $temp\n"); # miscUtils.pl

$mh .= '<li><strong>' . $temp . "</strong>\n";

if($temp =~ /^zmail_/)
	{
	$mh .= "<br>Note: <em>This calendar was transfered in 2010 during our emergency switchover between Zimbra servers due to weather-related server damage and likely contains legacy data</em>\n";
	}
elsif($temp =~ /^aegis_/)
	{
	$mh .= "<br>Note: <em>This calendar was transfered in 2007 during our switchover from the Aegis (iPlanet) messaging server and Zimbra, and likely contains legacy data</em>\n";
	}

$mh .= " <ul>\n";
if($c->type() eq 'owned')
	{
	$mh .= ' <li><strong>Exported as: </strong>' . $c->exportFilename() . " <em>(See attachment)</em></li>\n";
	}
$mh .= ' <li><strong>Number of Entries: </strong>' . $c->count() . "</li>\n";

# if this folder is subscribed, list the owner of the folder
if($c->type() eq 'subscribed')
	{
	$mh .= ' <li><strong>Owner: </strong>' . $c->ownerUsername() . '@saintmarys.edu';
	if(defined($c->ownerDisplayName()))
		{
		$mh .= ' (' . $c->ownerDisplayName() . ')';
		}
	$mh .= "</li>\n";
	}
else
	{
	# folder is owned, see if it is shared with anyone
 	my $gh = zimbra_findShareGrants($log,$ad,$c);

 	if($gh ne '')
 		{
 		$mh .= " <li><strong>Share Grants: </strong>\n";
 		$mh .= " <br>This calendar has been shared with other users.\n";
 		$mh .= "  <ul style=\"list-style-type: none;\">\n";
 		$mh .= $gh;
 		$mh .= "  </ul>\n";
 		$mh .= " </li>\n";
 		}
	}

$mh .= " </ul>\n";
$mh .= "</li><br>\n";

# set this calendar object's msgHTML member
$c->msgHTML($mh);

} # zimbra_analyzeCalendarExport 
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# zimbra_findShareGrants
#
# Look for share grants of the specified folder and report them back
# as a series of <li></li> tags
#
# Grant data comes the zmmailbox command in a form like this:
# Permissions      Type  Display
# -----------  --------  -------
#           r   account  woo@saintmarys.edu
#       rwidx   account  blah@saintmarys.edu
#      rwidxa   account  frosh@saintmarys.edu
#           r    public  
#          rp     guest  wee@mac.com
#           r     guest  boo@mac.com
#
#--------------------------------------------------------------------/

sub zimbra_findShareGrants {

my $log = shift;
my $ad = shift;
my $cf = shift;

my $name = $cf->name();
my $owner = $cf->ownerUsername();

my $path = "/$name";

# construct the command
my $cmd = sprintf("%s '%s -z-m \"%s\@saintmarys.edu\" gfg \"%s\"' 2>&1",$ZIMBRA_SSH,$ZMMAILBOX,$owner,$path);

my $result = `$cmd`;

if($result =~ /ERROR/)
	{
	printLC($log, "  zimbra_findShareGrants: $result\n");
	return '';
	}




my @lines = split /\n/,$result;
# first two lines are header and separator
shift @lines;
shift @lines;

# html containing grants
my $gh = '';
foreach (@lines)
	{
	printLC($log, "  $_\n");
	}

# see if this calendar is public
foreach my $l (@lines)
	{
	$l =~ s/^\s+//;
	my ($perm,$type,$disp) = split /\s+/,$l;
	if(lc($type) eq 'public')
		{
		printLC($log, "  Calendar has been publicly shared.\n");
		$gh .= "<em>This calendar was publicly shared on Zimbra.</em>\n";
		}
	}

# get saintmarys.edu grants
foreach my $l (@lines)
	{
	$l =~ s/^\s+//;
	my ($perm,$type,$disp) = split /\s+/,$l;
	if(lc($type) eq 'account')
		{
		my $subscriberDisplayName = '';
		my ($subScriberUsername,$crap) = split('@',$disp);
		if(!($subscriberDisplayName = exportAD_geSingleValuedAtt($ad,$log,$subScriberUsername,'displayName'))) # exportAdUtils
			{
			# if the owner's AD object doesn't have a displayName, try to get it from Zimbra
			$subscriberDisplayName = zimbra_getDisplayName($subScriberUsername); # zimbraUtils.pl
			}
		# interpret the permissions
		my $permissions = '';
		if(lc($perm) eq 'r')
			{$permissions = 'Viewer';}
		elsif(lc($perm) eq 'rwidx')
			{$permissions = 'Manager';}
		elsif(lc($perm) eq 'rwidxa')
			{$permissions = 'Admin';}
		printLC($log, "  Calendar shared with $type $disp - $subscriberDisplayName: $perm - $permissions.\n");
		$gh .= "<li>$disp - $subscriberDisplayName: <em>$permissions</em></li>\n";
		}
	}

# get guest grants
foreach my $l (@lines)
	{
	$l =~ s/^\s+//;
	my ($perm,$type,$disp) = split /\s+/,$l;
	if(lc($type) eq 'guest')
		{
		printLC($log, "  Calendar shared with $type $disp.\n");
		$gh .= "<li>$disp: <em>External Guest</em></li>\n";
		}
	}



return $gh;


} # sub zimbra_findShareGrants
#--------------------------------------------------------------------/




#--------------------------------------------------------------------\
# zimbra_getSignatures
#
# Look for all signatures using zmmailbox zmmailbox -z -m <user> gsig -v
#
# Extract them from the JSON output
#
#--------------------------------------------------------------------/

sub zimbra_getSignatures {

my $log = shift;
my $u = shift;

# construct the command
my $cmd = sprintf("%s '%s -z-m \"%s\@saintmarys.edu\" gsig -v' 2>&1",$ZIMBRA_SSH,$ZMMAILBOX,$u);

my $result = `$cmd`;

my $sigHTML = '';

if($result =~ /ERROR/)
	{
	printLC($log, " zimbra_getSignatures: $result.\n");
	return '';
	}
else
	{
	my $json = JSON->new->utf8;
	my @sigObjects = @{$json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode( $result )};

	if(scalar(@sigObjects))
		{
		# iterate through the signature objects
		foreach my $so (@sigObjects)
			{
			printLC($log, "\n Found signature: \"$so->{'name'}\"\n");
			printLC($log, "            Type: $so->{'type'}\n");
			printLC($log, "           Value: \n$so->{'value'}\n");
			
			$sigHTML .= '<h4 style="margin-left: 2em; margin-top: 2em">Signature &quot;' . $so->{'name'} . "&quot;:</h4>\n";
			if(lc($so->{'type'}) eq 'text/plain')
				{
				# convert text/plain signatures into HTML by changing \n into <br>
				$so->{'value'} =~ s/\n/<br>/g;
				}
			$sigHTML .= '<div style="margin-left: 3em;">' . "\n";
			$sigHTML .= "$so->{'value'}\n";
			$sigHTML .= "</div>\n";
			} # foreach my $so (@sigObjects)
		} # if(scalar(@sigObjects))
	}

return $sigHTML;

} # sub zimbra_getSignatures
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# zimbra_reportSignatures
#
# Get signatures from Zimbra. 
# If the account has any, report them to user in HTML formatted email
#--------------------------------------------------------------------/

sub zimbra_reportSignatures {

my $log = shift;
my $u = shift;
my $sender = shift;


# Get the signature from Zimbra
printLC($log, " Getting signatures...\n");
if(my $signatureHTML = zimbra_getSignatures($log,$u))
	{


	# construct the HTML email message	
	my $messageHTML = <<END_OF_HTML1;
<head>
	<meta charset="utf-8" />
	<title>Zimbra Signature Information</title>
	<meta name="generator" content="BBEdit 10.5" />
</head>
<body style="word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space; font: .75em 'Lucida Grande', Lucida, Verdana, sans-serif">
<img src="http://sites.saintmarys.edu/~hd/googleapps.jpeg" width="475" height="68" alt="googleapps">
<h2><img src="http://sites.saintmarys.edu/~hd/zimbralogo.jpeg" width="100" height="23" alt="zimbralogo"><span style="color: #36a">Zimbra Signature Information</span></h2>
<h3>Zimbra Signature for user <span style="color:#444"><strong>$u</strong></span></h3>
<hr align="left">
<p>Email signatures were detected for your account on Zimbra. They are displayed below.</p>
<p>Specific information about Gmail, including creating signatures and filtering messages, can be found <a href="https://sites.google.com/a/saintmarys.edu/googleapps/your-first-days-1" target="_blank">here</a>.
<br>
(You will need to be logged into your Google Apps account to access these instructions.)</p>
</p>
<hr align="left">
<h3>Signatures found:</h3>
END_OF_HTML1

	$messageHTML .= $signatureHTML;

	$messageHTML .= <<END_OF_HTML2;
<br>
<p>If you wish to use one of these signatures, you can copy it then edit your Google Apps signature. Specific information about Gmail, including creating signatures and filtering messages, can be found <a href="https://sites.google.com/a/saintmarys.edu/googleapps/your-first-days-1" target="_blank">here</a>.</p>
<hr align="left">
<p><strong>Note:</strong> We are unable to export any graphics or pictures that you may have had in your signature. You can add them to your signature in Google Apps using the tools provided by Google.</p>
<hr align="left">
<div style="color: #666; font-size: 80%;">
<p><em>Software written by Steve Hideg</em><br>&copy;2013, Saint Mary's College, Notre Dame, IN</p>
</div>
</body>
</html>
END_OF_HTML2

my $recipient = $u . '@saintmarys.edu';
### DEVELOPMENT/DEBUG
#my $recipient = 'frosh@saintmarys.edu';

printLC ($log, "\nSending email report to $recipient from $sender\n"); # miscUtils.pl
my $message = MIME::Lite->new
	(
	Subject => "Zimbra Signature Info: $u",
	From 	=> $sender,
	To		=> $recipient,
	Bcc		=> 'beta@gmigration.saintmarys.edu',
	Type	=> 'text/html',
	Data	=> $messageHTML
	);

	$message->send();  
	
	} # if(my $signatureHTML = zimbra_getSignatures($log,$u))
else
	{
	printLC ($log, " No signature found.\n"); # miscUtils.pl
	}


} # sub zimbra_reportSignatures
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# zimbra_setAccountStatus
#
# Set the zimbraAccountStatus for the specified account to the specified value
# active|locked|closed|maintenance
#--------------------------------------------------------------------/

sub zimbra_setAccountStatus {

my ($log,$u,$acctStatus) = @_;

# construct the command
my $cmd = sprintf("%s '%s ma \"%s\@saintmarys.edu\" zimbraAccountStatus %s'",$ZIMBRA_SSH, $ZMPROV, $u, $acctStatus);

my $result = `$cmd`;

printLC($log, " $result\n");


} # sub zimbra_setAccountStatus
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# zimbra_forwardToGmigration
#
# Forward mail for the specified account to gmigration.saintmarys.edu
# and set it not to keep local copies
#--------------------------------------------------------------------/

sub zimbra_forwardToGmigration {

my ($log,$u) = @_;

# construct the forwarding command
my $cmd = sprintf("%s '%s ma \"%s\@saintmarys.edu\" zimbraPrefMailForwardingAddress  %s\@gmigration.saintmarys.edu'",$ZIMBRA_SSH, $ZMPROV, $u, $u);
printLC($log, " Forwarding to $u\@gmigration.saintmarys.edu\n");
my $result = `$cmd`;
printLC($log, " $result\n") if ($result ne '');

# construct the disable local delivery command
$cmd = sprintf("%s '%s ma \"%s\@saintmarys.edu\" zimbraPrefMailLocalDeliveryDisabled TRUE'",$ZIMBRA_SSH, $ZMPROV, $u);
printLC($log, " Disabling local delivery\n");
$result = `$cmd`;
printLC($log, " $result\n") if ($result ne '');


} # sub zimbra_forwardToGmigration
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# return value
1;
#--------------------------------------------------------------------/
