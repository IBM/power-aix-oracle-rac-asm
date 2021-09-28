# Copyright (c) IBM Corporation 2021

# This script checks the number of running ASM instances with Flex ASM.
# The default cardinality for Flex ASM is 3 as per Oracle Automatic Storage
# Management Administrator's Guide 19c, p758 Overview of Oracle Flex ASM.
# If number of nodes <= 3, then the correct the number of
# ASM instances is equal to the number of nodes in the cluster.
#
# Run on first node only.
#
# Useage: check_asm_instances.pl <grid_home> <num_nodes>
# where <grid_home> HOME directory for grid
#       <num_nodes> Number of nodes

# Idempotent: N/A (check only)

$default_num_asm = 3;

$grid_home = $ARGV[0];
$num_nodes = $ARGV[1];

if ($grid_home eq "") {
    print "ERROR: missing GRID_HOME argument.\n";
    exit 1;
}

if ($num_nodes eq "") {
    print "ERROR: missing number of nodes argument.\n";
    exit 1;
}

# Wait for sufficient up time before checking for ASM status after reboot
$wait_for_uptime_mins = 7;
while (1) {
  $uptime = `/usr/bin/uptime`; chomp $uptime;
  if ($uptime =~ /^.*up\s(\d+)\s(\w+),\s+.*$/) {
    $units = $1;
    $mins_days = $2;
    if ($mins_days eq "mins") {
      last if ($units >= $wait_for_uptime_mins);
    } else {
      last;
    }     
  } elsif ($uptime =~ /^.*up\s+\d+:\d+,/) {
    last;
  }
  sleep 15;
}

`$grid_home/bin/asmcmd showclustermode 2>/dev/null | grep -q 'Flex mode enabled'`;
$is_flex_mode = ($? == 0) ? 1 : 0;

$run_nodelist = `$grid_home/bin/srvctl status asm`;
chomp $run_nodelist;
$run_nodelist =~ /ASM is running on (.*)$/;
$run_nodelist = $1;
if ("$run_nodelist" eq "") {
    print "ERROR: Failed to find running ASM instances from srvctl status asm.\n
";
    exit 1;
}
@_nodes = split(/,/, $run_nodelist);
$num_run = scalar @_nodes;

$grid_version = `$grid_home/bin/oraversion -compositeVersion`;
chomp $grid_version;
if ($is_flex_mode and $grid_version =~ /^19\.7/) {
  # In Grid 19.7, there's a bug where Flex ASM is enabled and number of
  # nodes > 3, the node without an ASM instance will fail to mount ACFS. The
  # workaround is to override the cardinality to all nodes.

  if ($num_nodes > 3 and $num_run != $num_nodes) {
    print "ERROR: In Oracle 19.7, number of ASMs is $num_run, should be $num_nodes to work around a bug when > 3 nodes, nodes that don't run ASM fail to mount ACFS .\n";
    print "ERROR: Consider using srvctl modify asm -count ALL.\n";
    exit 1;
  }
} else {
  if ($num_nodes < $default_num_asm) {
    if ($num_run < $num_nodes) {
      print "ERROR: number of running Flex ASM instances is $num_run, expected $num_nodes.\n";
      exit 1;
    }
  } else {
    if ($num_run < $default_num_asm) {
      print "ERROR: number of running Flex ASM instances is $num_run, expected $default_num_asm.\n";
      exit 1;
    }
  }
}

exit 0
