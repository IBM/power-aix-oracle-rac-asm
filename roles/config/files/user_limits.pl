#!/usr/bin/perl

# Copyright (c) IBM Corporation 2021

# Set user limits in /etc/security/limits.
# Attributes are set only if they differ from the current values
# and the changed attribute-value pairs are displayed.
#
# Idempotent: yes

use Getopt::Std;

sub usage {
  print <<EOF;
Usage: user_limits.pl -s <saved_dir> -u <user> <attribute>=<value> ... 

EOF
}


sub save_original {
  if (! -f "$saved_dir/limits") {
    `cp -p /etc/security/limits $saved_dir/limits`;
    if ($? != 0) {
      print "ERROR: Failed to save /etc/security/limits to $saved_dir/limits: $!\n";
      exit 1;
    }
  }
}


if ($#ARGV == -1 or $#ARGV == 0) {
  usage;
  exit 1;
}

if (!getopts('s:u:')) {
  print "ERROR: Invalid arguments\n";
  exit 1;
}

$saved_dir = $opt_s if defined $opt_s;
     $user = $opt_u if defined $opt_u;

if ("$saved_dir" eq "" || "$user" eq "") {
  usage;
  exit 1;
}

#
# Input limits
#
for $arg (@ARGV) {
  if ($arg =~ /(.*)=(.*)/) {
    $attrs{$1} = $2;
  }
}

#
# Current limits
#
open(IN, "lsuser $user |") or die "ERROR: Failed to open lsuser $user: $!\n";
$current_values = <IN>;
close IN;

for $av (split(' ', $current_values)) {
  if ($av =~ /(.*)=(.*)/) {
    $curr_attrs{$1} = $2;
  }
}

#
# Get diff limits using input args as reference
#
for $k (keys %attrs) {
  if ("$attrs{$k}" ne "$curr_attrs{$k}") {
    $set_attrs{$k} = $attrs{$k};
  }
}

#
# Set diff limits
#
if (keys %set_attrs) {
  for $k (sort keys %set_attrs) {
    $attrs .= "${k}=$set_attrs{$k} ";
  } 
  save_original;
  $output = `chuser $attrs $user 2>&1`;
  if ($? != 0) {
    print $output;
    exit 1;
  }
  print "user $user $attrs changed.\n";
} else {
  print "already set.\n";
}

exit 0;
