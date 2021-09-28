# Copyright (c) IBM Corporation 2021

# The script performs 4 checks and takes actions if "clear_pvids"
# and/or "zero_disks" options is/are specified.
#
# 1) VG exists but no disks belong to it - correct it by exportvg.
# 2) Disks existence and in "Available" state for the VG
# 3) Disks don't have PVIDs for the VG. If "clear_pvids" option is set,
#    the scripts clears the PVIDs on the disks, otherwise, the script 
#    reports it and fails.
# 4) Disks don't have VGDA. If "zero_disks" option is set, the disks will be
#    zeroed out to clear VGDA.

# Usage: vg_dsks_validity.pl <args>
# args:
#   <vg> "hdisk hdisk ..." ["clear_pvids"] ["zero_disks"]

# Idempotent: yes


         $vg = $ARGV[0];
      $disks = $ARGV[1];
$clear_pvids = $ARGV[2];
 $zero_disks = $ARGV[3];

#
# Build %disk_status to capture existence of disks
# and Defined/Available state.
#
open(IN, "lsdev |") or die "ERROR: Failed to execute lsdev: $?\n";
while (<IN>) {
  $disk_status{$1} = $2 if (/^(hdisk\d+)\s+(Available|Defined)/);
}
close IN;

$disk_status_errors=0;
for $d (split(/\s/, $disks)) {
  if ($disk_status{$d} ne "Available") {
    $disk_status_errors++;
    print "ERROR: $d not in Available state or missing.\n";
  }
}

exit 1 if ($disk_status_errors);

#
# Create %disk_pvids to capture PVIDs
# Create %disk_vgs to capture VGs
#
open(IN, "lspv |") or die "ERROR: Failed to execute lspv: $?\n";
while (<IN>) {
  $disk_pvids{$1} = $2 if /^(hdisk\d+)\s+(none|[\da-z]+)/;
  $disk_vgs{$1} = $3 if /^(hdisk\d+)\s+(none|[\da-z]+)\s+([^\s]+)\s+/;
}
close IN;

#
# Initial sanity check to see if VG is already configured
#
`lsvg | grep $vg`;
$vg_exists = ($? == 0) ? 1 : 0;
if ($vg_exists) {
  print "INFO Volume group $vg exists.\n";
  $vg_invalid = 0;
  for $d (split(/\s/, $disks)) {
    if ($disk_pvids{$d} ne "none" and $disk_vgs{$d} ne "$vg") {
      print "INFO $d has PVID but does not belong to $vg.\n";
      $vg_invalid++;
    }
    if ($disk_pvids{$d} eq "none" and $disk_vgs{$d} eq "None") {
      print "INFO $d has no PVID and does not belong to any volume group.\n";
      $vg_invalid++;
    }
  }
  if ($vg_invalid) {
    `exportvg $vg`;
    if ($? != 0) {
      print "ERROR: exportvg $vg failed.\n";
      exit 1;
    }
  } else {
    exit 0;
  }
}

#
# Check for presence of PVIDs. If "clear_pvids" is set, clear the PVIDs,
# otherwise just report it and fail the script.
#
$disk_pvids_errors=0;
for $d (split(/\s/, $disks)) {
  if ($disk_pvids{$d} ne "none") {
    if ($clear_pvids eq "clear_pvids") {
      `/usr/sbin/chdev -l $d -a pv=clear`;
      if ($? != 0) {
        print "ERROR: chdev -l $d -a pv=clear failed\n";
      } else {
        print "$d changed - PVID cleared.\n";
      }
    } else {
      $disk_pvids_errors++;
      print "ERROR: $d PVID=$disk_pvids{$d} present.\n";
    }
  }
}

exit 1 if ($disk_pvids_errors);

#
# Check for presence of VGDA on the disks. If "zero_disks" is set,
# zero out the disks, otherwise just report it and fail the script.
#
$disk_vgda_errors = 0;
for $d (split(/\s/, $disks)) {
  `readvgda -t $d 2>&1 >/dev/null`;
  if ($? == 0) {
    if ("$zero_disks" eq "zero_disks") {
      `dd if=/dev/zero of=/dev/r$d bs=1024k count=100`;
      if ($? != 0) {
        print "ERROR: dd if=/dev/zero of=/dev/r$d bs=1024k count=100 failed\n";
      } else {
        print "$d changed - zeroed out.\n";
      }
    } else {
      print "ERROR: $d has VGDA.\n";
      $disk_vgda_errors++;
    }
  }
}

exit 1 if ($disk_vgda_errors);

exit 0;


