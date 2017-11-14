#!/usr/bin/perl -w
#
# Program: DTrace NFSv3 Client Statistics Generator <nfsclientstats.pl>
#
# Author: Matty < matty91 at gmail dot com >
#
# Current Version: 1.0
#
# Revision History:
#  Version 1.0
#
# Last Updated: 04-05-2006
#
# Purpose: Prints NFS client statistics on Solaris servers with DTrace.
#
# Installation:
#   Copy the shell script to a suitable location
#
# CDDL HEADER START
#  The contents of this file are subject to the terms of the
#  Common Development and Distribution License, Version 1.0 only
#  (the "License").  You may not use this file except in compliance
#  with the License.
#
#  You can obtain a copy of the license at Docs/cddl1.txt
#  or http://www.opensolaris.org/os/licensing.
#  See the License for the specific language governing permissions
#  and limitations under the License.
# CDDL HEADER END
#
# NFS Operations ( http://www.freesoft.org/CIE/Topics/115.htm ):
#    Procedure 0:  NULL - Do nothing 
#    Procedure 1:  GETATTR - Get file attributes 
#    Procedure 2:  SETATTR - Set file attributes 
#    Procedure 3:  LOOKUP - Lookup filename 
#    Procedure 4:  ACCESS - Check Access Permission 
#    Procedure 5:  READLINK - Read from symbolic link 
#    Procedure 6:  READ - Read From file 
#    Procedure 7:  WRITE - Write to file 
#    Procedure 8:  CREATE - Create a file 
#    Procedure 9:  MKDIR - Create a directory 
#    Procedure 10: SYMLINK - Create a symbolic link 
#    Procedure 11: MKNOD - Create a special device 
#    Procedure 12: REMOVE - Remove a File 
#    Procedure 13: RMDIR - Remove a Directory 
#    Procedure 14: RENAME - Rename a File or Directory 
#    Procedure 15: LINK - Create Link to an object 
#    Procedure 16: READDIR - Read From Directory 
#    Procedure 17: READDIRPLUS - Extended read from directory 
#    Procedure 18: FSSTAT - Get dynamic file system information 
#    Procedure 19: FSINFO - Get static file system Information 
#    Procedure 20: PATHCONF - Retrieve POSIX information 
#    Procedure 21: COMMIT - Commit cached data on a server to stable storage 
#
# Example:
# $ nfsclientstats.pl
# process    read write readdir getattr setattr lookup access create remove rename mkdir rmdir
# mkdir         0     0       0     380       0    190      0      0      0      0   190     0
# mv            0     0       0     189       0   1890   2079      0      0    189     0     0
# orca       3328   194       0    5496       6   6882   8246     12      0      0     0     0
# rm            0     0     760     950       0   2850   5320      0    190      0     0   190
# touch         0     0       0     378     189   1512   1323    189      0      0     0     0
# 
# process    read write readdir getattr setattr lookup access create remove rename mkdir rmdir
# mkdir         0     0       0     386       0    193      0      0      0      0   193     0
# mv            0     0       0     195       0   1950   2145      0      0    195     0     0
# orca       3110   169       0    8312      22  10434  12476     44      0      0     0     0
# rm            0     0     780     975       0   2925   5460      0    195      0     0   195
# touch         0     0       0     388     194   1552   1358    194      0      0     0     0


use POSIX;

# Get the delay from the user.
$DELAY = $ARGV[0] || 5;

# Install our signal handler to print the results every $DELAY seconds.
my $sigset = POSIX::SigSet->new(SIGALRM);

my $action = POSIX::SigAction->new('print_procs',
                                    $sigset,
                                    &POSIX::SA_NODEFER);

POSIX::sigaction(&POSIX::SIGALRM, $action);


# This is the DTrace program to run to collect system call metrics
my $dtrace = <<END;
/usr/sbin/dtrace -q -n'

fbt:nfs:nfs3_getattr:return,
fbt:nfs:nfs3_setattr:return,
fbt:nfs:nfs3_lookup:return,
fbt:nfs:nfs3_access:return,
fbt:nfs:nfs3_read:return,
fbt:nfs:nfs3_write:return,
fbt:nfs:nfs3_create:return,
fbt:nfs:nfs3_mkdir:return,
fbt:nfs:nfs3_remove:return,
fbt:nfs:nfs3_rmdir:return,
fbt:nfs:nfs3_rename:return,
fbt:nfs:nfs3_readdir:return,
fbt:nfs:nfs3readdirplus:return
{
    printf("%s %s\\n",execname,probefunc);
}'
END

# Open up DTrace and start collecting stuff.
open(DTRACE,"$dtrace |") || die "cannot open dtrace $@\n";

# Collect data and print information every $DELAY seconds.
alarm($DELAY);

while (<DTRACE>) {
    chomp();

    ($proc, $func) = split(' ', $_);

    if ( $func =~ /access/) {
       $nfsops{$proc}{"access"}++;

    } elsif ( $func =~ /getattr/) {
       $nfsops{$proc}{"getattr"}++;

    } elsif ( $func =~ /setattr/) {
       $nfsops{$proc}{"setattr"}++;

    } elsif ( $func =~ /readdir/) {
       $nfsops{$proc}{"readdir"}++;

    } elsif ( $func =~ /read/) {
       $nfsops{$proc}{"read"}++;

    } elsif ( $func =~ /write/) {
       $nfsops{$proc}{"write"}++;

    } elsif ( $func =~ /lookup/) {
       $nfsops{$proc}{"lookup"}++;

    } elsif ( $func =~ /create/) {
       $nfsops{$proc}{"create"}++;

    } elsif ( $func =~ /rename/) {
       $nfsops{$proc}{"rename"}++;

    } elsif ( $func =~ /mkdir/) {
       $nfsops{$proc}{"mkdir"}++;

    } elsif ( $func =~ /rmdir/) {
       $nfsops{$proc}{"rmdir"}++;

    } elsif ( $func =~ /remove/) {
       $nfsops{$proc}{"remove"}++;

    }

    # Set a variable so we know we have data.
    $stuff = 1;
}

sub print_procs {

    if ( $stuff ) {
        # print a heading with file and directory operations.
        printf("process    read write readdir getattr setattr lookup access create remove rename mkdir rmdir\n");

        # Sort and print the entries in the associative array.
        for $index ( sort( keys %nfsops )) {
            printf("%-10s %4d %5d %7d %7d %7d %6d %6d %6d %6d %6d %5d %5d\n", $index,
                                                               $nfsops{$index}{"read"}    ? $nfsops{$index}{"read"} : 0,
                                                               $nfsops{$index}{"write"}   ? $nfsops{$index}{"write"} : 0,
                                                               $nfsops{$index}{"readdir"}    ? $nfsops{$index}{"readdir"} : 0,
                                                               $nfsops{$index}{"getattr"}   ? $nfsops{$index}{"getattr"} : 0,
                                                               $nfsops{$index}{"setattr"}    ? $nfsops{$index}{"setattr"} : 0,
                                                               $nfsops{$index}{"lookup"}   ? $nfsops{$index}{"lookup"} : 0,
                                                               $nfsops{$index}{"access"}    ? $nfsops{$index}{"access"} : 0,
                                                               $nfsops{$index}{"create"}  ? $nfsops{$index}{"create"} : 0,
                                                               $nfsops{$index}{"remove"} ? $nfsops{$index}{"remove"} : 0,
                                                               $nfsops{$index}{"rename"}   ? $nfsops{$index}{"rename"} : 0,
                                                               $nfsops{$index}{"mkdir"}   ? $nfsops{$index}{"mkdir"} : 0,
                                                               $nfsops{$index}{"rmdir"}   ? $nfsops{$index}{"rmdir"} : 0);
        }
        print "\n";

    } else {
        printf("process    read write readdir getattr setattr lookup access create remove rename mkdir rmdir\n");
        printf("No Data       -     -       -       -       -      -      -      -      -      -     -     -\n\n");
    }

    # Setup the signal handler.
    alarm($DELAY);

    # Clear $stuff and the associative array.
    $stuff = 0;
    undef %nfsops;
}
