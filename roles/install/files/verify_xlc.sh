#!/usr/bin/ksh93

# Copyright (c) IBM Corporation 2021

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

done_dir=$1

if [ ! -x /opt/IBM/xlC/13.1.3/bin/xlc ]; then
  echo "ERROR: /opt/IBM/xlC/13.1.3/bin/xlc not found or not executable."
  exit 1
fi

cd /tmp
cat <<EOF > hello.c
#include <stdio.h>
main() {
  printf("hello world");
}
EOF

/opt/IBM/xlC/13.1.3/bin/xlc hello.c
if [ $? -ne 0 ]; then
  echo "ERROR: xlC 13.1.3 installed but /opt/IBM/xlC/13.1.3/bin/xlc appears to be non-functional."
  rm hello.c
  exit 1
fi

output=$(./a.out)
if [ "$output" != "hello world" ]; then
  echo "ERROR: xlc generated test executable appears to be non-functional."
  rm hello.c $output
  exit 1
fi

rm hello.c $output

echo "verify_xlc changed (verified successfully)."
touch $done_dir/verify_xlc_done

exit 0
