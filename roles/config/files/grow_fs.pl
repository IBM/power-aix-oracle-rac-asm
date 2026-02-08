#+!/usr/bin/perl -w

# Copyright (c) IBM Corporation 2021

# Idempotent: yes

use strict;
use warnings;
use Getopt::Std;

my $dbg="";
my $filesystem="not_set";
my $befree="not_set";

#+----------------------------------------------------------------
#+--  OPTION HANDLING  -------------------------------------------
#+----------------------------------------------------------------
sub do_opts {
  my $man = 0, my $help = 0;
  my $version;

  use Getopt::Long;
  my $retval=GetOptions( 
            "filesystem=s"  =>\$filesystem,
            "free=s"        =>\$befree,
            "dbg"           =>\$dbg,
            "version"       =>\$version,
            'help|?'        =>\$help,
            'man'           =>\$man
            ) ;

  #+ handles unknown options. (ARGV isnt empty!)
  if ( $ARGV[0] ) {
    print "Unprocessed by Getopt::Long\n";
    foreach (@ARGV) { print "$_\n"; }
    pod2usage(-message => "Unprocessed by Getopt::Long",
              -exitval => 2,
              -verbose => 0,
              -output  => \*STDERR);
  }

  #+- Parse options and print usage if there is a syntax error,
  #+- or if usage was explicitly requested.
  pod2usage(1)             if $help;
  pod2usage(-verbose => 2) if $man;

#+ #- If no arguments were given, then allow STDIN to be used only
#+ #- if it's not connected to a terminal (otherwise print usage)
#+   pod2usage("$0: No files given.")  if ((@ARGV == 0) && (-t STDIN));

  return $retval;
}

&do_opts or pod2usage(1) or die "do_opts failed\n" ;

if ( $befree  eq "not_set" ) { pod2usage(-verbose => 1); }
if ( $filesystem eq "not_set" ) { pod2usage(-verbose => 1); }
#+----------------------------------------------------------------
#+--  FUNCTIONS        -------------------------------------------
#+----------------------------------------------------------------

sub turn_into_number{
}

#+----------------------------------------------------------------
#+----------------------------------------------------------------
#+ Main Program
#+----------------------------------------------------------------
#+----------------------------------------------------------------


my $CMD;
my $cmd;
my $fs;
my $al;
my $free;
my $pc;
my $iu;
my $ipc;
my $mnt;
my $found="false";
my $diff;
my $avail;
my $units="";
my $wanted="";

#+ what units is the free agument in?
($wanted,$units)=($1,$2) if ( $befree =~ /^(\d+)([GMK])$/ );
if ($units eq "" ) {  $units='K'; }

if ( $units eq 'G' || $units eq 'M' || $units eq 'K' ) {
  #+ convert to MEGS
  if ($units eq 'K') { $wanted=int $wanted/1024; }
  if ($units eq 'M') { $wanted=int $wanted; }
  if ($units eq 'G') { $wanted=int $wanted*1024; }
} else {
  die("-free units are not in form: nnnM, nnnG, or nnnK or nnn \n");
}


$cmd="df -ck";
open ($CMD, "$cmd |")  or die("Cant open $cmd\n");
while ( <$CMD> ) {
    #+Filesystem    1024-blocks      Free %Used    Iused %Iused Mounted on
  next if ( /Mounted on/ );
    #+/dev/hd3          5505024   5441532    2%       91     1% /tmp
  chomp;
  (      $fs,              $al,    $free,  $pc,     $iu,  $ipc,$mnt)=split(':');
  if ($mnt eq $filesystem) {
     $avail=int $free/1024;     #+ we want it in MBS
     $found="true";
  }
}
close($CMD);


if ( $found ne "true" ) {
   die("Error: file system: $filesystem not found. Aborting...\n"); 
}

print("\nFilesystem:      $filesystem FREE: $avail MB\n");
print("\nWanted::      $wanted MB\n");

if ($avail < $wanted ) {
  $diff=$wanted - $avail;
  $cmd="/usr/sbin/chfs -a size=+${diff}M $filesystem";
   if(system($cmd) != 0) {
     die("chfs failed\n"); 
  }
  print "$filesystem changed."
}

exit 0;
#+===========================================================
#+===========================================================
#+===========================================================
#+EVERYTHING after __END__ is ignored by perl, below is the
#+help info used by pod_usage
#+===========================================================

use Pod::Usage;
__END__

=head1 NAME

grow_fs.pl - Check if the OS meets minimum OS level

=head1 SYNOPSIS

grow_fs.pl -filesystem /filesystem -free <nnn>
                        [-help|?] [-man]

 Options:
   -help                 brief help message
   -man                  full documentation
   -filesystem           full path filesystem name
   -free                 available space in MB units


=head1 DESCRIPTION

B<This program> checks the amount of avaiable space within
the targeted file system if too small, expands to make that
much space avaiable.

Example: 
    perl grow_fs.pl --filesystem=/tmp  --free=1024  #+(MB's)

=cut
