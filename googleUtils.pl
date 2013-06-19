#!/usr/bin/perl -w

#--------------------------------------------------------------------\
# googleUtils.pl
#
# Set of subroutines for management of the saintmarys.edu GoogleApps domain
#
# Written by Steve HIdeg <hideg@saintmarys.edu>
#
# December 2012
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

use Net::Google::AuthSub;


# the Google Apps Manager utilty command
# Uses a later version of Python.
# Append arguments to this and execute via shell
my $GAM = '/usr/bin/python2.6 /home/hideg/bin/gam/gam.py';
my $CUSTOMERID = '**********'; # from gam info domain


#--------------------------------------------------------------------\
# google_Auth
#
# Test authentication to Google Apps for credential verification.
#
# Use Net::Google::AuthSub to authenticate the provided credentials
#
#--------------------------------------------------------------------/

sub google_Auth {

my ($u,$p) = @_;

my $domainUser = $u . '@saintmarys.edu';

my $auth = Net::Google::AuthSub->new;

my $response = $auth->login($domainUser,$p);
if ($response->is_success)
	{
	return 'ok';
	}
else
	{
	return $response->error;
	}


} # sub google_Auth
#--------------------------------------------------------------------/





#--------------------------------------------------------------------\
# parseOU
#
# Parse the first OU part of a user object's DN.
# Assumes that the rest of the DN is ou=People,dc=saintmarys,dc=edu
# If the parsed OU isn't one of the OUs set up in Google, then we
# label it as invalid.
#
#--------------------------------------------------------------------/

sub parseOU {

my $dn = shift;

$dn =~ /cn=[\w|-]+,ou=(.+),ou=People,dc=saintmarys,dc=edu/i;

my $ou = $1;


if($ou !~/Alum|Exstu|Faculty|Retired|Shared|Special|Staff|Student/)
	{
	return "$ou - INVALID OU";
	}
else
	{
	return $ou;
	}


} # sub parseOU
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# google_createGoogleAppsAccount
#
# Create a Google Apps account for the specified user with the
# specified password.
# User is moved to the specified Organizational unit. If no Org is specified,
# user is created at the top level
#--------------------------------------------------------------------/

sub google_createGoogleAppsAccount {

my $u = shift;
my $p = shift;
my $f = shift;
my $l = shift;
my $org = shift;


# escape every character in every variable we send to the shell
my $e_u = '\\' . join('\\',split(//, $u));
my $e_p = '\\' . join('\\',split(//, $p));
my $e_f = '\\' . join('\\',split(//, $f));
my $e_l = '\\' . join('\\',split(//, $l));
my $e_org = '\\' . join('\\',split(//, $org));



# GAM command syntax
# https://code.google.com/p/google-apps-manager/wiki/ExamplesProvisioning
# create user <email address> firstname <First Name> lastname <Last Name> password <Password> [suspended on|off] [changepassword on|off] [admin on|off] [sha] [md5] [nohash] [ipwhitelisted on|off] [quota #] [agreedtoterms on|off] [org <Org Name>] [customerid <Customer ID>]
my $cmd = "$GAM create user $e_u\@saintmarys.edu firstname $e_f lastname $e_l password $e_p agreedtoterms on suspended off";

if((defined($org)) && ($org ne '') && ($org =~/\S+/))
	{
	$cmd .= " org $e_org customerid '$CUSTOMERID'";
	}

my $result = `$cmd 2>&1`;
chomp $result;
my @lines = split /\n/,$result;
foreach my $line (@lines)
	{
	print " $line\n";
	}

my $status = 0;
if ($result =~ /Error: (\d+)/)
	{
	$status = $1;
	}

return $status;


} # sub google_createGoogleAppsAccount
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# google_enableIMAP
#
# Enable IMAP for the specified user
#--------------------------------------------------------------------/

sub google_enableIMAP {

my $u = shift;

my $cmd = "$GAM user $u imap on";

my $result = `$cmd 2>&1`;
chomp $result;
my @lines = split /\n/,$result;
foreach my $line (@lines)
	{
	print " $line\n";
	}

my $status = 0;
if ($result =~ /Error: (\d+)/)
	{
	$status = $1;
	}

return $status;

} # sub google_enableIMAP
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# google_disableWebClips
#
# Disable annoying web clips for the specified user
#--------------------------------------------------------------------/

sub google_disableWebClips {

my $u = shift;

my $cmd = "$GAM user $u webclips off";

my $result = `$cmd 2>&1`;
chomp $result;
my @lines = split /\n/,$result;
foreach my $line (@lines)
	{
	print " $line\n";
	}

my $status = 0;
if ($result =~ /Error: (\d+)/)
	{
	$status = $1;
	}

return $status;

} # sub google_disableWebClips
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# google_addToGroupByOU
#
# Add specified user to the Google group corresponding to the specified OU
#
# NOTE: assumes the specified user is in saintmarys.edu
#--------------------------------------------------------------------/

sub google_addToGroupByOU {

my $u = shift;
my $ou = shift;

# group name is simply the OU name with "_group" appended
# no ou verification is done here. If the group doesn't exist,
# the API should throw an error, which we return to the caller
my $groupName = $ou . '_group';

my $cmd = "$GAM update group $groupName add member $u\@saintmarys.edu";

my $result = `$cmd 2>&1`;
chomp $result;
my @lines = split /\n/,$result;
foreach my $line (@lines)
	{
	print " $line\n";
	}

my $status = 0;
if ($result =~ /Error: (\d+)/)
	{
	$status = $1;
	}

return $status;

} # sub google_addToGroupByOU
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# google_createAliasForUser
#
# Add specified alias to the user
#
# NOTE: assumes the specified user is in saintmarys.edu
#--------------------------------------------------------------------/

sub google_createAliasForUser {

my $u = shift;
my $alias = shift;


my $cmd = "$GAM create alias '$alias' user $u";

my $result = `$cmd 2>&1`;
chomp $result;
my @lines = split /\n/,$result;
foreach my $line (@lines)
	{
	print " $line\n";
	}

my $status = 0;
if ($result =~ /Error: (\d+)/)
	{
	$status = $1;
	}

return $status;

} # sub google_createAliasForUser
#--------------------------------------------------------------------/




#--------------------------------------------------------------------\
# google_getExistingUsers
#
# Calls gam to retrieve a list of all usernames in our google apps domain
# (saintmarys.edu). Populates hash reference keys with usernames (string
# to the left of @saintmarys.edu)
# 
# If an error is encountered, it puts the error text into the hash ref
# with the key 'error', then returns a 0/false value. Otherwise, returns
# 1/true.
#--------------------------------------------------------------------/

sub google_getExistingUsers {

# Reference to hash that will contain usernames
my $addsRef = shift;

my $cmd = "$GAM print users 2>&1";

my $result = `$cmd`;

if($result =~ /error/i)
	{
	$addsRef->{'error'} = $result;
	return 0;
	}

my @lines = split("\n",$result);

foreach my $line (sort @lines)
	{
	if($line =~ /^(\S+?)\@saintmarys\.edu/)
		{
		$addsRef->{$1} = 1;
		}
		
	} # foreach my $line (@lines)

return 1;

} # sub google_getExistingAddresses
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# google_getExistingNicknames
#
# Calls gam to retrieve a list of all nicknames in our google apps domain
# (saintmarys.edu). Populates hash reference keys with "usernames" (string
# to the left of @saintmarys.edu)
# 
# If an error is encountered, it puts the error text into the hash ref
# with the key 'error', then returns a 0/false value. Otherwise, returns
# 1/true.
#--------------------------------------------------------------------/

sub google_getExistingNicknames {

# Reference to hash that will contain usernames
my $addsRef = shift;

my $cmd = "$GAM print nicknames 2>&1";

my $result = `$cmd`;

if($result =~ /error/i)
	{
	$addsRef->{'error'} = $result;
	return 0;
	}

my @lines = split("\n",$result);

foreach my $line (sort @lines)
	{
	if($line =~ /^(\S+?)\@saintmarys\.edu.*/)
		{
		$addsRef->{$1} = 1;
		}
		
	} # foreach my $line (@lines)

return 1;

} # sub google_getExistingNicknames
#--------------------------------------------------------------------/









#--------------------------------------------------------------------\
# return value
1;
#--------------------------------------------------------------------/
