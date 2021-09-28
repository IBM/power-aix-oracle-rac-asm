# Copyright (c) IBM Corporation 2021

# This script adds websm_rlogin and websm_su entries to /etc/pam.conf.

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

pam_conf=/etc/pam.conf

save_original $pam_conf

typeset -A service_entries=(
  [websm_rlogin]="websm_rlogin session required /usr/lib/security/pam_aix"
  [websm_su]="websm_su session required /usr/lib/security/pam_aix"
  )

for service in ${!service_entries[@]}; do
  if ! grep -q ^$service $pam_conf; then
    update_cmd="\$\na\n${service_entries[$service]}\n.\nw\nq\n"
    echo "$update_cmd" | ed -s $pam_conf
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to add $service entry in $pam_conf."
      exit 1
    fi
    echo "$pam_conf changed for adding $service service."
  else
    pattern=$(echo ${service_entries[$service]} | sed 's/ /[ ]*/g')
    if ! egrep -q "$pattern" $pam_conf; then
      update_cmd="/^$service\nd\ni\n${service_entries[$service]}\n.\nw\nq\n"
      echo "$update_cmd" | ed -s $pam_conf
      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to replace $service entry in $pam_conf."
        exit 1
      fi
      echo "$pam_conf changed for replacing $service entry."
    else
      echo "$service entry already exists in $pam_conf."
    fi
  fi
  echo
done

exit 0
