# Copyright (c) IBM Corporation 2021

# Disable NTP service now and on boot and stop the xntp service.

# Idempotent: yes

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

# make sure this script is running as this user.
check_user_is root

################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################

saved_dir=$1

runcmd "lssrc -s xntpd | grep inoperative"
[ $? != 0 ] && running=1 || running=0

if [ $running -eq 1 ]
then
  runcmd "/usr/bin/stopsrc -s xntpd"
  echo "xntp service changed from active to inoperative."
fi

if ! grep -q '#*start /usr/sbin/xntpd' /etc/rc.tcpip; then
  runcmd "/usr/sbin/chrctcp -S -d xntpd"
  echo "/etc/rc.tcpip changed."
fi

# Oracle runcluvfy.sh doesn't allow its presence when ntpd is not running.
mv /etc/ntp.conf /etc/ntp.conf.orig
echo "/etc/ntp.conf changed (moved to /etc/ntp.conf.orig)"

exit 0
