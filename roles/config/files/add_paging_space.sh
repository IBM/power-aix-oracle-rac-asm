#!/usr/bin/ksh93

# Copyright (c) IBM Corporation 2021

# This script configures the paging space size to the specified size,
# round up to rootvg's partition size. The paging space size will not
# be reduced if the current size is >= the specified size.

# Idempotent: yes

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

  #+ make sure this script is running as this user.
check_user_is root

function show_usage_and_exit
{
  printf "\nUsage: $(basename $0) <final_size(MB)>"; exit -1;
}

[ $# -eq 0 ] && show_usage_and_exit

################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################

final_size=$1
if [ $final_size -eq 0 ]; then
  echo "Final size 0 MB requested, nothing to do."
  exit 0
fi

runcmd_nz "lsps -s | tail -1 | awk '{print \$1}' | sed -e '/MB/s///'"
paging_space_size=$RESOUT

if (( $paging_space_size < $final_size )) ; then
  runcmd_nz "lsvg -l rootvg | fgrep paging | awk '{print \$1}'"
  page_lv=$RESOUT

  # Find the physical partition size for allocating paging space(MB's)
  runcmd_nz "/usr/sbin/lsvg rootvg |grep 'PP SIZE' |awk '{print(\$6);}"
  ppsize=$RESOUT
  
  _num_pps=$(echo "($final_size - $paging_space_size) / $ppsize" | bc -l)
  asize=$(( ceil($_num_pps) ))
  echo "Adding $asize segments to Paging"
  echo runcmd_nz "/usr/sbin/chps -s $asize $page_lv"
       runcmd_nz "/usr/sbin/chps -s $asize $page_lv"
  echo "Paging LV $page_lv changed."

  runcmd_nz "lsps -s | tail -1 | awk '{print \$1}' | sed -e '/MB/s///'"
  paging_space_size=$RESOUT

  if (( $paging_space_size < $final_size )) ; then
    error_if_non_zero 50 "Failure to increase paging size"
  else
    echo "Paging size is = ${paging_space_size} MB"
  fi

else
  echo "Current paging size $page_space_size MB >= requested $final_size MB. No action taken."

fi

exit 0
