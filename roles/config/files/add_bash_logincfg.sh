# Copyright (c) IBM Corporation 2021

# This script adds /usr/bin/bash to /etc/security/login.cfg.
# Save original on first update.

# Idempotent: yes

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

  #+ make sure this script is running as this user.
check_user_is root

export FILE=/etc/security/login.cfg

if ! grep -q /usr/bin/bash $FILE; then
  save_original $FILE
  cmd="/shells =\ns/shells = \/bin\/sh,/shells = \/bin\/sh,\/\usr\/bin\/bash,/\nw\nq\n"
  echo "$cmd" | ed -s $FILE
  echo "$FILE changed."
fi

