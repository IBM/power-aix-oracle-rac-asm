# Copyright (c) IBM Corporation 2021

# This script checks for minimum CPUs(cores) and memory.

use Getopt::Long;
use    Pod::Usage;

my  $cores=-99;
my $minmem=-99;
my $fail="false";
#+---------------------------------------------------------------
#+-  OPTION HANDLING  -------------------------------------------
#+---------------------------------------------------------------
sub do_opts {
  my $man = 0, $help = 0;

  use Getopt::Long;
  $retval=GetOptions( 
            "c=s"         =>\$cores,
            "m=s"         =>\$minmem,
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

  #+ Parse options and print usage if there is a syntax error,
  #+ or if usage was explicitly requested.
  pod2usage(1)             if $help;
  pod2usage(-verbose => 2) if $man;

  return $retval;
}

&do_opts or pod2usage(1) or die "do_opts failed\n" ;


if  ( $cores  == -99 )   { pod2usage(1); }
if  ( $minmem == -99 )   { pod2usage(1); }

#+--------------------------------------------
#+--  Main MAIN Program  ---------------------
#+--------------------------------------------

#+ make sure that this host is in /etc/hosts file
#+

$cmd="/usr/sbin/lsconf";
open (CMDO, "$cmd |" ) or die ("Cannot open pipe on \'$cmd\' \n") ;
while ( <CMDO> ) {
  $curcores=$1 if ( /Number Of Processors: (.*)$/ );
  $curmem=$1   if ( /Good Memory Size: (.*) MB/ );
}
close(CMDO);

if ( !defined($curcores) ) {
  die("lsconf did not produce number of processors\n");
}
if ( !defined($curmem) ) {
  die("lsconf did not produce 'Good Memory Size'\n");
}

  #+ change to MB's from GB
$meminMBs=$minmem*1024;

if ( $curcores < $cores  ) { 
  print("Insufficient Cores:$curcores Needed: $cores. Aborting...\n"); 
  print STDERR "ERROR: Insufficient Cores:$curcores Needed: $cores. Aborting...\n"; 
  $fail="true";
}
if ( $curmem   < $meminMBs ) { 
  print("Insufficient Memory:$curmem Needed: $meminMBs. Aborting...\n"); 
  $fail="true";
}
if ( $fail eq "true" ) {
  print("$0 failed. Aborting...\n");
  exit(-5);
}

print("OK. System meets footprint requirements\n");
exit(0);


__END__

=head1 NAME

lsconf.pl - Checking minimum cores and memory using lsconf command

=head1 SYNOPSIS

lsconf -c <min_#_of_cores> -m <min_amt_of_mem>GB

Required parameters:

  -c Specifies the minimum number of cores
  -m Specifies the minimum amount of memory in GB

Options:
-help brief help message
-man  full documentation

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=synompis
some text

=cut


