# Copyright (c) IBM Corporation 2021

# This script adds entries in /etc/hosts as specified in config.etc_hosts.
# See "help" below for details.

# Idempotent: yes

use Getopt::Std;

sub usage {
  print <<EOF;
Usage: update_etc_hosts.pl -s <saved_dir>  <entry> ...
where <entry> is enclosed by double quotes with following fields separated
by a space:
a) IP address
b) hostname
c) optional aliases separated by a space

This script updates /etc/hosts as specified on the commnad line arguments.
The command line arguments specify completely of what the /etc/hosts entries
should be, not just entries to be added and/or to be upated. This means
entries that are not specified will be removed.
If the command line arguments contains a IPv4 loopback (aka 127.0.0.1), the AIX
supplied loopback entry will be commentd out.

Update to /etc/hosts only if the entries differ from the command line arguments.
Prior to the update, the /etc/hosts will be saved to <saved_dir> and occurs
only the first time in order to keep the original copy.

EOF

}

if ($#ARGV == -1) {
  usage;
  exit 1;
}

if (!getopts('s:')) {
  print "ERROR: Invalid arguments\n";
  exit 1;
}

$saved_dir = $opt_s if defined $opt_s;
if ("$saved_dir" eq "") {
  usage;
  exit 1;
}

$file = "/etc/hosts";

#
# Populate "new" array from command line arguments
#
$loopback_in_new = 0;
for $n (@ARGV) {
  $n =~ s/\s*$//;
  if ($n =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+\w+/) {
    $loopback_in_new = 1 if ($1 eq "127.0.0.1");
  } else {
    print "ERROR: Invalid argument: $n\n";
    exit 1;
  }
  push(@new, $n);
}

#
# Populate "exist" array with /etc/hosts entries and
# save AIX supplied default entries including comments,
# loopback entries, and timeserver entry in "defaults" array.
#
$comment_start = 0;
$loopback_in_exist = 0;
open(IN, "< $file") or die "ERROR: Failed to open $file for reading: $!\n";
while (<IN>) {
  chomp;
  if (/^#/) {
    $comment_start = 1;
    push(@defaults, $_);
  } elsif ($comment_start == 1 && /^$/) {
    push(@defaults, $_);
  } elsif (/^127\.0\.0\.1\s+loopback localhost\s+# loopback\s\(lo0\) name\/address*/) {
    $comment_start = 0;
    $loopback_in_exist = 1;
    push(@defaults, $_);
  } elsif (/^::1\s+loopback localhost\s+# IPv6 loopback.*/) {
    push(@defaults, $_);
  } elsif (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\s+timeserver/) {
    push(@defaults, $_);
  } elsif (/^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*$/) {
    $_ =~ s/\s*$//;
    push(@exist, $_);
  }
}
close IN;


sub save_original {
  if (! -f "$saved_dir/hosts") {
    `cp -p /etc/hosts $saved_dir/hosts`;
    if ($? != 0) {
      print "ERROR: Failed to save /etc/hosts to $saved_dir/hosts: $!\n";
      exit 1;
    }
  }
}


sub recreate {
  save_original;

  open(OUT, "> $file") or die "Failed to update $file: $!\n";
  for $d (@defaults) {
    if ($comment_out_loopback == 1 && $d =~ /^127\.0\.0\.1\s+loopback localhost/) {
      # When recreating /etc/hosts, if "new" array contains a loopback entry,
      # the AIX supplied loopback entry is commented out.
      print OUT "#";
      $comment_out_loopback = 0;
    }
    print OUT "$d\n";
  }
  for $n (@new) {
    $n =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(.*)\s*(.*)$/;
    $ip = $1; $hostname = $2; $aliases = $3;
    printf OUT "%-15s %s %s\n", $ip, $hostname, $aliases;
  }
  close OUT;
  system("chmod 664 $file");
  print "/etc/hosts changed - ";
  print "add, "    if (scalar @add_exist > 0);
  print "update, " if (scalar @update_exist > 0);
  print "delete, " if (scalar @delete_exist > 0);
  print "\n";

}

if ($loopback_in_new && $loopback_in_exist) {
  $comment_out_loopback = 1;
  recreate;
  print "$file changed - comment out loopbackn";
  exit 0;
}

#
# Scan "new" arrays, save entries that need to be updated
# in update_exist array and save entries that need to
# added in "add_exist" array.
#
$comment_out_loopback = 0;
for $n (@new) {
  $n =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(.*)$/;
  $n_ip = $1;
  $n_hostname = $2;
  $comment_out_loopback = 1 if ($n_ip eq "127.0.0.1");
  $n_ip_found = 0;
  for $e (@exist) {
    $e =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(.*)$/;
    $e_ip = $1;
    $e_hostname = $2;
    if ($n_ip eq $e_ip) {
      $n_ip_found = 1;
      if ($n_hostname ne $e_hostname) {
        push(@update_exist, "$e_ip");
      }
      last;
    }
  }
  if ($n_ip_found == 0) {
    push(@add_exist, "$n_ip");
  }
}

#
# Scan "exist" array and save entries to be deleted in "delete_exist" array
#
for $e (@exist) {
  $e =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(.*$)/;
  $e_ip = $1; $e_hostname = $2;
  $exist_ip_found = 0;
  for $n (@new) {
    $n =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+.*$/;
    $n_ip = $1;
    if ($n_ip eq $e_ip) {
      $exist_ip_found = 1;
      last;
    }
  }
  if ($exist_ip_found == 0) {
    push(@delete_exist, $e_ip);
  }
}

#
# If the size of "add_exist", "update_exist" or "delete_exist" arrays is
# non-zero, recreate /etc/hosts by composing it from "defaults" and "new"
# arrays.
#
if (((scalar @add_exist + scalar @update_exist + @delete_exist) > 0) || \
    $comment_out_loopback == 1) { 
  recreate;
}

exit 0;
