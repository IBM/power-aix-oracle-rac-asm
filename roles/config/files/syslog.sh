# Copyright (c) IBM Corporation 2021

# This script adds 3 syslog facilities to /etc/syslog.conf, they are
# user.alert, user.err, and user.debug.
#
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

syslog_conf=/etc/syslog.conf

save_original $syslog_conf

typeset -A facility_priority=(
  [ualert]="user.alert /var/adm/ras/ualert.log rotate size 100k files 10"
  [uerr]="user.err /var/adm/ras/uerr.log rotate size 100k files 10"
  [udebug]="user.udebug /var/adm/ras/udebug.log rotate size 100k files 10"
  )

for fp in ${!facility_priority[@]}; do
  if ! egrep -q "^${facility_priority[$fp]}" $syslog_conf; then
    update_cmd="a\n${facility_priority[$fp]}\n.\nw\nq\n"
    echo "$update_cmd" | ed -s $syslog_conf
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to add ${facility_priority[$fp]} to $syslog_conf."
      exit 1
    fi
    echo "$syslog_conf changed for adding $fp"
  else
    pattern=$(echo ${facility_priority[$fp]} | sed 's/ /[ ]*/g')
    if ! egrep -q "$pattern" $syslog_conf; then
      update_cmd="/^$fp\nd\ni\n${facility_priority[$fp]}\n.\nw\nq\n"
      echo "$update_cmd" | ed -s $syslog_conf
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to replace $fp in $syslog_conf."
        exit 1
      fi
      echo "$fp ${facility_priority[$fp]} changed in $syslog_conf for update."
    else
      echo "$fp ${facility_priority[$fp]} already exists in $syslog_conf"
    fi
  fi
done

exit 0
