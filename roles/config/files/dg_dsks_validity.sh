#!/usr/bin/ksh93

# Copyright (c) IBM Corporation 2021

# This script is invoked per ASM disk group and runs on first host.
# It performs the following to the disks specified in config.asmdisks.diskgroup:
#
# 1) Check if the disks exist and in Available state
# 2) Check if the disks have PVIDs, clear them if the option "clear_pvids" is
#    specified, otherwise report it and fail the script.
# 3) Check if the disks belong to a volume group. If "zero_disks" is specified
#    zero out the disks, otherwise report it and fail the script.
# 3) Check if disks have ASM header, if "zero_disks" is specified, zero out
#    the disks, otherwise report it and fail the script.
#
# Only <first_host> performs zeroing out disks.
#
# Usage: dg_dsks_validity.sh <first_host> <diskgroup> <disk_nums> ["clear_pvids"] ["zero_disks"]
#
# Idempotent: yes
#

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

  #+ make sure this script is running as this user.
check_user_is root

check_for_availability() {
  _disk_nums="$1"
  typeset -A available_disks
  lsdev -Cc disk | awk '/Available/ { print $1 }' | while read d; do
    available_disks[$d]="available";
  done

  availability_errors=0
  for d in $_disk_nums; do
    disk="hdisk$d"
    if [ "${available_disks[$disk]}" != "available" ]; then
      echo "ERROR: $disk is not in Available state or not found while processing $diskgroup disk group.";
      ((availability_errors++))
    fi
  done
  [ $availability_errors -ne 0 ] && exit 1
}

check_for_pvids_vgs() {
  _disk_nums="$1"
  typeset -A pvid_disks
  typeset -A vg_disks
  lspv | while read line; do
    set -- $line
    name=$1
    pvid=$2
    vg=$3
    pvid_disks[$name]=$pvid
    vg_disks[$name]=$vg
  done

  # disks have PVIDs?
  num_pvid_disks=0
  for d in $_disk_nums; do
    disk="hdisk$d"
    if [ "${pvid_disks[$disk]}" != "none" ]; then
      if [ "$clear_pvids" == "clear_pvids" ]; then
        runcmd_nz "/usr/sbin/chdev -l $disk -a pv=clear"
        echo "$disks changed - PVID cleared"
      else
        echo "ERROR: $disk has PVID=${pvid_disks[$disk]} in $diskgroup disk group."
        ((num_pvid_disks++))
      fi
    fi
  done
  [ $num_pvid_disks -ne 0 ] && exit 1

  # hdisks have Volume groups?
  num_vg_disks=0
  for d in $_disk_nums; do
    disk="hdisk$d"
    vgda_disk=0
    /usr/sbin/readvgda -t $disk >/dev/null 2>&1
    [ $? -eq 0 ] && vgda_disk=1
    
    if [[ "${vg_disks[$disk]}" != "None" || $vgda_disk -eq 1 ]]; then
      if [[ "$zero_disks" == "zero_disks" && $do_zero_disks -eq 1 ]]; then
        runcmd_nz "dd if=/dev/zero of=/dev/r$disk bs=1024k count=100"
        echo "$disk changed - zeroed out"
      else
        echo "ERROR: $disk belongs to volume group ${vg_disks[$disk]} while processing $diskgroup disk group."
        ((num_vg_disks++))
      fi
    fi
  done

  if [ $num_vg_disks -ne 0 ]; then
    echo "ERROR: Verify the hdisks are available for use as ASM disk group $diskgroup. Consider using exportvg <volume group> to remove AIX volume group from these hdisks."
    exit 1
  fi
}

check_for_asm_diskgroup() {
  _disk_nums="$1"
  num_dg_disks=0
  for d in $_disk_nums; do
    disk="hdisk$d"
    if /usr/sbin/lquerypv -h /dev/$disk | grep -q ORCLDISK; then
      if [ "$zero_disks" == "zero_disks" ]; then
        if [ $do_zero_disks -eq 1 ]; then
          runcmd_nz "dd if=/dev/zero of=/dev/r$disk bs=1024k count=100"
          echo "$disk changed - zeroed out"
        fi
      else
        echo "ERROR: $disk has an ASM header while processing $diskgroup disk group."
        ((num_dg_disks++))
      fi
    fi
  done
        
  if [ $num_dg_disks -ne 0 ]; then
    echo "ERROR: Consider using dd if=/dev/zero of=/dev/hdiskX bs=1024k count=100 to clear the ASM headers."
    exit 1
  fi
}


###############################################################################
#                                                                             #
# Main                                                                        #
#                                                                             #
###############################################################################

 first_host=$1
  diskgroup=$2
  disk_nums=$3
clear_pvids=$4
 zero_disks=$5

if [ $# -ne 5 ]; then
  echo "ERROR: Invalid number of arguments. $#"
  exit 1
fi

#
# Ensure if zeroing out disks is needed, do it on first host only.
# 
if ifconfig -a | grep -q $first_host; then
  do_zero_disks=1
else
  do_zero_disks=0
fi

check_for_availability "$disk_nums"
check_for_pvids_vgs "$disk_nums"
check_for_asm_diskgroup "$disk_nums"

exit 0
