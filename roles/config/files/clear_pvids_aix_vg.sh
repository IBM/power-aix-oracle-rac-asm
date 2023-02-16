#!/usr/bin/ksh93

# This script clears the PVIDs on the disks for an AIX volume group.
# Usage: clear_pvid_aix_vg.sh <volume_group> "<disk1 disk2 ...>"

# Idempotent: yes

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

  #+ make sure this script is running as this user.
check_user_is root

vg=$1
disks="$2"

#
# Clear PVID on the disk only if the disk is not binded to the vg
# and has a PVID. The disk will be zero'd out.
#
function clear_pvid {
  disk=$1

  runcmd_nz "lspv | awk '/^${disk}[ ]/ {print \$3}'"
  # A disk has a PVID and binded to a volume group can occur when
  # this script runs again after the volume group has been created.
  [ "$RESOUT" == "$vg" ] && return
  if [ "$RESOUT" != "None" ]; then
    error_if_zero 0 "DISK $disk BELONGS TO VG: $RESOUT. ABORTING..."
  fi

  runcmd_nz "lspv | awk '/${disk}[ ]/ {print(\$2);}'"
  if [ "$RESOUT" != "none" ] ; then
    echo runcmd_nz "/usr/sbin/chdev -l $disk -a pv=clear"
         runcmd_nz "/usr/sbin/chdev -l $disk -a pv=clear"
    echo "$disk changed for clearing PVID, prepping for RAC install"

  fi
  # Sometimes even without PVID, the disk may still has VGDA so mkvg
  # will fail unless the force option is used. Clear the VDGA here to
  # to avoid the hassle.
  echo runcmd_nz "dd if=/dev/zero of=/dev/r${disk} bs=1024K count=100"
       runcmd_nz "dd if=/dev/zero of=/dev/r${disk} bs=1024K count=100"
}

#
# Fix a corner case error
# Error senario is vg exists, but the hdisks that are SUPPOSED to be binded
# to it are not. These hdisks have PVIDs.
#
# The simple fix is to do an exportvg and let clear_pvid() handles the
# PVIDs on the hdisks.
num_hdisks_binded=0
total_num_hdisks=0
if lsvg | grep -q $vg; then
  for d in $disks; do
    ((total_num_hdisks++))
    runcmd_nz "lspv | awk '/${d}[ ]/ {print(\$3);}'"
    [[ "$RESOUT" == "$vg" ]] && ((num_hdisks_binded++))
  done
  if [[ $num_hdisks_binded -ne $total_num_hdisks ]]; then
    echo runcmd_nz "exportvg $vg"
         runcmd_nz "exportvg $vg"
  fi
fi

for d in $disks; do
  clear_pvid $d
done

exit 0
