#!/usr/bin/ksh93

# Copyright (c) IBM Corporation 2021

# This script verifies ACFS is mounted

# Idempotent: N/A (check only)

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi
. ./helper.sh

  #+ make sure this script is running as this user.

check_user_is root

################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################

grid_home=$1
     acfs=$2
num_nodes=$3

num_nodes_mounted=$($grid_home/bin/srvctl status filesystem |\
  perl -sne 'if (/.*${acfs} is mounted on nodes (.*)$/) { @array = split(/,/, $1); print scalar @array; }' -- -acfs=$acfs)

if [ $num_nodes_mounted -ne $num_nodes ]; then
  echo "ERROR: Number of ACFS mounted nodes is $num_nodes_mounted, expected $num_nodes."
  exit 1
fi

exit 0
