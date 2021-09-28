# Copyright (c) IBM Corporation 2021

# Usage: netconn.pl <network_spec> <network_spec> ...
# where <network_spec> is double-quoted with the following fields:
#   IP address of the host
#   Interface name
#   IP address of the interface
#   Repeat for interface name and its IP address

################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################

#
# Save <network_spec>s in %networks
#
for $a (@ARGV) {
  @data = (split(/\s/, $a));
  $size = @data;
  $host = $data[0];
  $i = 1;
  while ($i < $size) {
    $en = $data[$i++];
    $ip = $data[$i++];
    $networks{$host}{$en} = $ip;
  }
}

#
# Determine IP address for each interface to ping other hosts
#
for $host (sort keys %networks) {
  # Find my host
  system("ifconfig -a | grep -q $host");
  if ($? == 0) {
    $myhost = $host;
    # Determine all interfaces to ping
    for $en (sort keys %{$networks{$host}}) {
      $myhost_networks{$en} = $networks{$host}{$en};
      if ($ens eq "") {
        $ens = $en;
      } else {
        $ens = "$ens $en";
      }
    }
  }
  # Save hosts to ping excluding this host
  if ($host ne $myhost) {
    if ($pinghosts eq "") {
      $pinghosts = $host;
    } else {
      $pinghosts = "$pinghosts $host";
    }
  }
}

#
# Ping all other hosts for all interfaces
#
for $en (split('\s', $ens)) {
  for $h (split('\s', $pinghosts)) {
    system("ping -c 5 -w 2 $networks{$h}{$en}");
    if ($? != 0) {
      if ($errors eq "") {
        $errors = "ERROR: Failed to ping $networks{$h}{$en} on ${myhost}.\n"
      } else {
        $errors = "${errors}ERROR: Failed to ping $networks{$h}{$en} on ${myhost}.\n"
      }
    }
  }
}

if ($errors ne "") {
  print $errors;
  exit 1
}

exit 0
