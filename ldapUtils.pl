#!/usr/bin/perl -w

#--------------------------------------------------------------------\
# ldapUtils.pl
#
# Set of subroutines for accessing iPlanet Directory Server LDAP
#
# Written by Steve HIdeg <hideg@saintmarys.edu>
#
# 20 May 2011
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
# setupLDAP
#
# Subroutine to set up the LDAP connection
#
#--------------------------------------------------------------------/

sub setupLDAP {

my $ldap = Net::LDAP->new("aegis.saintmarys.edu") or die "$@";

my $mesg = $ldap->bind("cn=Directory Manager",
                                        password => "**********",
                                        version => 3) or die "$@";

my $code = $mesg->code;

if($code)
        {die "LDAP bind: ",ldap_error_name($code),"\n";}

return $ldap;

}
#--------------------------------------------------------------------/


#--------------------------------------------------------------------\
# LDAPsearch
#
# Subroutine for basic LDAP search
# (from Net::LDAP::Examples perldocexamplespod)
#
# Because of the more complex DIT structure we use in AD, the scope is
# now 'sub'
#--------------------------------------------------------------------/

sub LDAPsearch {

my ($ldap,$searchString,$attrs,$base) = @_;


# set a base dn if none was provided
if (!$base)
        {$base='ou=People,o=saintmarys.edu,o=saintmarys.edu';}

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


#--------------------------------------------------------------------\
# ldap_simpleBind
#
# Subroutine to perform a simple bind operation
#
# Can be used for authentication alone or for accessing the directory
# returns 1 (true) if bind succeeded, returns 0 (false) otherwise
# (including connection errors)
#
#--------------------------------------------------------------------/

sub ldap_simpleBind {

my ($ldap,$user,$password) = @_;

my $bindDN = "uid=$user,ou=people,o=saintmarys.edu,o=saintmarys.edu";

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

#-----------------------------------------------------------------------\
# ldap_replaceAttByUid
#
# Replace all values of a given attribute with specified value for
# specified UID
#
# It is assumed that the entry that this UID corresponds to does exist
#
# Calling scheme:
#	$result = ldap_replaceAttByUid($ldap,$uid,$attName,$attValue,\$message);
#-----------------------------------------------------------------------/

sub ldap_replaceAttByUid {

my $ldap     = shift;
my $uid      = shift;
my $attName  = shift;
my $attValue = shift;
my $msgRef   = shift;

my $filter = "(uid=$uid)";
my @Attr = ($attName);

my $ldapResult = LDAPsearch($ldap,$filter,\@Attr);
if($ldapResult->code)
	{
	$$msgRef = ldap_error_name($ldapResult->code);
	return;
	}
elsif($ldapResult->count == 0)
	{
	$$msgRef = "Unable find entry for uid $uid";
	return;
	}
else
	{
	# set the entry's DN
	my $entry = $ldapResult->entry(0);
	
	# replace the attribute
	$entry->replace($attName => $attValue);
	
	# update the entry on the server
	$ldapResult = $entry->update ( $ldap ); # update directory server
	
	if($ldapResult->code)
		{
		$$msgRef = ldap_error_name($ldapResult->code);
		return 0;
		}
	else
		{
		$$msgRef = "Attribute $attName replaced for uid $uid\n";
		return 1;
		}
	}
}
#-----------------------------------------------------------------------/


#-----------------------------------------------------------------------\
# ldap_getCypheredPassword
#
# Get the cyphered password for the given user
#-----------------------------------------------------------------------/

sub ldap_getCypheredPassword {

my $ldap = shift;
my $uid = shift;

my $cypheredPW = 'UNKNOWN';

my $ldapBaseDN = "ou=People,o=saintmarys.edu,o=saintmarys.edu";
my @ldapAttrs = ('***REDACTED***');
my $ldapFilter = "(uid=$uid)";

my $ldapResult = LDAPsearch($ldap,$ldapFilter,\@ldapAttrs,$ldapBaseDN); # ldapUtils.pl

if((!$ldapResult->code) && ($ldapResult->count == 1))
	{
	my $ldapEntry = $ldapResult->entry(0);
	$cypheredPW = $ldapEntry->get_value('***REDACTED***') ? $ldapEntry->get_value('***REDACTED***') : 'UNKNOWN';
	}

return $cypheredPW;





} # sub ldap_getCypheredPassword
#-----------------------------------------------------------------------/










# return value
1;