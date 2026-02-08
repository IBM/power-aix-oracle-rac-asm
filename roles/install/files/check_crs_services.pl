#!/usr/bin/perl

# Copyright (c) IBM Corporation 2021

# This script checks if each node has 4 CRS services online
# and check if all nodes are active.
#
# TODO
# Not sure retry is necessary.

# Idempotent: N/A (check only)

$grid_home = $ARGV[0];
$nodelist = $ARGV[1];  # commas separated

if ($grid_home eq "") {
    print "ERROR: Missing GRID_HOME argument.\n";
    exit 1;
}

if (! -d $grid_home) {
    print "ERROR: GRID_HOME=$grid_home not found.\n";
    exit 1;
}

if ($nodelist eq "") {
    print "ERROR: Missing nodelist argument.\n";
    exit 1;
}

%crs_online_services_count;

if (!open(IN, "dsh -n $nodelist $grid_home/bin/crsctl check crs |")) {
    print "ERROR: Failed to run dsh $grid_home/bin/crsctl check crs: $!\n";
    exit 1;
}

while (<IN>) {
    ($_node, $msg_code, $msg) = split(/:\s/);
    my @fqdn = split(/\./, $_node);
    $node = $fqdn[0];

    if ($msg =~ /.*Services is online|Event Manager is online/) {
        $crs_online_services_count{$node}++;
    }
}
close IN;

for my $node (split(/,/, $nodelist)) {
    $num_nodes++;
}
$num_nodes_found = 0;
$services_errors = "ERROR: ";
for my $node (keys %crs_online_services_count) {
    $num_nodes_found++;
    my $count = $crs_online_services_count{$node};
    if ($count != 4) {
        $service_errors .= "$node has $count services! Should be 4. ";
    }
}
if ($services_errors ne "ERROR: ") { $services_errors .= "\n"; }

if ($num_nodes_found < $num_nodes) {
    $missing_nodes = "";
    for my $node (split(/,/, $nodelist)) {
        if (! defined($crs_online_services_count{$node})) {
            $missing_nodes .= "$node ";
        }
    }
    $services_errors .= "Found missing nodes: $missing_nodes\n";
};

if ($services_errors ne "ERROR: ") {
    print STDERR "$services_errors";
    exit 1;
}

$num_active = `$grid_home/bin/olsnodes -s | grep -c Active`;
if ($num_active != $num_nodes) {
  print "ERROR: Number of active nodes not equal to $num_nodes.\n";
  exit 1;
}

exit 0;

