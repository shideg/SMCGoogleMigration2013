#!/usr/bin/perl -w

#--------------------------------------------------------------------\
# adUtils.pl
#
# Set of subroutines for accessing Active Directory via LDAP
#
# Written by Steve HIdeg <hideg@saintmarys.edu>
#
# May 2011
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

use Net::LDAP;
use Net::LDAP::Util qw( ldap_error_name ldap_error_text);
use Net::LDAPS;

#--------------------------------------------------------------------\
# AD_setupAdminLDAPS
#
# Subroutine to set up administrative LDAPS connection to the directory server adsmc03
#
#--------------------------------------------------------------------/

sub AD_setupAdminLDAPS {

my $dirServerName = 'adsmc03.saintmarys.edu';
my $dirAdminName = '***REDACTED***';
my $dirAdminPass = '**********';


my $ldap = Net::LDAPS->new($dirServerName, 
							version => 3,
							port => 636,
							verify => 'none' ) or die "$@";

my $mesg = $ldap->bind($dirAdminName,
							password => $dirAdminPass,
							version => 3) or die "$@";

my $code = $mesg->code;

if($code)
        {die "LDAP bind: ",ldap_error_name($code),"\n";}

return $ldap;

}
#--------------------------------------------------------------------/
#--------------------------------------------------------------------\
# AD_setupAdminLDAP
#
# Subroutine to set up administrative LDAP connection to adsmc01
#
#--------------------------------------------------------------------/

sub AD_setupAdminLDAP {

my $zldap = Net::LDAP->new("adsmc02.saintmarys.edu") or die "$@";

my $mesg = $zldap->bind('zzadpeopleadmin@saintmarys.edu',
					password => "**********",
					version => 3) or die "$@";

my $code = $mesg->code;

if($code)
	{die "AD LDAP bind: ",ldap_error_name($code),"\n";}

return $zldap;

}
#--------------------------------------------------------------------/
#--------------------------------------------------------------------\
# AD_setupLDAP
#
# Subroutine to set up the LDAP connection to adsmc01
#
# NOTE: This routine does NOT perform a bind operation
#
#--------------------------------------------------------------------/

sub AD_setupLDAP {

my $ldap = Net::LDAP->new("adsmc02.saintmarys.edu") or die "$@";


return $ldap;

}
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# AD_LDAPsearch
#
# Subroutine for basic LDAP search
# (from Net::LDAP::Examples perldocexamplespod)
#
#--------------------------------------------------------------------/

sub AD_LDAPsearch {

my ($ldap,$searchString,$attrs,$base) = @_;


# set a base dn if none was provided
if (!$base)
	{$base='ou=People,dc=saintmarys,dc=edu';}

# set up a list of attributes if none is passed
if (!$attrs)
	{$attrs = ['cn','mail'];}

my $result = $ldap->search (
						base => $base,
						scope => 'sub',
						filter => "$searchString",
						attrs => $attrs);

return $result;
}
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# AD_ldap_simpleBind
#
# Subroutine to perform a simple bind operation
#
# Can be used for authentication alone or for accessing the directory
# returns 1 (true) if bind succeeded, returns 0 (false) otherwise
# (including connection errors)
#
#--------------------------------------------------------------------/

sub AD_ldap_simpleBind {

my ($ldap,$user,$password) = @_;

my $bindDN = "$user\@saintmarys.edu";

if (my $mesg = $ldap->bind($bindDN,
					password => $password,
					version => 3))
	{
	my $code = $mesg->code;
	if($code)
		{
		return 0;
		}
	else
		{
		return 1;
		}
	}
else
	{
	return 0;
	}
}

#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# AD_replaceSingleValuedAttOfEntry
#
# Subroutine to replace the value of a specified single-valued 
# attribute of specified entry in AD
#
# Assumes we are passed a valid found entry from an LDAP search in AD.
# Assumes we are passed an ldap object that has write privileges to the entry.
#--------------------------------------------------------------------/

sub AD_replaceSingleValuedAttOfEntry {

my $ad = shift;
my $entry = shift;
my $attName = shift;
my $newAttValue = shift;
my $ldapMessageRef= shift;

$entry->replace($attName => $newAttValue);
my $mesg = $entry->update($ad);
if($mesg->code)
	{
	$$ldapMessageRef = ldap_error_name($mesg->code);
	return 0;
	}
else
	{
	return 1;
	}



} 
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# AD_ldap_addAcctDescValue
#
# Assumes that a successful bind operation has already taken place
#
#--------------------------------------------------------------------/

sub AD_ldap_addAcctDescValue {

my ($ldap,$uid,$servicename,$message) = @_;

my $LDAPfilter = "(uid=$uid)";

my @Attrs = ('displayName');

my $result = AD_LDAPsearch($ldap,$LDAPfilter,\@Attrs);


if($result->count == 1)
	{
		
	my $entry = $result->entry(0);
	
	my $logEntry = smcEduAcctDescLogEntryNow($servicename,$message);
	
	
	$entry->add('smcEduAcctDesc' => $logEntry);

	my $uresult = $entry->update($ldap);
	
	if($uresult->code)
		{
		return ldap_error_name($uresult->code);
		}
	else
		{
		return 'OK';
		}
	}
else
	{
	return "unique entry not found";
	}
		

}
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# smcEduAcctDescLogEntryNow
#
# Subroutine to format text for inclusion into the attribute 
# smcEduAcctDesc as a log entry
#
# Calling sequence:
#  my $logEntry = smcEduAcctDescLogEntry("servicename","message");
#
#--------------------------------------------------------------------/

sub smcEduAcctDescLogEntryNow {

	my $serviceName = shift;
	my $message = shift;
	
	# get the current date and time
	my ($sec,$min,$hour,$mday,$month,$year) = (localtime)[0,1,2,3,4,5];
	$year += 1900;
	$month++;
	
	return sprintf("%s: %d-%02d-%02d %02d:%02d:%02d %s",$serviceName,$year,$month,$mday,$hour,$min,$sec,$message);

}
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# ad_getExistingAccountInfo
#
# Subroutine to populate hash references with all PIDMs, CNs, and mail
# addresses  found in 
# objects in OU=People
# 
# Calling sequence:
#  ad_getExistingAccountInfo($ad,\%existingPIDM,\%existingCN,\%existingMail);
#
#--------------------------------------------------------------------/

sub ad_getExistingAccountInfo {

my $ad = shift;
my $pidmRef = shift;
my $cnRef = shift;
my $mailAddRef = shift;

# define a filter
# since we need all usernames, we'll simply search for all objects
my $adFilter = '(sAMAccountName=*)';

# attributes to return
# need the cn and PIDM
my @Attrs = ('cn','smcEduPIDM','proxyAddresses');

# base DN
my $baseDN = 'OU=People,DC=saintmarys,DC=edu';

# perform the search
my $result = AD_LDAPsearch($ad,$adFilter,\@Attrs,$baseDN);
if($result->code)
	{
	my $code = $result->code;
	die "AD Search Error $code: ",ldap_error_name($result->code),"\n";
	}
elsif($result->count == 0)
	{
	die "AD Search Error: No user objects found\n";
	}

my $count = $result->count;

for (my $i=0; $i<$count; $i++)
	{
	my $entry = $result->entry($i);
	my $dn = $entry->dn;
	my $cn = $entry->get_value('cn');
	my $pidm = $entry->get_value('smcEduPIDM');
	my @pas = $entry->get_value('proxyAddresses');

	$$cnRef{$cn} = 1;
	$$pidmRef{$pidm} = $cn if defined($pidm);

	# proxyAddresses is multi-valued, so we have to check an array
	foreach my $pa (@pas)
		{
		# general format:
		# SMTP: hideg@saintmarys.edu
		# smtp: steve@saintmarys.edu
		# extract the address portion from the email (before the @)
		# we must be careful because some entries are in there without the SMTP: or smtp: prefix
		if(($pa =~ /^SMTP:(.+)@.+/i) || ($pa =~ /^(.+)@.+/i))
			{
			$$mailAddRef{$1} = 1;
			}
		}

	} # for (my $i=0; $i<$count; $i++)



}
#--------------------------------------------------------------------/


#===============================================================================
# Special GoogleApps-specific functions


#--------------------------------------------------------------------\
# addDNtoGoogleAppsUsers
#
# Subroutine to add designated DN to the member attribute of
# the secondary user group GoogleAppsUsers
#
# Membership in GoogleAppsUsers indicates that the account has been
# provisioned in Google Apps
#
#--------------------------------------------------------------------/
sub addDNtoGoogleAppsUsers {

my $ad = shift;
my $userDN = shift;

my $filter = '(CN=GoogleAppsUsers)';
my $baseDN = 'OU=SecondaryUserGroups,OU=Groups,DC=saintmarys,DC=edu';
my @Attrs = ('member');

my $result = AD_LDAPsearch($ad,$filter,\@Attrs,$baseDN);

if($result->code())
	{
	return "Error: " . ldap_error_name($result->code());
	}
if($result->count != 1 )
	{
	return 'Error: ' . $result->count() . ' entries found.';
	}

my $e = $result->entry(0);

my @members = $e->get_value('member');

foreach my $m (@members)
	{
	if (lc($m) eq lc($userDN))
		{
		# nothing to do
		return 'ok';
		}
	}

# if we made it here, we can add this DN to the member attribute
$e->add ( 'member' => $userDN);

my $updateResult = $e->update($ad);
if($updateResult->code())
	{
	return 'Error: ' . ldap_error_name($updateResult->code());
	}

return 'ok';

} # sub addDNtoGoogleAppsUsers        
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# dnIsGoogleAppsUserMember
#
# Subroutine to see if designated DN is a member of
# the secondary user group GoogleAppsUsers
#
#--------------------------------------------------------------------/
sub dnIsGoogleAppsUserMember {

my $ad = shift;
my $userDN = shift;

# username is unique. DN could change if user objects are moved.
# I don't know if AD is smart enough to update group membership lists
my $u = '';
# Note: \S+? is supposed to be non-greedy 
if($userDN =~ /CN=(\S+?),OU=.+/i)
	{
	$u = $1;
	}


my $filter = '(CN=GoogleAppsUsers)';
my $baseDN = 'OU=SecondaryUserGroups,OU=Groups,DC=saintmarys,DC=edu';
my @Attrs = ('member');

my $result = AD_LDAPsearch($ad,$filter,\@Attrs,$baseDN);

if($result->code())
	{
	return "Error: " . ldap_error_name($result->code());
	}
if($result->count != 1 )
	{
	return 'Error: ' . $result->count() . ' entries found.';
	}

my $e = $result->entry(0);

my @members = $e->get_value('member');

foreach my $m (@members)
	{
	# Note: \S+? is supposed to be non-greedy 
	$m =~ /CN=(\S+?),OU=.+/i;
	my $mu = $1;
	if (lc($mu) eq lc($u))
		{
		return 1;
		}
	}

return 0;

} # sub dnIsGoogleAppsUserMember        
#--------------------------------------------------------------------/



#--------------------------------------------------------------------\
# getEmailAliases
#
# Subroutine to extract any email aliases from the proxyAddresses
# attribute of the specified entry.
# Primary address should have the prefix SMTP: while aliases should
# have prefix smtp:
#
#--------------------------------------------------------------------/

sub getEmailAliases {
my $entry = shift;

my @pas = $entry->get_value('proxyAddresses');

if(scalar(@pas) == 0)
	{
	return ();
	}

my @aliases = ();
foreach my $pa (@pas)
	{
	if($pa =~ /smtp:(.+\@saintmarys.edu)/)
		{
		push @aliases, $1;
		}
	}
return @aliases;

} # sub getEmailAliases
#--------------------------------------------------------------------/




#--------------------------------------------------------------------\
# return value
1;
#--------------------------------------------------------------------/
