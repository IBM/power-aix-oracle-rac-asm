#!/usr/bin/ksh93

# Copyright (c) IBM Corporation 2021

# This script comments out the nameserver entries except the one with
# IP address specified in the argument. It can uncomment those
# entries previously commented out.
# gridSetup.sh/runInstaller don't allow more than one nameserver entries.

# Usage: modify_nameserver_entry.sh <IP_address_to_keep> comment_out
#        modify_nameserver_entry.sh <IP_address_to_keep> uncomment_out

# Idempotent: yes

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

keep_ip="$1"
action="$2"

file="/etc/resolv.conf"

if [ "$action" == "comment_out" ]; then
  grep ^nameserver $file | grep -v $keep_ip | awk -F ' ' '{ print $ NF }' | \
    while read ip; do
      cmd="/^nameserver[ ]*$ip/\ns/^nameserver/# nameserver/\nw\nq\n"
      echo "$cmd" | ed -s $file
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to comment out nameserver $nameserver_ip."
        exit 1
      fi
      echo "$file changed (commented out nameserver ${ip})"
    done
fi

if [ "$action" == "uncomment_out" ]; then
  egrep '^#.*nameserver' $file | awk -F ' ' '{ print $ NF }' | \
    while read ip; do
      cmd="/^#[ ]*nameserver[ ]*$ip/\ns/^#[ ]*nameserver/nameserver/\nw\nq\n"
      echo "$cmd" | ed -s $file
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to comment out nameserver $nameserver_ip."
        exit 1
      fi
      echo "$file changed (uncommented out nameserver ${ip})"
    done
fi

exit 0

