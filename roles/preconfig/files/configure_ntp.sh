# Copyright (c) IBM Corporation 2021

# This script configures NTP service:
# 1) update broadcast client
# 2) add "-x" to xntpd to prevent time from drifting backward
# 3) set up autostart on boot

# https://www.ibm.com/docs/en/aix/7.2?topic=files-ntpconf-file
#
# Idempotent: yes

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

# make sure this script is running as this user.
check_user_is root

ntp_conf="/etc/ntp.conf"
rc_tcpip="/etc/rc.tcpip"

typeset -a servers

usage() {
  echo "ERROR: Invalid arguments."
  echo "Usage: configure_ntp.sh {<done_dir>} {<server> [prefer]} [<server> ...]"
  echo "                        [broadcastclient:{present}|{absent}]"
  echo
  echo "The script supports minimal configuration of NTP in client/server mode."
  echo "The desired time servers and broadcastclient options can be set."
  echo "Notice that servers specified will be configured in the /etc/ntp.conf."
  echo "Pre-existing servers that are not specified will be deleted. Also,"
  echo "\"<server>\" and \"<server> prefer\" are treated as two different servers."
  echo "If the servers specified match the pre-existing servers, the file will"
  echo "not be updated. <server> is either an IP address or DNS name. Optionally,"
  echo "\"prefer\" can follow immediately, in which case, it's associated with"
  echo "the <server> that comes before it. At least one <server> must be"
  echo "specified, otherwise it is an error. The default for broadcastclient"
  echo "option is \"present\", if it is \"absent\", broadcastclient option will be"
  echo "commented out."
  exit 1
}

[ $# -eq 0 ] && usage

update_broadcastclient() {
  if [ $state == "present" ]; then
    if grep -q '^broadcastclient' $ntp_conf; then
      update_cmd=""
    elif egrep -q '^#.*broadcastclient' $ntp_conf; then
       update_cmd="/^#.*broadcastclient\ns/#.*broadcastclient/broadcastclient/
\np\nw\nq\n"
    else
      # add broadcastclient
      update_cmd="/^[a-z]\ni\nbroadcastclient\n.\nw\nq\n"
    fi
  elif [ $state == "absent" ]; then
    if grep -q "^#.*broadcastclient" $ntp_conf; then
      update_cmd=""
    elif grep -q ^broadcastclient $ntp_conf; then
      update_cmd="/^broadcastclient\ns/broadcastclient/# broadcastclient/\nw\nq\n"
    else
      update_cmd="/^[a-z]\ni\n# broadcastclient\n.\nw\nq\n"
    fi
  fi

  if [ -n "$update_cmd" ]; then
    echo "$update_cmd" | ed -s $ntp_conf
    echo "broadcastclient changed in $ntp_conf"
    config_changed=1
  fi
} # update_broadcastclient


# Update ntp servers in /etc/ntp.conf from command line arguments
update_servers() {
  typeset -a curr_servers
  typeset -a delete_curr_servers  # delete current's b/c no match in requested
  typeset -a add_servers          # final to add after filtered out matched
  update_cmd=""

  grep ^server $ntp_conf | while read s; do
    _s=$(expr "$s" : 'server[ ]*\(.*\)')
    curr_servers+=("$_s")
  done

  num_curr_servers=${#curr_servers[@]}
  if [ $num_curr_servers -gt 0 ]; then
    for i in {0..$(($num_curr_servers - 1))}; do
      match=0
      for j in {0..$((${#servers[@]} - 1))}; do
        if [ "${curr_servers[$i]}" == "${servers[$j]}" ]; then
          match=1
          servers[$j]="";
          break
        fi
      done
      if [ $match -eq 0 ]; then
        delete_curr_servers+=("${curr_servers[$i]}")
      fi
    done
  fi

  if [ -n "${servers[0]}" ]; then
    for j in {0..$((${#servers[@]} - 1))}; do
      if [ "${servers[$j]}" != "" ]; then
        add_servers+=("${servers[j]}")
      fi
    done
  fi

  add_cmd=""
  if [ ${#add_servers[@]} -gt 0 ]; then
    for i in {0..$((${#add_servers[@]} - 1))}; do
      add_cmd="$add_cmd\n/broadcastclient\na\nserver ${add_servers[$i]}\n.\n"
    done
  fi

  delete_cmd=""
  if [ ${#delete_curr_servers[@]} -gt 0 ]; then
    for i in {0..$((${#delete_curr_servers[@]} - 1))}; do
      delete_cmd="$delete_cmd\n/server.*${delete_curr_servers[$i]}\nd\n"
    done
  fi

  if [ -n "$add_cmd" ] || [ -n "$delete_cmd" ]; then
    update_cmd="${delete_cmd}${add_cmd}w\nq\n"
  fi

  if [ -n "$update_cmd" ]; then
    echo "$update_cmd" | ed -s $ntp_conf
    echo "server option changed in $ntp_conf"
    config_changed=1
  fi
} # update_servers


check_servers_accessiblity() {
  typeset -a ntpdate_servers
  grep ^server $ntp_conf | while read _s; do
    s=$(echo "$_s" | awk '{print $2}')
    ntpdate_servers+=("$s")
  done

  if [ ${#ntpdate_servers[@]} -eq 0 ]; then
    echo "ERROR: No ntp servers found in $ntp_conf."
    exit 1
  fi
  
  if ps -ef | grep -q /usr/sbin/xntpd | grep -v grep; then
    runcmd_nz "stopsrc -s xntpd"
    sleep 2
  fi

  # Initial ntp update. Success from one server is good enough.
  good_server=""
  for i in {0..$((${#ntpdate_servers[@]} - 1))}; do
    server=${ntpdate_servers[$i]}
    for j in {0..4}; do
      if ntpdate -q $server 2>&1; then
        good_server=$server
        break
      fi
      sleep 5
    done
    [ -n "$good_server" ] && break
  done
  if [ -z "$good_server" ]; then
    echo "ERROR: ntpdate failed."
    exit 1
  fi
} # check_servers_accessiblity


################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################

# Parse arguments

state="present"
for arg in "$@"; do
  if echo $arg | egrep -q 'broadcastclient:'; then
    state=$(expr $arg : 'broadcastclient:\(.*\)')
    [ -z "$state" ] && state="present"
    echo "$state" | egrep -q 'present|absent'
    if [ $? -ne 0 ]; then
      echo "ERROR: broadcastclient argument $arg is invalid"
      exit 1
    fi
  else
    if echo $arg | grep -q prefer; then
      ((j = ${#servers[@]} - 1))
      servers[$j]="${servers[$j]} prefer"
    else
      servers+=($arg)
    fi
  fi
done

for f in $ntp_conf $rc_tcpip; do
  save_original $f
done

update_broadcastclient
update_servers

# Add "-x" to prevent time from stepping backward in cluster database enviroment

config_changed=0
if ! grep -q 'start /usr/sbin/xntpd "$src_running" "-x"' $rc_tcpip; then
  update_cmd="/start \/usr\/sbin\/xntpd \"\$src_running\"\nd\ni\nstart /usr/sbin/xntpd \"\$src_running\" \"-x\"\n.\nw\nq\n"
  echo "$update_cmd" | ed -s $rc_tcpip
  config_changed=1
fi

if [ $config_changed -eq 1 ]; then
  check_servers_accessiblity
  if lssrc -s xntpd |grep -q active; then
    runcmd_nz "stopsrc -s xntpd"
  fi
  runcmd_nz "startsrc -s xntpd -a \"-x\""
fi

exit 0
