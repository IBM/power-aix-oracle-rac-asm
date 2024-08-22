#!/usr/bin/perl

# This scripts runs on the localhost (Ansible controller).
# Check each hdisk specified in config.disks has a consistent unique ID
# across the cluster nodes.
# The method used is to count the number of unique ID for a given hdisk from
# all the nodes. This should be equal to the number of nodes. If not,
# it prints out the inconsistent hdisks and exits with 1.
# The unique ID of each disk on each node is stored in
# /tmp/ansible/done/dsk_uids_done which is created by dsks_uids.sh.

# Idempotent: no if hdisks have been renamed (this task will be skipped.
#                Nothing is changed because it's just checking for hdisks
#                consistency. Furthermore, to account for the possiblility
#                of changes of hdisks in config.disks after this script
#                has run once, recheck is necessary.)

$nodes = "p224n95.pbm.ihost.com p224n96.pbm.ihost.com";
$first_host = "p224n95.pbm.ihost.com";

if ("$nodes" eq "") {
  print "ERROR: nodes is blank.\n";
  exit 1;
}

if ("$first_host" eq "") {
  print "ERROR: first_host is blank.\n";
  exit 1;
}

%hi_counts;
%dsks_uids;
@nodes = split('\s', $nodes);
$num_nodes = scalar @nodes;

# Gather all hdisk names and their unique IDs in %dsks_uids
for $n (split('\s', $nodes)) {
    if (!open(IN, "ssh root\@$n 'cat /tmp/ansible/done/dsks_uids_done' |")) {
        print "ERROR: Failed to open/read /tmp/ansible/done/dsks_uids_done on $n: $!\n";
        exit 1;
    }
    while (<IN>) {
        ($disk, $uid) = (split('\s'));
        $dsks_uids{$n}{$disk} = $uid;
        $hi_counts{$disk}{$uid}{count}++;
    }
    close IN;
}

# Create %inconsistent to track the number of unique IDs per hdisk
for $d (keys %hi_counts) {
    for $n (keys %{$hi_counts{$d}}) {
        $count = $hi_counts{$d}{$n}{count};
        if ($count != $num_nodes) {
            $inconsistent{$d} = 1;
            $errors++;
        }
    }
}

# Print the hdisks if the %inconsistent has any elements
$num_inconsistent = keys %inconsistent;
if ($num_inconsistent) {
    print "ERROR: Inconsistent unique ID found on disks ...\n";
    for $d (sort keys %inconsistent) {
        print "$d\n";
    }
    exit 1;
}

print "Shared disk consistent check succeeded.";
exit 0;

