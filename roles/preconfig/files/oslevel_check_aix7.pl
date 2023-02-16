#!/usr/bin/perl -w

# Copyright (c) IBM Corporation 2021

# This script checks for AIX level compatibility.

use strict;
use warnings;
use Getopt::Std;

my $dbg="";

#+----------------------------------------------------------------
#+--  OPTION HANDLING  -------------------------------------------
#+----------------------------------------------------------------
sub do_opts {
  my $man = 0, my $help = 0;
  my $version;

  use Getopt::Long;
  my $retval=GetOptions( 
            "dbg"         =>\$dbg,
            "version"     =>\$version,
            'help|?'      =>\$help,
            'man'         =>\$man
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

sub chk_fix {
  my $cmd="/usr/sbin/instfix -ik $_[0]";
  if ( $dbg ne "" ) { printf("cmd: %s\n",$cmd,); }
  system($cmd) == 0 or die "system $cmd failed: $?";
}

sub split_oslevel {
 my $base;
 my $tlevel;
 my $spack;
 my $spdate;

  ($base,$tlevel,$spack,$spdate)=split('-',$_[0]);
  return($base,$tlevel,$spack,$spdate);
}

my $value;
my $ver;
my $techlvl;
my $svcpack;
my $spdate;
my $tlsp;
my $min73i;
my $min72i;
my $min71i;
my $min71_base;
my $min71_techlvl;
my $min71_spack;
my $min71_spdate;
my $min72_base;
my $min72_techlvl;
my $min72_spack;
my $min72_spdate;
my $min73_base;
my $min73_techlvl;
my $min73_spack;
my $min73_spdate;


#+ this version value was found from the Oracle Doc ID: 1330703.1
#+
#+ https://docs.oracle.com/en/database/oracle/oracle-database/18/cwaix/supported-ibm-aix-72-versions.html#GUID-7BDD5193-1943-4103-9795-CF9CCEC283B1
#+ AIX 7.2 Technology Level 2 Service Pack 1 (7200-02-01-1731) or later, 64-bit kernel
#+ AIX 7.1 Technology Level 5 Service Pack 1 (7100-05-01-1731) or later, 64-bit kernel

my $min_AIX_7_3_VER='7300-00-01-2148';
my $min_AIX_7_2_VER='7200-02-01-1731';
my $min_AIX_7_1_VER='7100-05-01-1731';

($min73_base,$min73_techlvl,$min73_spack,$min73_spdate)=split_oslevel($min_AIX_7_3_VER);
($min72_base,$min72_techlvl,$min72_spack,$min72_spdate)=split_oslevel($min_AIX_7_2_VER);
($min71_base,$min71_techlvl,$min71_spack,$min71_spdate)=split_oslevel($min_AIX_7_1_VER);

$min71i=($min71_techlvl*100)+$min71_spack;
$min72i=($min72_techlvl*100)+$min72_spack;
$min73i=($min73_techlvl*100)+$min73_spack;

#+get current value
$value=`oslevel -s`; chomp($value);
($ver,$techlvl,$svcpack,$spdate)=split_oslevel($value);
$tlsp=($techlvl*100)+$svcpack;

if ( $dbg ne "" ) { printf("min73: %s TLSP: %s\n",$min73i,$tlsp); }
if ( $dbg ne "" ) { printf("min72: %s TLSP: %s\n",$min72i,$tlsp); }
if ( $dbg ne "" ) { printf("min71: %s TLSP: %s\n",$min71i,$tlsp); }
if ( $dbg ne "" ) { print("VER: $ver TL: $techlvl SP: $svcpack\n"); }

#+is version correct?
#+
if (! (($ver == "7300") || ($ver == "7200") || ($ver == "7100")) ) {
  print("Incorrect Version: Must be 7300 or 7200 or 7100\n");
  exit 16
}

if ( $ver == "7300" ) {
  if ($tlsp < $min73i ) {
    print("OS Minimum Version: $min_AIX_7_3_VER\n");
    print("ERROR::   OS Ver:   $value is lower than the Minimum required version.\n");
    exit 128;
  }
  print("OS Minimum Version: $min_AIX_7_3_VER\n");
  print("OS Ver: $value passes Minimum version check.\n");
}

if ( $ver == "7200" ) {
  if ($tlsp < $min72i ) {
    print("OS Minimum Version: $min_AIX_7_2_VER\n");
    print("ERROR::   OS Ver:   $value is lower than the Minimum required version.\n");
    exit 128;
  }
  print("OS Minimum Version: $min_AIX_7_2_VER\n");
  print("OS Ver: $value passes Minimum version check.\n");
}
if ( $ver == "7100" ) {
  if ($tlsp < $min71i ) {
    print("OS Minimum Version: $min_AIX_7_1_VER\n");
    print("ERROR::   OS Ver:   $value is lower than the Minimum required version.\n");
    exit 64;
  }
  print("OS Minimum Version: $min_AIX_7_1_VER\n");
  print("OS Ver: $value passes Minimum version check.\n");
}


#+ Ok now check instfix's
#+ See 1330703.1 for patches needed
#+
if ( $ver == "7100" ) {
  if ( $techlvl == "04" ) {
    chk_fix "IV81303";
  }
}
if ( $ver == "7200" && ($techlvl == 1) ) {
    chk_fix "IV94362";
}
if ( $ver == "7300" && ($techlvl == 0) && ($svcpack == 1)) {
    my $cmd1="/usr/sbin/instfix -i -c | grep -e  'IJ38518'";
    if (system($cmd1) != 0) {
        print "instfix check $cmd1 : Fix for APAR IJ38518 doesn't exit\n";
        print("Next Checking for efix existence using emgr \n");
        my $aix73_fix_cnt=0;
        $aix73_fix_cnt=`emgr -l |grep IJ38518 |grep -v grep|wc -l`; chomp($aix73_fix_cnt);
        if ( $aix73_fix_cnt >= 1) {
	    print("Efix installed and proceed with oracle install\n");
            open(my $fh, '>', "/tmp/efix_IJ38518.txt") or die "Could not create or open file in /tmp";
            print $fh "Efix IJ38518 exists and proceed with oracle install \n";
            close $fh;
        }
        else
        {
           print("Install the APAR IJ38518, Refer to https://www.ibm.com/support/pages/apar/IJ38518 \n");
           exit 128;
        }
     }
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

oslevel_check_aix7.pl - Check if the OS meets minimum OS level

=head1 SYNOPSIS

oslevel_check.pl [-help|?] [-man]

 Options:
   -help            brief help message
   -man             full documentation


=head1 DESCRIPTION

B<This program> checks the os level of AIX and errors
if the AIX level is less than the minimum level.
The OS level must be '7200-01-01' or later;

=cut
