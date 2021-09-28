# Copyright (c) IBM Corporation 2021

# This script checks oslevel consistency across the hosts.

# Idempotent: N/A

$hosts = $ARGV[0];

for $h (split('\s', $hosts)) {
  $oslevel = `ssh root\@$h oslevel -s`;
  chomp $oslevel;
  print "$h: $oslevel\n";
  $oslevels{$oslevel}++;
}

$num_oslevels = keys %oslevels;
if ($num_oslevels ne 1) {
  print "ERROR: oslevel is not consistent across the nodes.\n";
  exit 1
}

exit 0
