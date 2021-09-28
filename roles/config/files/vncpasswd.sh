# Copyright (c) IBM Corporation 2021

# This script creates the VNC password file in user's home
# as .vnc/passwd. View-only password is not created.

# Idempotent: yes

. ./helper.sh

function show_usage_and_exit {
  printf "\nUsage: $(basename $0) -p password";
  exit -1;
}

################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################

while getopts h:p: _option $*
do
   case $_option in
      h) home_dir="$OPTARG" ;;
      p) password="$OPTARG" ;;
      *) printf "\nInvalid Option Specified: %s\n\n" $OPTARG
         show_usage_and_exit ;;
   esac
done
shift $(($OPTIND - 1))

[ -f $home_dir/.vnc/passwd ] && exit 0

if [ "X$password" == "X" ] ; then show_usage_and_exit; fi
if [ "X$home_dir" == "X" ]  ; then show_usage_and_exit; fi

prog="/usr/bin/X11/vncpasswd"

fail_if_file_doesnt_exist $prog
fail_if_directory_doesnt_exist $home_dir

/usr/bin/expect <<EOF
spawn "$prog" $home_dir/.vnc/passwd
expect "Password:"
send "$password\r"
expect "Verify:"
send "$password\r"
expect "view-only password (y/n)?"
send "n\r"
expect eof
exit
EOF
error_if_non_zero $? "Expect script to set password failed."

echo "$home_dir/.vnc/passwd changed."

exit 0
