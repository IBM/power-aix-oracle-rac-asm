# Copyright (c) IBM Corporation 2021

# This script configures the network interfaces for
# 1) interface address
# 2) netmask
# 3) gateway address
# 4) monitor flag
# 5) hostname

# Idempotent: yes

# Usage: mktcpip.sh <network_spec> ...
# where <network_spec> is enclosed by double quotes with
# the following ordered list separated by a space
# network name ('pub', 'ora_pub', 'ora_pvt1', 'ora_pvt2')
# hostname
# interface
# IP address
# netmask
# optional gateway

debug=0
typeset -a args
for a in "$@"; do
  args+=("$a")
done

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

  #+ make sure this script is running as this user.
check_user_is root

help() {
  echo "\nUsage: $(basename $0) <network_spec> ..."
  echo "where <network_spec> is \"<name> <hostname> <interface> <address> <netmask> [gateway_address]\""
  exit 1
}

function set_monitor_flag_on_boot {
  intf=$1;
  file="/etc/rc.net"
  if ! egrep "^ifconfig[ ]*${intf}[ ]*monitor" $file; then
    echo "ifconfig $intf monitor" >> $file
    echo "$file changed - added monitor flag to ${intf}."
  fi
}

# Returns the following combination of "bit" as an integer
# 0   No change needed
# 1   Change needed for monitor flag
# 2   Change needed for address and/or netmask
# 4   Change needed monitor for virtual Ethernet
get_current_settings() {
  return_code=0
  addr_mask=$(ifconfig $intf | awk '/net/ { print $2, $4, monitor }; /MONITOR/ { monitor="MONITOR"}')
  set -- $addr_mask
  c_addr=$1
  c_mask=$2
  c_monitor=$3
  c_mask=$(echo $c_mask | perl -pe '$_ =~ s/0x//; $_ = join(".", map(hex, /.{2}/g))')
  [[ $debug -eq 1 ]] && \
    echo "DEBUG: get_current_settings(): intf=$intf, initial return_code=$return_code"
  [[ $addr != $c_addr ]] || [[ $mask != $c_mask ]] && ((return_code += 2))
  [[ $debug -eq 1 ]] && \
    echo "DEBUG: intf=$intf, addr=$addr, c_addr=$c_addr, mask=$mask, c_mask=$c_mask, return_code=$return_code"
  [[ -z "$c_monitor" ]] && ((return_code += 1))
    echo "DEBUG: intf=$intf, c_monitor=[$c_monitor], return_code=$return_code"
  if lsattr -El $(echo $intf | sed -e 's/en/ent/') | grep -q uplink; then
    virt_eth_monitor=$(lsattr -El $intf | awk '/^monitor/ { print $2 }')
    [ "$virt_ether_monitor" == "off" ] && ((return_code += 4))
  fi
  [[ $debug -eq 1 ]] && \
    echo "DEBUG: intf=$intf, virt_ether_monitor=[$virt_ether_monitor], return_code=$return_code"
  return $return_code
}

################################################################################
#                                                                              #
# Main                                                                         #
#                                                                              #
################################################################################

[ $# -eq 0 ] && help

gateway_intf=$(netstat -rn | awk '/^default/ { printf("%s %s\n", $2, $6); }')
set -- $gateway_intf
curr_gateway_addr=$1
curr_gateway_intf=$2
if [ -n "$curr_gateway_addr" ] && [ -z "$curr_gateway_intf" ]; then
  echo "ERROR: Found existing gateway address but missing interface."
  exit 1
fi
if [ -z "$curr_gateway_addr" ] && [ -n "$curr_gateway_intf" ]; then
  echo "ERROR: Found existing gateway interface but missing gateway address."
  exit 1
fi

typeset -a update_cmds
changed_intfs=""        # change in address, mask, and/or monitor
ora_pub_hostname=""
changed_hostname=0
changed_monitor_flag_on_boot=0

for net_spec in "${args[@]}"; do
  set -- $net_spec
  netname=$1
  hname=$2
  intf=$3
  addr=$4
  mask=$5
  gateway_addr=$6
  intf_changed=0

  [ "$netname" = "ora_pub" ] && ora_pub_hostname="$hname"

  if [ -n "$gateway_addr" ]; then
    if [ -z "$curr_gateway_intf" ]; then
      update_cmds+=("chdev -l inet0 -a route=net,-hopcount,0,-if,${intf},,0,${gateway_addr}")
      intf_changed=1
    else
      if [ "$intf" != "$curr_gateway_intf" ] || [ "$gateway_addr" != "$curr_gateway_addr" ]; then
        update_cmds+=("chdev -l inet0 -a delroute=$(lsattr -El inet0 | awk '$2 ~ /hopcount/ { print $2 }')")
        update_cmds+=("chdev -l inet0 -a route=net,-hopcount,0,-if,${intf},,0,${gateway_addr}")
        intf_changed=1
      fi
    fi
  fi

  get_current_settings
  rc=$?
  [[ $debug -eq 1 ]] && \
    echo "DEBUG: netname=$netname, rc=$rc"

  if [ $intf_changed -eq 0 ] && [ $rc -eq 0 ]; then
    continue
  fi
    
  changed_intfs="$changed_intfs $intf"
  [[ $(( 4 & $rc )) -ne 0 ]] && update_cmds+=("chdef -l $intf -P -a monitor=on")
  [[ $(( 2 & $rc )) -ne 0 ]] && update_cmds+=("mktcpip -h $hname -i $intf -a $addr -m $mask -t N/A")
  # set monitor flag must go after interface is created
  if [[ $(( 1 & $rc )) -ne 0 ]]; then
    update_cmds+=("ifconfig $intf monitor")
  fi
  set_monitor_flag_on_boot $intf
done

for cmd in "${update_cmds[@]}"; do
  echo "$cmd"
  runcmd_nz "$cmd"
done

# Change of hostname must be the last command
[[ $debug -eq 1 ]] && \
  echo "DEBUG: hostname=$(hostname), ora_pub_hostname=$ora_pub_hostname"
if [ "$(hostname)" != "$ora_pub_hostname" ]; then
  runcmd_nz "chdev -l inet0 -a hostname=$ora_pub_hostname"
  echo "hostname changed to $ora_pub_hostname"
  changed_hostname=1
fi

for intf in $changed_intfs; do
  echo "$intf changed"
done

[[ -z "$changed_intfs" ]] && [[ $changed_hostname -eq 0 ]] &&  \
echo "No change."

exit 0
