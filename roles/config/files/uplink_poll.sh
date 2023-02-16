#!/usr/bin/ksh93

# Copyright (c) IBM Corporation 2021

# This script sets the Virtual I/O Ethernet Adapter uplink poll flag.

# Idempotent: yes

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

  #+ make sure this script is running as this user.
check_user_is root

#
# Note: There are 3 possible scenarios
# 1) All Ethernet adapters are physical.
# 2) Mixed of physical and virtual Ethernet Adapters 
# 3) All virtual Ethernet adapters.

# Report only if poll_uplink is set on a virtual Ethernet adapters.
# No message will be displayed for physical Ethernet adapters.


help() {
  echo "\nUsage: $(basename $0) <interface> ..."
  exit 1
}

################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################

[ $# -eq 0 ] && help
 
intfs=$*
for intf in $intfs
do
  dev=$(echo $intf | sed -e 's/en/ent/')
  lsdev -Cc adapter |egrep -q "${dev}.*Available.*Virtual I/O Ethernet Adapter"
  if [ $? -ne 0 ]; then
    echo "INFO: $dev is not a Virtual Ethernet Adapter, poll uplink not set."
  else
    output=$(lsattr -El $dev -a poll_uplink 2>&1)
    exit_code=$?
    case $exit_code in
    255)
      echo "ERROR: Virtual Ethernet Adapter $dev doesn't support poll uplink."
      exit 1
      ;;
    0)
      if echo "$output" | egrep -q '^poll_uplink no'; then
        runcmd_nz "chdev -l $dev -a poll_uplink=yes -P"
        echo "uplink poll changed on $dev, reboot required."
      fi
      ;;
    *)
      echo "ERROR: lsattr -El $dev -a poll_uplink failed with exit code $?"
      exit 1
      ;;
    esac
  fi
done

exit 0
