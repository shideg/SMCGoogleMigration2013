READ ME

Copyright (C) 2013  Steve Hideg

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program (see file GPL.txt); if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

###############################################################################
#                       THIS IS NOT A TURNKEY SOLUTION!                       #
#                                                                             #
# This software source code is presented to illustrate our approach to        #
# provisioning user accounts and migrating data from Zimbra Collaboration     #
# Server to Google Apps for Education. If you choose to use all or part of    #
# this software for your own solution, you must test it extensively in your   #
# own environment. This software is distributed as is WITHOUT ANY WARRANTY.   #
###############################################################################

This file will describe the source-code files in this directory that were used
to facilitate the migration of user data from a Zimbra Collaboration Server to
Google Apps for Education for Saint Mary's College. 

This software is being made available in conjunction with a presentation at
resnetsymposium.org. Presentation slides can be found there.

All software in this distribution is written in Perl and is designed to be run
on the command line of a Linux, Mac OS X or other unix/Posix compliant system.




SOURCE-CODE
###############################################################################

File adutils.pl
---------------
Set of subroutines for accessing Active Directory via LDAP

AD_setupAdminLDAPS
    Creates an LDAPS connection to Active Directory with full administrative 
    access.

AD_setupAdminLDAP
    Creates an LDAP connection with access to modify user objects only.

AD_setupLDAP
    Creates an unbound (unauthenticated) LDAP connection to Active Directory.
    Useful for authentication of user accounts.

AD_LDAPsearch
    Basic LDAP search in Active Directory.

AD_ldap_simpleBind
    Perform a simple bind using an LDAP object to Active Directory (see 
    AD_setupLDAP).
    Useful for authentication of user accounts.

AD_replaceSingleValuedAttOfEntry
    Replace the value of the specified single-valued attribute of an object.

AD_ldap_addAcctDescValue
    Add a time-stamped entry to smcEduAcctDesc.
    smcEduAcctDesc is used to log various operations on a user object.

smcEduAcctDescLogEntryNow
    Put data into a consistent time-stamped format for AD_ldap_addAcctDescValue.

ad_getExistingAccountInfo
    Get CNs, PIDMs, Mail addresses of all OU=People objects.
    PIDM is the primary key in our Banner SIS. It links an AD object to Banner.

addDNtoGoogleAppsUsers
    Add designated DN to the member attribute group GoogleAppsUsers.
    Membership in GoogleAppsUsers indicates account has been provisioned in
    Google Apps.

dnIsGoogleAppsUserMember
    See if specified DN is a member of group GoogleAppsUsers.
    Membership in GoogleAppsUsers indicates account has been provisioned in
    Google Apps.

getEmailAliases
    Extract mail aliases from proxyAddresses attribute in AD.
    Primary email address is prefixes with "SMTP:".
    Aliases are prefixed with "smtp:".


exportAdUtils.pl
-----------------
Set of subroutines for accessing Active Directory via LDAP supporting Zimbra
data export operations

exportAD_determineReportSender
    Deterimines the sender of software-generated emails based on recipient's
    role:
    Students, Ex-Students, Alumnae: mail comes from resnet@saintmarys.edu
    All others: helpdesk@saintmarys.edu

exportAD_geSingleValuedAtt
    Get the value of specified single-valued attribute for specified user
    object.

exportAD_addUsertoGoogleAppsMigrated
    add designated user's DN to the member attribute of group
    GoogleAppsMigrated.
    Membership in GoogleAppsMigrated indicates that the account's data has been
    migrated to Google Apps.


gammeComparator.pl
------------------
Compare GAMME csv input file to a capture (copy/paste) of GAMME's HTML report to
see which accounts it neglected to migrate.

After a run of GAMME concludes, there will appear on its window the text:
    Error Reports: Show
with "Show" being a clickable link.
If you click on this, GAMME will open an HTML report in a web browser. 
Under "Select Migration Run ID :" find the run you just completed (should be the
last one above "Aggregate" in the menu).

Click on the numerical value displayed after "Total Users".
Copy all the data lines (NOT the header line) in the displayed table and save it
to a text file.

Run gammeComparator.pl with your original text input file for googleAppify or
the CSV file for GAMME and the file you just created.

The output will be a listing of each file, then the differences (in CSV format)
that you can paste into a new CSV file for a follow-up GAMME run.

Follow-up GAMME runs such as this usually result in a message saying "No mail to
move", but I didn't want to trust it.


googleAppify
------------
Program to create specified accounts in Google Apps. It uses Google Apps Manager
(GAM) to access the Provisioning API. GAM is actually called in subroutines that
exist in other libraries described below.

Accounts are specified on the command line, by a program prompt or in a text
file.

Text file format is one username per line.
Comment lines (first character is #) are ignored.

googleAppify pulls information from Active directory (and other sources) to
create Google Account:

    givenName (first name)
    sn  (last name/surname)
    Location in AD's DIT (e.g. OU=Faculty,OU=People,DC=saintmarys,DC=edu)
    Mail aliases (proxyAddresses attribute)
    Password (you'll have to devise your own solution for this)

googleAppify then does the following
    Creates account
    Puts account in corresponding OU in Google (e.g. OU=Faculty)
    Enables IMAP
    Disables WebClips
    Adds account to group corresponding to OU
    Creates email aliases, if any
    Adds account as member of AD group GoogleAppsUsers
    Adds account entry to output CSV file

The output CSV file can be used to control GAMME and other programs.
The CSV file consists of the user's address on Zimbra, a password for the
account on Zimbra (we use a local password common to all Zimbra accounts), and
the email address the account has on Google (should be the same as Zimbra).


googleUtils.pl
--------------
Set of subroutines for management of the saintmarys.edu GoogleApps domain. These
will be used for general management and account provisioning beyond the
migration.

google_Auth
    Tests authentication to Google Apps for credential verification.

parseOU
    Parse the first OU part of a user object's DN.
    This is used for placement in the proper Google OU during provisioning.

google_createGoogleAppsAccount
    Invokes Google Apps Manager (GAM) to create an account in Google Apps.
    Includes specifying the OU to place the account.

google_enableIMAP
    Invokes Google Apps Manager (GAM) to enable IMAP for the account.
    This must be done on a per-account basis, though GAM can do bulk operations.

google_disableWebClips
    Invokes Google Apps Manager (GAM) to disable annoying web clips for the 
    specified user.
    
google_addToGroupByOU
    Invokes Google Apps Manager (GAM) to Add specified user to the Google group 
    corresponding to the specified OU.
    We have a set of groups that parallels our OU structure.

google_createAliasForUser
    Invokes Google Apps Manager (GAM) to create a mail alias (nickname) for 
    specified user.

google_getExistingUsers
    Invokes Google Apps Manager (GAM) to retrieve a list of all usernames in our 
    google apps domain.
    Useful for general account provisioning to avoid name collisions.

google_getExistingNicknames
    Invokes Google Apps Manager (GAM) to retrieve a list of all nicknames in our 
    google apps domain.
    Useful for general account provisioning to avoid name collisions.


ldapUtils.pl
------------
Set of subroutines for accessing iPlanet Directory Server via LDAP.

setupLDAP
    Creates an LDAP connection to iPlanet with full administrative access.

LDAPsearch
    Basic LDAP search in iPlanet.

ldap_simpleBind
    Perform a simple bind using an LDAP object to iPlanet.
    Useful for authentication of user accounts.

ldap_replaceAttByUid
    Replace all values of a given attribute with specified value for
    specified UID

ldap_getCypheredPassword
    Get the scrambled password for the given user.


migrationAcctCheck.pl
---------------------
Pre-flight a list of accounts to be migrated.
Make sure they aren't migrated already by checking membership in
groupGoogleAppsMigrated.
Make sure they have first and last names (givenName & sn attributes).
Make sure zimbra account isn't locked.

zimbra_getAccountStatus
    Get the zimbraAccountStatus for the specified account.
    Probably could have put this in zimbraUtils.pl. Why didn't I?


migrationFoldernameCheck.pl
---------------------------
Pre-flight a list of accounts to be migrated.
Make sure they aren't using illegal folder names.

Calls zimbra_getFolderPathLines and zimbra_evaluateMailFolders in
zimbraUtils.pl.


miscUtils.pl
------------
Set of subroutines for various functions needed for Google Apps migration.

createTimeStampedLogFile
    Create a time-stamped log file with the specified prefix (e.g. username), 
    in the specified location.
    Returns a file handle and the full path to the file.

printLC
    Print to log file and the console.
    Prints the contents of $msg to the specified log file handle as well as to
    the console. Newline characters are the caller's responsibility and should
    be embedded in the $msg argument.

hhmmss
    Returns a formatted string with leading zeros in the form hh:mm:ss for 
    specified number of seconds.
    
niceNow
    Returns a string with with current localtime in a pleasing format.


zimbraExport.pl
---------------
Unlocks Zimbra account in order to access its data.
Exports address books, calendars, and signatures from Zimbra.
Locks Zimbra accounts after export.
Records export data in log file.
Records export event in account's smcEduAcctDesc attribute.
Adds account to group GoogleAppsMigrated.
Input can be one or more usernames or a file of usernames via < input
redirection.
Expects a directory structure at $ZIMBRA_EXPORT_HOME. Under this, it expects to
be able to create a directory under $ZIMBRA_EXPORT_USERS for each account to
contain files of exported data. It also creates log files in $ZIMBRA_EXPORT_LOGS
for each run. Log file names contain a datetime stamp and the account's username
as a prefix.
It calls routines in zimbraUtils to perform the exports.


zimbraForward.pl
----------------
Forward zimbra accounts to gmigration.saintmarys.edu.


zimbraUtils.pl
Set of subroutines for accessing acccount information on Zimbra Collaboration
Server, exporting data from Zimbra and emailing it to users.

struct ContactsFolderInfo
    Data structure containing pertinent data for a Zimbra contacts folder.
    Software ends up creating an array of these to facilitate export.

struct CalendarInfo
    Data structure containing pertinent data for a Zimbra calendar.
    Software ends up creating an array of these to facilitate export.

zimbra_getFolderPathLines
    SSH to Zimbra server and issue the zmmailbox gaf command to get a 
    list of the user's folders. Put each folder listing line in an array

zimbra_getDisplayName
    Get the displayname for the account on the Zimbra server.
    Used as a fallback in case there's no displayName attribute in AD.

zimbra_evaluateMailFolders
    Perform some quality checks on Zimbra foldernames.
    Reference to an array containing lines from the zmmailbox gaf 
    folder listing is passed to to this.
    Used in pre-flight script migrationFoldernameCheck.pl,

zimbra_folderCountsIDs
    Examines the folder path lines array generated by zimbra_getFolderPathLines.
    Extracts names of contacts folders from the array
    Puts message counts into a referenced hash with folder names as keys.
    Puts folder ID numbers into a referenced hash with folder names as keys.

zimbra_sortFoldersByHierarchy
    Return a list of folders from the specified list, sorted by hierarchy.
    Hierarchy is determined by number of slashes in the path name.
    Since there is no hierarchy in the set of files we email to the user,
    we must do this kind of sorting to ensure filename uniqueness.

zimbra_determineUniqueFolderName
    Determine a unique foldername based on specified name and list of
    names in use.
    Proposed name should already be cleaned up from illegal characters and
    reserved names by the caller. This routine merely ensures uniqueness
    based on the contents in $usedNamesRef array

zimbra_exportContactsFolder
    Using the curl command, exports a contacts folder in csv format:
     For the specified user $u,
     At the specified URL $folderURL,
     Redirecting it to a file $exportFolderName in a directory for the user $u
     Specific csv format specified by $csvFormat

zimbra_exportContactsFolders
    If the specified user has contacts folders, this routine will process them 
    and determine which ones are to be exported, construct and send HTML-
    formatted email to the user with exported contacts folders as attachments.
    Exports each contacts folder twice in two formats:
     thunderbird-csv (for import by user into Google Apps)
     zimbra-csv (for extraction of group data to be listed in email message)

zimbra_analyzeAddressBookExport
    Analyze the specified address book.
    Put the resulting HTML-formatted report into the msgHTML member of the
    specified ContactsFolderInfo struct.

zimbra_checkForAddressBookGroups
    Analyze the specified Thunderbird export file to see if any entries are
    groups.
    Obtain group members (if any) from corresponding Zimbra export file
    To do this, the software locates certain columns by examining the header
    line of the thunderbird file:
        nickname
        primary email
        secondary email
        first name
        last name
    And the header row of the zimbra file:
        nickname
        dlist
    If an entry in the thunderbird file has neither primary email nor secondary
    email, it may be a group. It then checks the dlist column in the zimbra
    file for possible data, then tries to parse it.
    Lots of monkey-business with regular expressions.
    Returns an HTML-formatted list of the group name and its members (if any).

zimbra_splitAddresses
    Feeble attempt at parsing and splitting out members of the "dlist" field in 
    Zimbra-formatted address book csv files. Recursively calls itself until it
    decides the addresses can no longer be split.
    This could probably be much more sophisticated, but it seemed to meet our
    needs.

zimbra_exportCalendars
    If the specified user has calendars, this routine will process them and 
    determine which ones are to be exported, construct and send HTML-formatted 
    email to the user with exported calendars as attachments.
    If the user is subscribed to calendars, those are listed in the email
    along with the owner's email address.
    If the user has shared calendars, the sharing privileges are listed for such 
    calendars.

zimbra_exportCalendar
    Using the curl command, exports a calendar in iCalendar format:
     For the specified user $u,
     At the specified URL $folderURL,
     Redirecting it to a file $exportFolderName in a directory for the user $u

zimbra_analyzeCalendarExport
    Analyze the specified calendar.
    Checks to see if the calendar is shared by the account. Reports the sharing
    settings.
    Put the resulting HTML-formatted report into the msgHTML member of the 
    specified CalendarInfo struct.

zimbra_findShareGrants
    Looks for share grants of the specified folder and report them back as a 
    series of <li></li> tags
    Grant data comes the zmmailbox command in a form like this:
    Permissions      Type  Display
    -----------  --------  -------
              r   account  woo@saintmarys.edu
          rwidx   account  blah@saintmarys.edu
         rwidxa   account  frosh@saintmarys.edu
             r    public  
             rp     guest  blah@mac.com
              r     guest  boo@mac.com

zimbra_getSignatures
    Look for all signatures using zmmailbox zmmailbox -z -m <user> gsig
    Extract them from the JSON output.
    Convert newlines in text/plain signatures to <br> tags.
    Return an array of containing HTML display of each signature

zimbra_reportSignatures
    Get signatures from Zimbra (calling zimbra_getSignatures)
    If the account has any, report them to user in HTML formatted email.

zimbra_setAccountStatus
    Set the zimbraAccountStatus for the specified account to the specified value
    active|locked|closed|maintenance

zimbra_forwardToGmigration
    Forward mail for the specified account to gmigration.saintmarys.edu and set 
    it to not keep local copies.


populateResnet-Notice.pl
-----------------------
Utility script.
Uses input from text file or GAMME csv control file to create the commands to
send to listserv to populate the Resnet-Notice mailing list. Output is sent to
STDOUT. Copy the output and email it to listserv to repopulate the list. This
was useful for emailing large groups of students about their impending
migrations.

splitICS.pl
-----------
Utility script.
Quick-and-dirty script to analyze the specified iCalendar (.ics) file, report
number of events to user. User specifies number of events per output file.
Creates output files containint specified number events (or fewer for the last
file). Output files have the same name as the input file plus "-s<number>" plus
".ics".
This was created to split up calendars exported from Zimbra that were seemingly
too large to import into Google Apps.




WORKFLOW
###############################################################################

Preparation
-----------
* Create text file of users to migrate.
    Lines beginning with # are comments and will be ignored by this software.
    Text files (and therefore migration populations) can be anywhere from 1
    to hundreds of accounts.
    Typical text file:
        # Library       8                   
        jlng
        rhghl
        bernard
        suew
        ukovach
        libcirc
        ask-ill
        libdups

        # Marketing and Communications  1
        adotson

        #Publications       3
        lozicki
        courier

        #Admission Office   3
        plesnieg
        dwayne
        admislet

* Send a welcome to Google Apps email to these users.
    Our email addresses are username@saintmarys.edu, so a list is easy to 
    construct. For larger populations (students by class cohort), we use
    the resnet-notice listserv, populated by populateResnet-Notice.pl.

Preflight
---------
This was done 2-4 days before announced migration of the particular group.

* Check Zimbra folder names for illegal characters and names.
    Program migrationFoldernameCheck.pl

* Check that each account has givenName and sn attributes in Active Directory.
    Program migrationAcctCheck

Provisioning
------------
This was done 2-4 days before announced migration of the particular group.

* Program googleAppify
    Use text file of users as input.
    Creates accounts in Google.
    Creates CSV file to control GAMME
        CSV file is named "gamme" with a date/time stamp and .csv extension.

* (Optional) Rename csv file to something more identifiable.
    Typically the same name as the input text file but with .csv extension.

* Copy csv file to Windows machine hosting GAMME.
* Make sure line-endings on Windows machine copy are CRLF.

Heavy Lifting
-------------
This was done 1-3 days before announced migration of the particular group.

* Run GAMME, using csv file that was copied over.
    2-12 hours, depending on population size and mail usage.

* Check to see if entire population was migrated.
    After a run of GAMME concludes, there will appear on its window the text:
        Error Reports: Show
    with "Show" being a clickable link.
    If you click on this, GAMME will open an HTML report in a web browser. 
    Under "Select Migration Run ID :" find the run you just completed (should be 
    the last one above "Aggregate" in the menu).

    If the total users count is the same as the number of entries in your csv
    then you can skip the rest of this step.
    Click on the numerical value displayed after "Total Users".
    Copy all the data lines (NOT the header line) in the displayed table and 
    save it to a text file.

    Run gammeComparator.pl with your original text input file for googleAppify 
    or the CSV file for GAMME and the file you just created.

    The output will be a listing of each file, then the differences (in CSV 
    format) that you can paste into a new CSV file for a follow-up GAMME run.
    
    MAKE SURE LINE ENDINGS ARE CRLF.

    Follow-up GAMME runs such as this usually result in a message saying "No 
    mail to move", but I didn't want to trust it.

Curtain Lift
------------
Done on announced day of migration.

* Forward Zimbra email
    Run zimbraForward.pl with text or CSV file as input.
        Forwards each zimbra account to <user>@gmigration.saintmarys.edu
    ~ 5:30-6:00AM
    Usually scheduled with at command.

* GAMME "Curtain Lift" run
    Picks up email that arrived after Heavy Lifting.

* Check to see if entire population was migrated.
    Same procedure as after the heavy lifting GAMME run.

* Run zimbraExport.pl with text or CSV file as input.
    Calendars, Contacts, Signatures exported, Zimbra account locked

DONE!

Unless...

If users report difficulty importing large calendar files, you can use
splitICS.pl to split them into smaller chunks. Each output file is a complete
iCalendar file, but with only a subset of the original's events. User can import
them all into the same Google calendar for complete data transfer.


###############################################################################
#                       THIS IS NOT A TURNKEY SOLUTION!                       #
#                                                                             #
# This software source code is presented to illustrate our approach to        #
# provisioning user accounts and migrating data from Zimbra Collaboration     #
# Server to Google Apps for Education. If you choose to use all or part of    #
# this software for your own solution, you must test it extensively in your   #
# own environment. This software is distributed as is WITHOUT ANY WARRANTY.   #
###############################################################################

Copyright (C) 2013  Steve Hideg

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program (see file GPL.txt); if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
