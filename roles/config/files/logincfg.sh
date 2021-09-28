# Copyright (c) IBM Corporation 2021

# This script changes the auth_type from STD_AUTH to PAM_AUTH in
# /etc/security/login.cfg.

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

login_cfg=/etc/security/login.cfg

save_original $login_cfg

auth_type="PAM_AUTH"

if ! egrep -q 'auth_type[ ]+=' $login_cfg; then
  update_cmd="$\ni\n        auth_type = PAM_AUTH\n.\nw\nq\n"
  echo "$update_cmd" | ed -s $login_cfg
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to add auth_type = $auth_type to $login_cfg."
    exit 1
  fi
else
  if ! egrep -q "auth_type[ ]+=[ ]+$auth_type" $login_cfg; then
    update_cmd="/auth_type[ ]*=\ns/=.*$/= $auth_type/\nw\nq\n"
    echo "$update_cmd" | ed -s $login_cfg
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to update auth_type to $auth_type in $login_cfg."
      exit 1
    fi
    echo "auth_type changed to $auth_type in $login_cfg."
  else
    echo "auth_type = $auth_type already exists in $login_cfg"
  fi
fi

exit 0

