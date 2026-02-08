#!/usr/bin/ksh93

# Copyright (c) IBM Corporation 2021

# This script creates an ASM disk group.

# Idempotent: yes

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi
. ./helper.sh


################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################
   group_name=$1
dg_redundancy=$2
   grid_owner=$3
    grid_home=$4
       prefix=$5
    disk_nums=$6
new_disk_nums=$7

#echo "DEBUG: arg group_name=$group_name"
#echo "DEBUG: arg dg_redundancy=$dg_redundancy"
#echo "DEBUG: arg grid_owner=$grid_owner"
#echo "DEBUG: arg grid_home=$grid_home"
#echo "DEBUG: arg prefix=$prefix"
#echo "DEBUG: arg disk_num=$disk_nums"
#echo "DEBUG: arg new_disk_num=$new_disk_nums"

  #+ make sure this script is running as this user.

check_user_is $grid_owner

#
# Check sanity of variables
# 
[ -z "$grid_home" ] && echo "ERROR: grid_home cannot be empty." && exit 1

[ -z "$group_name" ] && echo "ERROR: group_name cannot be empty." && exit 1;

[ -z "$dg_redundancy" ] && echo "ERROR: dg_redundancy cannot be empty." \
&& exit 1

if $grid_home/bin/asmcmd lsdg $group_name 2>/dev/null | grep -q $group_name; then
  echo "ASM disk group $group_name already exists."
  exit 0
fi

if [ ! -d $grid_home ]; then
  echo "ERROR grid home directory $grid_home not found."
  exit 1
fi

#
# Check for inconsistent number of "nums" and "new_nums" if prefix is set
#
if [ -n "$prefix" ]; then
  n_nums=0
  n_new_nums=0
  for d in $nums; do
    ((n_nums++))
  done
  for d in $new_nums; do
    ((n_new_nums++))
  done
  if [ $n_nums -ne $n_new_nums ]; then
    echo "ERROR: inconsistent number of \"nums\" and \"new_nums\"."
    exit 1
  fi
fi

# Get the renamed disks 
disk_list=""
if [ -n "$prefix" ]; then
   if [ -n "$new_disk_nums" ]; then
     _nums=$new_disk_nums
   else
     _nums=$disk_nums
   fi
   _raw_disk_prefix="/dev/r$prefix"
else
   _nums=$disk_nums
   _raw_disk_prefix="/dev/rhdisk"
fi

#
# Get disk list for asmca -createGroup
#
for d in $_nums; do
  if [ -z "$disk_list" ]; then
    disk_list="${_raw_disk_prefix}$d"
  else
    disk_list="${disk_list},${_raw_disk_prefix}$d"
  fi
done

  #+ 3. Create disk groups by specifying the following command and parameters:
  #+ 	-createDiskGroup
  #+ 		[-diskString <disk discovery path>]
  #+ 		(-diskGroupName <disk group name>
  #+ 			(-disk <disk path> [-diskName <disk name>] |
  #+ 			 -diskList <comma separated disk list>
  #+ 				[-diskSize <disk size in MB>] 
  #+ 				[-failureGroups <comma separated failure group name list>] 
  #+ 				[-quorumFailureGroups <comma separated failure group name list>] 
  #+ 				[-sites <site name>] 
  #+ 				[-force|-noforce] 
  #+ 				[-quorum|-noquorum])
  #+ 			[-redundancy <HIGH|NORMAL|EXTERNAL|FLEX|EXTENDED>]
  #+ 			[-au_size <1 ~ 64>]
  #+ 			[-compatible.asm <11.2.0.2 ~ 12.2>]
  #+ 			[-compatible.rdbms <11.2.0.2 ~ 12.2>]
  #+ 			[-compatible.advm <11.2.0.2 ~ 12.2>]
  #+ 			[-sector_size.physical <512, 4k>]
  #+ 			[-sector_size.logical <512, 4k>]
  #+ 			[-autoLabel <automatically generates AFD labels, if label prefix is
  #+                                 not specified then the disk group name is used as prefix>])
  #+ 			[-labelPrefix <Label prefix will be used to create AFD labels>]
  #+ 		[-sysAsmPassword <SYS user password>]

#
# Create disk group
#
failuregroups_option=""
if [ "$dg_redundancy" = "NORMAL" ]; then
  fg_name="acfs_fg";
  fg_seq=1
  failuregroups_option="-failuregroups ";
  for d in $disk_nums; do
    failuregroups_option="${failuregroups_option}${fg_name}$fg_seq,"
    ((fg_seq++))
  done
fi

echo "DEBUG: parameter diskGroupName=$diskGroupName"
echo "DEBUG: parameter diskList=$diskList"
echo "DEBUG: parameter redundancy=$redundancy"
echo "DEBUG: parameter failuregroups_option=$failuregroups_option"

$grid_home/bin/asmca -silent -createDiskGroup \
   -diskGroupName    $group_name \
   -diskList         $disk_list \
   -redundancy       $dg_redundancy \
   $failuregroups_option \
   -compatible.asm   19.0.0.0 \
   -compatible.rdbms 19.0.0.0 
error_if_non_zero $? "asmca -createDiskgroup: Failed to create disk group $group_name."

#
# Verify disk group is mounted 
#
num_asms=$($grid_home/bin/srvctl status asm | \
           perl -ne 'if (/ASM is running on (.*)$/) { @array = split(/,/, $1); print scalar @array; }')

num_mounted=$(echo "lsdg -g --suppressheader $group_name" | \
                $grid_home/bin/asmcmd | \
                grep -v exit | wc -l | tr -d ' ')

if [ $num_asms -ne $num_mounted ]; then
  echo "ERROR: Number of mounted disk group $group_name is $num_mounted \
not equal to $num_asms ASM instances."
  exit 1
fi
echo "ASM disk group $group_name changed (created successfully)."

exit 0
