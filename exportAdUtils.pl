#!/usr/bin/perl -w

#--------------------------------------------------------------------\
# exportAdUtils.pl
#
# Set of subroutines for accessing Active Directory via LDAP supporting
# Zimbra data export operations
#
# Written by Steve HIdeg <hideg@saintmarys.edu>
#
# January 2013
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
require 'adUtils.pl';
require 'miscUtils.pl';

#--------------------------------------------------------------------\
# exportAD_determineReportSender
#
# Determine proper sender address for Zimbra export reports
# Students, ex-students, and alumnae should get resnet@saintmarys.edu
# All others should get helpdesk@saintmarys.edu
#
#--------------------------------------------------------------------/

sub exportAD_determineReportSender {

my $ad = shift;		# ldap connection to AD
my $log = shift;	# path to log file
my $u = shift;		# username

my $filter = "(cn=$u)";
my @Attrs = ('edupersonPrimaryAffiliation');

my $adResult = AD_LDAPsearch($ad,$filter,\@Attrs);

if($adResult->code)
	{
	printLC ($log,' exportAD_determineReportSender LDAP error: ' . ldap_error_name($adResult->code) . "\n"); # miscUtils.pl
	printLC ($log,"  Using helpdesk\@saintmarys.edu\n"); # miscUtils.pl
	return 'helpdesk@saintmarys.edu';
	}
elsif($adResult->count == 0)
	{
	printLC ($log," exportAD_determineReportSender error: User $u not found\n"); # miscUtils.pl
	printLC ($log,"  Using helpdesk\@saintmarys.edu\n"); # miscUtils.pl
	return 'helpdesk@saintmarys.edu';
	}
elsif($adResult->count > 1)
	{
	printLC ($log," exportAD_determineReportSender error: " . $adResult->count . " entries for $u found!\n"); # miscUtils.pl
	printLC ($log,"  Using helpdesk\@saintmarys.edu\n"); # miscUtils.pl
	return 'helpdesk@saintmarys.edu';
	}
else
	{
	my $entry = $adResult->entry(0);
	my $eppa = $entry->get_value('edupersonPrimaryAffiliation');
	printLC ($log," EPPA: $eppa\n"); # miscUtils.pl
	if((defined($eppa)) && ($eppa =~/student|alum/i))
		{
		# student, ex-student, alumna
		return 'resnet@saintmarys.edu';
		}
	else
		{
		# all others (including any without a value)
		return 'helpdesk@saintmarys.edu';
		}
	}
} # sub exportAD_determineReportSender
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# exportAD_geSingleValuedAtt
#
# Get the value of specified single-valued attribute for specified user object
# If there is an error, no or multiple objects, log it and return an empty string.
# If the value isn't defined, return an empty string.
#
#--------------------------------------------------------------------/

sub exportAD_geSingleValuedAtt {

my $ad = shift;			# ldap connection to AD
my $log = shift;		# path to log file
my $u = shift;			# username
my $attName = shift;	# name of the single-valued attribute

my $filter = "(cn=$u)";
my @Attrs = ($attName);

my $adResult = AD_LDAPsearch($ad,$filter,\@Attrs);

if($adResult->code)
	{
	printLC ($log,' exportAD_geSingleValuedAtt LDAP error: ' . ldap_error_name($adResult->code) . "\n"); # miscUtils.pl
	return '';
	}
elsif($adResult->count == 0)
	{
	printLC ($log," exportAD_geSingleValuedAtt error: User '$u' not found\n"); # miscUtils.pl
	return '';
	}
elsif($adResult->count > 1)
	{
	printLC ($log," exportAD_geSingleValuedAtt error: " . $adResult->count . " entries for $u found!\n"); # miscUtils.pl
	return '';
	}
else
	{
	my $entry = $adResult->entry(0);
	my $value = $entry->get_value($attName);
	return ((defined($value)) && ($value ne '')) ? $value: '';
	} # else, if($adResult->code)

} # sub exportAD_determineReportSender
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# exportAD_addUsertoGoogleAppsMigrated
#
# Subroutine to add designated user's DN to the member attribute of
# the secondary user group GoogleAppsMigrated
#
# Membership in GoogleAppsMigrated indicates that all migration activities
# for the account have been completed, and the user of the account should 
# use Google Apps instead of local email (Zimbra or Exchange).
#
#--------------------------------------------------------------------/
sub exportAD_addUsertoGoogleAppsMigrated {

my $ad = shift;
my $u = shift;

# first, search for the user and get the DN
my $uFilter = "(cn=$u)";
my $uBaseDN = 'ou=People,dc=saintmarys,dc=edu';
my @uAttrs = ('memberOf');

my $uResult = AD_LDAPsearch($ad,$uFilter,\@uAttrs,$uBaseDN);

if($uResult->code())
	{
	return "Error: " . ldap_error_name($uResult->code());
	}
if($uResult->count != 1 )
	{
	return 'Error: ' . $uResult->count() . ' entries found.';
	}

# see if this user is already a member
my $uEntry = $uResult->entry(0);
# get the (multiple) values of the memberOf attribute
my @memberOf = $uEntry->get_value('memberOf');
foreach my $mo (@memberOf)
	{
	if($mo =~ /GoogleAppsMigrated/i)
		{
		# nothing to do
		return 'ok';
		}
	}

# get the DN of the user to add to the group
my $userDN = $uEntry->dn();

my $filter = '(CN=GoogleAppsMigrated)';
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

} # sub exportAD_addUsertoGoogleAppsMigrated        
#--------------------------------------------------------------------/
