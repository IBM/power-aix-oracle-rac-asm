# Copyright (c) IBM Corporation 2021

# This script updates oslevel because after xlC 13 TL is installed
# oslevel may drop to base level.

# Usage: oslevel_update.sh <aix_ver_rel_tl> <installp_device_path>

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

aix_ver_rel_tl=$1
installp_device_path=$2

if [ ! -d $installp_device_path ]; then
  echo "ERROR: installp_device_path $installp_device_path not found."
  exit 1
fi

cd $installp_device_path

fileset="/tmp/fileset.$$"
installp_log="/tmp/oslevel_update_installp.out"

curr_ver_rel_tl=$(oslevel -s | perl -ne 'while(/^(\d)(\d)00\-0(\d)\-.*$/) { printf("%d.%d.%d", $1, $2, $3); exit 0; }')

if [ "$aix_ver_rel_tl" != "$curr_ver_rel_tl" ]; then
  lslpp -l | perl -e 'while (<STDIN>) { if (/^\s{2}([^\s]+)\s+.*$/) { next if $1 eq "Fileset"; next if $1 =~ /^----/; print $1, "\n"; }}' > $fileset

  if [ ! -f $fileset ]; then
    echo "ERROR: Failed to find fileset $fileset."
    exit 1
  fi

  if [ $(wc -l $fileset | awk '{print $1}') -eq 0 ]; then
    echo "ERROR: Filesets $fileset is empty."
    exit 1
  fi

  installp -agXd. -e $installp_log -f $fileset

  # Can't rely on 0 exit code because there may be files that are not
  # in the lpp source hence non-zero exit code. The purpose is to sync oslevel
  # not really for updating the fileset.
  
  rm -f $fileset

  curr_ver_rel_tl=$(oslevel -s | perl -ne 'while(/^(\d)(\d)00\-0(\d)\-.*$/) { printf("%d.%d.%d", $1, $2, $3); exit 0; }')
  if [ "$aix_ver_rel_tl" != "$curr_ver_rel_tl" ]; then
    echo "ERROR: Failed to update oslevel - current: $curr_ver_rel_tl, expected: ${aix_ver_rel_tl}. See $installp_log for details."
    exit 1;
  fi

  echo "oslevel changed (updated successfully)."

fi

exit 0
