# Copyright (c) IBM Corporation 2021

# This script adds timeserver entries to /etc/hosts and runs setclock.
# Idempotent: yes

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

# make sure this script is running as this user.
check_user_is root

etc_hosts=/etc/hosts

save_original $etc_hosts

usage() {
  echo "Usage: aix_timeserver.sh {<timeserver>}"
  exit 1
}

################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################

[ $# -eq 0 ] && usage

timeserver="$1"
timeserverf=$(printf "%-15s" $timeserver)

if echo $timeserver | egrep -q '^[0-9]{1,3}'; then
  # Looks like it's in IP address format, verify it.
  echo "$timeserver" | egrep -q '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
  if [ $? -ne 0 ]; then
    echo "ERROR: Invalid timeserver IP address format: $timeserver."
    exit 1
  fi
else
  # If timeserver is not in IP address format, indirectly verify
  # it's a valid hostname/FQDN through lookup using host command,
  # in doing so, the IP address is returned, which is exactly what is
  # needed for the 1st field.
  output=$(host $timeserver)
  if echo "$output" | grep -q 'NOT FOUND'; then
    echo "ERROR: timeserver $timeserver could not be resolved."
    exit 1
  else
    # Extract the IP address from $output
    # E.g. mytserver is 123.45.67.8,  Aliases:  tserver1.mydomain.com, tserver1
    timeserver=$(echo "$output" | \
               perl -pe 's/.*is\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*/$1/')
  fi
fi

if ! ping -c 2 -w 2 $timeserver >/dev/null 2>&1; then
  echo "ERROR: timeserver $timeserver not pingable."
  exit 1
fi

if ! egrep -q "^$timeserver[ ]*timeserver" $etc_hosts; then
  # desired entry not found
  if egrep -q "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}[ ]{1,}timeserver" $etc_hosts; then
    # Timeserver entry exists but it is not the correct timeserver IP address,
    # delete it and add the correct entry."
    update_cmd="/[0-9][0-9]*.*[ ][ ]*timeserver\nd\na\n$timeserverf timeserver\n.\nw\nq\n"
    echo "$update_cmd" | ed -s $etc_hosts
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to update timserver in $etc_hosts."
      exit 1
    fi
    echo "/etc/hosts changed for updating to \"$timeserver timeserver\"."
  else
    # No entry found, add it
    update_cmd="a\n$timeserverf timeserver\n.\nw\nq\n"
    echo "$update_cmd" | ed -s $etc_hosts
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to add timserver $timeserver in $etc_hosts."
      exit 1
    fi
    echo "/etc/hosts changed for adding \"$timeserver timeserver\"."
  fi
  /usr/bin/setclock $timeserver
else
  echo "\"$timeserver timeserver\" already exists in $etc_hosts."
fi

exit 0
