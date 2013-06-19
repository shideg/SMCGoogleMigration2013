#!/usr/bin/perl -w

#--------------------------------------------------------------------\
# miscUtils.pl
#
# Set of subroutines for various functions needed for Google Apps migration
#
# Written by Steve Hideg <hideg@saintmarys.edu>
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



#--------------------------------------------------------------------\
# createTimeStampedLogFile
#
# create and open for writing a log file
#
# Returns an array with two elements:
# 	file handle
#	file path
#
# See http://search.cpan.org/~nwclark/perl-5.8.7/pod/perl56delta.pod#File_and_directory_handles_can_be_autovivified
# 
#--------------------------------------------------------------------/

sub createTimeStampedLogFile {

# prefix (will be part of the filename)
my $prefix = shift;
# containing directory for the log file
my $directoryPath = shift;

# run time stamp
my ($runSec,$runMin,$runHour,$runDay,$runMonth,$runYear) = (localtime)[0,1,2,3,4,5];

# file name
my $fileName = sprintf("%s-%4d%02d%02d-%02d%02d%02d.log",$prefix,$runYear+1900,$runMonth+1,$runDay,$runHour,$runMin,$runSec);

# path with enclosing directory
my $filePath = $directoryPath . '/' . $fileName;

# remove any extraneous / characters
$filePath =~ s/\/{2,}/\//g;

open my $fh, ">$filePath"
	or die "Can't create log file '$filePath': $!\n";

return ($fh,$filePath);

} # sub createTimeStampedLogFile
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# printLC
#
# Print to log file and the console
#
# Line endings are the responsibility of the caller, assumed to be in $msg.
# 
#--------------------------------------------------------------------/

sub printLC {

# fileHandle for the log
my $log = shift;
# message to write
my $msg = shift;

# print to log
print $log $msg;
# print to console
print $msg;

} # sub printLC
#--------------------------------------------------------------------/

#--------------------------------------------------------------------\
# hhmmss
#
# returns a formatted string with leading zeros in the form hh:mm:ss
# for specified number of seconds
#
#--------------------------------------------------------------------\

sub hhmmss {

my $sec = shift;
my $hr;
my $min;

$hr = 0;
$min = 0;

if($sec >= 3600)
	{
	$hr = int($sec/3600);
	$sec -= $hr*3600;
	}
if($sec >= 60)
	{
	$min = int($sec/60);
	$sec -= $min*60;
	}

return sprintf("%02d:%02d:%02d",$hr,$min,$sec);

} # sub hhmmss
#--------------------------------------------------------------------/




#--------------------------------------------------------------------\
# niceNow
#
# returns a string with with current datetime
# in a pleasing format
#
#--------------------------------------------------------------------\

sub niceNow {

my ($year,$month,$day,$hour,$min,$sec) = (localtime)[5,4,3,2,1,0];
my $rightNow = sprintf("%4d-%02d-%02d %02d:%02d:%02d",$year+1900,$month+1,$day,$hour,$min,$sec);

return $rightNow;

} # sub niceNow
#--------------------------------------------------------------------/






#--------------------------------------------------------------------\
# return value
1;
#--------------------------------------------------------------------/
