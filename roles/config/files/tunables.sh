# Copyright (c) IBM Corporation 2021

# Idempotent: yes

# Set AIX tunables according to Oracle 19c recommendation

#+ Version:
#+ V1.00 Original Text
#+
#+ V1.02 Fri Mar  6 09:10:57 PST 2020 jubal. modified udp_recvspace from 65536 to 655360 per ravi
#+
#+ V1.03 Fri Feb 19 11:59:26 PST 2021 tommy.tse.
#+ Added references:
#+ [1] Oracle Database Release 19 --- Grid Infrastructure Installation and Upgrade Guide for IBM AIX on POWER Systems (64-Bit)
#+ https://docs.oracle.com/en/database/oracle/oracle-database/19/cwaix/tuning-aix-system-environment.html#GUID-B78ACF79-E28C-4D55-BE88-5E8C588E941B
#+ [2] Oracle 19.8 <GRID_HOME>/cv/cvdata/*.xml
#+ [3] Oracle Database (RDBMS) on Unix AIX,HP-UX,Linux,Solaris and MS Windows Operating Systems Installation and Configuration Requirements Quick Reference (12.1/12.2/18c/19c) (Doc ID 1587357.1)


if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

  #+ make sure this script is running as this user.
check_user_is root

set_no() {
  name=$1
  value=$2

  [[ $name == "ipqmaxlen" ]] && option="-r" || option="-p"
  curr_value=$(no -o $name | awk '{print $3}')
  if [ $value -ne $curr_value ]; then
    runcmd_nz "no $option -o ${name}=$value"
    echo "no $name changed."
    changed=1
  fi
}

set_chdev() {
  name=$1
  value=$2
  case $name in
    "maxuproc")
      curr_value=$(lsattr -El sys0 |awk '/^maxuproc/ { print $2 }')
      if [ $value -ne $curr_value ]; then
        runcmd_nz "chdev -l sys0 -a maxuproc=$value"
        echo "maxuproc changed."
        changed=1
      fi
      ;;
    "ncargs")
      curr_value=$(lsattr -El sys0 |awk '/^ncargs/ { print $2 }')
      if [ $value -ne $curr_value ]; then
        runcmd_nz "chdev -l sys0 -a ncargs=$value"
        echo "ncargs changed."
        changed=1
      fi
      ;;
    *)
      echo "ERROR: $name not supported."
      exit 1
      ;;
  esac
}

set_schedo() {
  name=$1
  value=$2
  curr_value=$(schedo -o $name | awk '{print $3}')
  if [ $value -ne $curr_value ]; then
    runcmd_nz "schedo -p -o ${name}=$value"
    echo "$name changed."
    changed=1
  fi
}

set_vmo() {
  name=$1
  value=$2
  curr_value=$(vmo -o $name | awk '{print $3}')
  # gridSetup.sh requires vmm_klock_mode to have "BOOT" value, i.e.
  # it has to be set in /etc/tunables/nextboot despite the default
  # value is 2 and is expected by gridSetup.sh.
  if [ $name == "vmm_klock_mode" ]; then
    if ! grep -q 'vmm_klock_mode = "2"' /etc/tunables/nextboot; then
      runcmd_nz "vmo -y -r -o ${name}=$value"
      echo "$name changed."
      changed=1
    fi
  else
    if [ $value -ne $curr_value ]; then
      runcmd_nz "vmo -y -r -o ${name}=$value"
      echo "$name changed."
      changed=1
    fi
  fi
}


################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################

changed=0

# Network Tuning Parameters from [1]
set_no tcp_recvspace 65536
set_no udp_recvspace 655360
set_no tcp_sendspace 65536
set_no udp_sendspace 65536
set_no rfc1323 1
set_no ipqmaxlen 512
set_no sb_max 4194304
# Following values are from [3]
set_no tcp_ephemeral_low 32768
set_no udp_ephemeral_low 32768
set_no tcp_ephemeral_high 65500
set_no udp_ephemeral_high 65500

# Max number of processes for each user from [1]
set_chdev maxuproc 16384
# System Block Size Allocation from [1]
set_chdev ncargs 1024
# Virtual Processor Manager from [1]
set_schedo vpm_xvcpus 2
# Following value is lifted from [2]
set_vmo vmm_klock_mode 2

if [ $changed -eq 1 ]; then
  echo "NOTE: MUST DO A REBOOT to AFFECT CHANGES!"; echo
fi

exit 0
