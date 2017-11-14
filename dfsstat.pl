#!/usr/bin/perl -w
#
# Program: DTrace File System Statitics Generator <dfsstat.pl>
#
# Author: Matty < matty91 at gmail dot com >
#
# Current Version: 1.0
#
# Revision History:
#  Version 1.0
#
# Last Updated: 04-02-2006
#
# Purpose: Prints file system statistics on Solaris servers with DTrace.
#
# Idea: This idea came from the Solaris fsstat C program.
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
# Example:
#    $ dfsstat.pl 5
#    process    open close read write stat creat link unlink symlink mkdir rmdir
#    cat         148   148   74    37  111     0    0      0       0     0     0
#    dfsstat.pl    0     0    6     0    0     0    0      0       0     0     0
#    dtrace        0     0    0     7    0     0    0      0       0     0     0
#    ln          111    74    0     0  185     0    0      0      37     0     0
#    mkdir       148   111    0     0  148     0    0      0       0    37     0
#    mv          111    74    0     0  111     0    0      0       0     0     0
#    rm          370   259    0     0  370     0    0    222       0     0    37
#    test.sh       0   222    0    37    0    74    0      0       0     0     0
#    touch       111   222    0     0  407   148    0      0       0     0     0

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

syscall::read:return,
syscall::write:return,
syscall::readv:return,
syscall::writev:return,
syscall::pread:return,
syscall::pwrite:return,
syscall::pread64:return,
syscall::pwrite64:return
{
   printf("%s %s\\n", execname, probefunc);
}

syscall::stat:return,
syscall::fstat:return,
syscall::stat64:return
syscall::lstat:return,
syscall::xstat:return,
syscall::fxstat:return,
syscall::lxstat:return,
syscall::fstat64:return,
syscall::lstat64:return
{
   printf("%s %s\\n", execname, probefunc);
}

syscall::lseek:return,
syscall::llseek:return
{
   printf("%s %s\\n", execname, probefunc);
}

syscall::open:return,
syscall::open64:return
{
   printf("%s %s\\n", execname, probefunc);
}

syscall::close:return
{
   printf("%s %s\\n", execname, probefunc);
}

syscall::rename:return
{
   printf("%s %s\\n", execname, probefunc);
}

syscall::mkdir:return,
syscall::rmdir:return
{
   printf("%s %s\\n", execname, probefunc);
}
syscall::creat:return,
syscall::creat64:return
{
   printf("%s %s\\n", execname, probefunc);
}

syscall::link:return,
syscall::unlink:return,
syscall::symlink:return
{
   printf("%s %s\\n", execname, probefunc);
}'
END

# Open up DTrace and start collecting stuff.
open(DTRACE,"$dtrace |") || die "cannot open dtrace $@\n";

# Collect data and print information every $DELAY seconds.
alarm($DELAY);

while (<DTRACE>) {
    chomp();

    ($proc, $func) = split(' ', $_);

    # The first few operations have several variants (e.g., creat() && crat64()), 
    # so search for the general name (e.g., open).
    if ( $func =~ /read/) {
       $procs{$proc}{"read"}++;

    } elsif ( $func =~ /write/) {
       $procs{$proc}{"write"}++;

    } elsif ( $func =~ /open/) {
       $procs{$proc}{"open"}++;

    } elsif ( $func =~ /seek/) {
       $procs{$proc}{"seek"}++;

    } elsif ( $func =~ /stat/) {
       $procs{$proc}{"stat"}++;

    } elsif ( $func =~ /creat/) {
       $procs{$proc}{"creat"}++;

    } else {
       $procs{$proc}{$func}++;
    }

    # Set a variable so we know we have data.
    $stuff = 1;
}

sub print_procs {
    # Print the header if we have stuff.
    if ( $stuff ) {
        # print a heading with file and directory operations.
        printf("process        open close read write stat creat link unlink symlink mkdir rmdir\n");

        # Sort and print the entries in the associative array.
        for $index ( sort( keys %procs )) {
            printf("%-14s %4d %5d %4d %5d %4d %5d %4d %6d %7d %5d %5d\n", $index,
                                                                     $procs{$index}{"open"}    ? $procs{$index}{"open"} : 0,
                                                                     $procs{$index}{"close"}   ? $procs{$index}{"close"} : 0,
                                                                     $procs{$index}{"read"}    ? $procs{$index}{"read"} : 0,
                                                                     $procs{$index}{"write"}   ? $procs{$index}{"write"} : 0,
                                                                     $procs{$index}{"stat"}    ? $procs{$index}{"stat"} : 0,
                                                                     $procs{$index}{"creat"}   ? $procs{$index}{"creat"} : 0,
                                                                     $procs{$index}{"link"}    ? $procs{$index}{"link"} : 0,
                                                                     $procs{$index}{"unlink"}  ? $procs{$index}{"unlink"} : 0,
                                                                     $procs{$index}{"symlink"} ? $procs{$index}{"symlink"} : 0,
                                                                     $procs{$index}{"mkdir"}   ? $procs{$index}{"mkdir"} : 0,
                                                                     $procs{$index}{"rmdir"}   ? $procs{$index}{"rmdir"} : 0);
        }
        print "\n";

    } else {
        printf("process        open close read write stat creat link unlink symlink mkdir rmdir\n");
        printf("No Data           -     -    -     -   -      -    -      -       -     -     -\n\n");
    }
 
    # Setup the signal handler.
    alarm($DELAY);

    # Clear $stuff and the associative array.
    $stuff = 0;
    undef %procs
}
