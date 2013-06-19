#!/usr/bin/perl -w
#--------------------------------------------------------------------\
# migrationAcctCheck.pl
#
# Pre-flight a list of accounts to be migrated
# Make sure they aren't migrated already.
# Make sure they have first and last names
#
# Written by Steve Hideg <hideg@saintmarys.edu>
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
migrationAcctCheck version 1, Copyright (C) 2013 Steve Hideg
migrationAcctCheck comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions. See file GPL.txt.

END_OF_GPL_DISCLAIMER

# BE SURE TO ADJUST PATHS TO THESE FOR YOUR OWN ENVIRONMENT
require 'adUtils.pl';


my @usernames = ();

if($#ARGV == -1)
	{
	print "Usage: migrationAcctCheck.pl inputfile\n";
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

my $adBaseDN = 'ou=People,dc=saintmarys,dc=edu';
my @adAttrs = qw(sn givenName memberOf smcEduEmplStatus eduPersonPrimaryAffiliation);

foreach my $u (@usernames)
	{
	my $adFilter = "(cn=$u)";
	my $adResult = AD_LDAPsearch($ad,$adFilter,\@adAttrs,$adBaseDN);

	my $provisioned = '';
	my $migrated = '';

	if($adResult->code)
		{
		print "  ", ldap_error_name($adResult->code),"\n";
		print "  ", ldap_error_text($adResult->code),"\n";
		}
	elsif($adResult->count == 0)
		{
		print " User $u not found\n";
		}
	elsif($adResult->count > 1)
		{
		print $adResult->count, " entries for $u found!\n";
		}
	else
		{
		my $e = $adResult->entry();
		my $sn = $e->get_value('sn') ? $e->get_value('sn') : 'none';
		my $givenName = $e->get_value('givenName') ? $e->get_value('givenName') : 'none';
		my @memberOf = $e->get_value('memberOf');
		foreach my $mo (@memberOf)
			{
			if($mo =~ /GoogleAppsUsers/i)
				{
				$provisioned = 'provisioned';
				}
			elsif($mo =~ /GoogleAppsMigrated/i)
				{
				$migrated = 'migrated';
				}
			}
		my $empStatus = $e->get_value('smcEduEmplStatus') ? $e->get_value('smcEduEmplStatus') : 'unknown';
		my $eppa = $e->get_value('eduPersonPrimaryAffiliation') ? $e->get_value('eduPersonPrimaryAffiliation') : 'unknown';
		my $empStatusQuestionable = 0;
		if($eppa =~ /shared|special/i)
			{
			$empStatusQuestionable = 0;
			}
		elsif(($eppa =~ /unknown/) || ($empStatus =~ /term|unkown/i))
			{
			$empStatusQuestionable = 1;
			}
			

			
# Different logic for different types of accounts
# Definitely a kluge, I know...
#		if(($sn eq 'none') || ($givenName eq 'none') || ($provisioned ne '') || ($migrated ne '') || ($empStatusQuestionable)) # employees
#		if(($sn eq 'none') || ($givenName eq 'none') || ($provisioned ne '') || ($migrated ne '')) # students
		if(($sn eq 'none') || ($givenName eq 'none') || ($migrated ne '')) # students, already provisioned (oops)
			{
#			print "$u\t$givenName\t$sn\t$provisioned\t$migrated\t$eppa\t$empStatus\n"; # employees
			print "$u\t$givenName\t$sn\t$provisioned\t$migrated\t$eppa\n"; # students
			}
		else
			{
			my $zStatus = zimbra_getAccountStatus($u);
			if($zStatus !~ /zimbraAccountStatus: active/)
				{
				print "$u\t$zStatus\n";
				}
			} # else, if(($sn eq 'none') || ($givenName eq 'none') || ($provisioned ne '') || ($migrated ne ''))
		
		
		
		} # else, if($adResult->code)

	}

$ad->unbind();





#--------------------------------------------------------------------\
# zimbra_getAccountStatus
#
# Get the zimbraAccountStatus for the specified account 
#--------------------------------------------------------------------/

sub zimbra_getAccountStatus {

my $u = shift;

# ssh to zimbra box string
my $ZIMBRA_SSH = 'ssh zimbra@zimbra';

# path to the zmprov program
my $ZMPROV = '/opt/zimbra/bin/zmprov';

# construct the command
my $cmd = sprintf("%s '%s ga \"%s\@saintmarys.edu\" zimbraAccountStatus 2>&1'",$ZIMBRA_SSH, $ZMPROV, $u);

my $result = `$cmd`;

my @lines = split("\n",$result);

return $lines[$#lines];

} # sub zimbra_getAccountStatus
#--------------------------------------------------------------------/
