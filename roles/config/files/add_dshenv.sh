#!/usr/bin/ksh93

# Copyright (c) IBM Corporation 2021

# This script adds DSH_* variables to /etc/environment from config.dsh list.
# Create a file specified by config.dsh.DSH_NODE_LIST that contains the
# RAC node names.
# Save original /etc/environment.

# Idempotent: yes

if [ ! -f ./helper.sh ]
then
    echo "$(basename $0): helper.sh not found in $(pwd)"
    exit 1
fi

. ./helper.sh

  #+ make sure this script is running as this user.
check_user_is root

FILE=/etc/environment
save_original $FILE

help() {
  echo "\nUsage: $(basename $0) -n \"node node ...\" <DSH_OPTIONS>"
  echo "where <DSH_OPTIONS> are space-separated options, double-quoted"
  echo "the option when necessary."
  exit 1
}

nodes=""
while getopts n: opt
do
  case $opt in
    n) nodes="$OPTARG";;
    *) echo "ERROR: Invalid option: $OPTARG."
       help;;
  esac
done

[ -z "nodes" ] && help
shift $((OPTIND - 1))

#
# Store arguments in "wanted" array
#
typeset -a wanted
wanted_i=-1
for i in "$@"; do
  ((wanted_i++))
  wanted+=("$i")
done

#
# Store existing DSH_* entries in "existing" array
#
existing_i=-1
typeset -a existing
egrep '^DSH_' $FILE | while read e; do
  ((existing_i++))
  existing+=($e)
done

#
# Delete unwanted entries
#
if [ $existing_i -ge 0 ]; then
  update_cmd=""
  for i in {0..$existing_i}; do
    e="${existing[$i]}"
    e_name=$(expr "$e" : '^\([A-Z][A-Z_]*\)=.*')
    e_value=$(expr "$e" : '^[A-Z][A-Z_]*=\(.*\)')
    name_matched=0
    for j in {0..$wanted_i}; do
      w="${wanted[$j]}";
      w_name=$(expr "$w" : '^\([A-Z][A-Z_]*\)=.*')
      w_value=$(expr "$w" : '^[A-Z][A-Z_]*=\(.*\)')
      if [ "$e" == "$w" ]; then
        name_matched=1
        break
      elif [ $e_name == $w_name ]; then
        name_matched=1
        update_cmd="${update_cmd}1\n/^${e_name}=\nd\n"
        break
      fi
    done
    if [ $name_matched -eq 0 ]; then
      update_cmd="${update_cmd}/1\n/^${e_name}=\nd\n"
    fi
  done

  if [ -n "$update_cmd" ]; then
    echo "update_cmd=[$update_cmd]"
    echo "${update_cmd}w\nq\n" | ed -s $FILE
    echo "$FILE changed for deleting unwanted entry/entries."
  fi
fi

#
# Add wanted entries if non-exist
#
update_cmd=""
add_entry_str=""
dsh_node_list=""
for i in {0..$wanted_i}; do
  w="${wanted[$i]}";
  w_name=$(expr "$w" : '^\([A-Z][A-Z_]*\)=.*')
  if [ $w_name == "DSH_NODE_LIST" ]; then
    dsh_node_list=$(expr "$w" : '^[A-Z][A-Z_]*=\(.*\)')
  fi
  count=$(egrep -c "^${w}$" $FILE)
  case $count in
    0) add_entry_str="${add_entry_str}, $w_name"
       update_cmd="${update_cmd}a\n${w}\n.\n"
       ;;
    1) ;;
    *) # If more than one entries exist, delete them leaving only one.
       ((count--))
       for j in {1..$count}; do
         update_cmd="${update_cmd}/^${w_name}=\nd\n"
       done
       ;;
  esac
done
if [ -n "$update_cmd" ]; then
  echo "${update_cmd}w\nq\n" | ed -s $FILE
  echo "$FILE changed for adding ${add_entry_str} entry/entries."
fi

# NOTE: DSH_NODE_LIST variable has replaced WCOLL env var (see man dsh).
if [ -z "$dsh_node_list" ]; then
  echo "ERROR: DSH_NODE_LIST not specified in config.dsh."
  exit 1
fi

#
# Update file specified in DSH_NODE_LIST
#

FILE=$dsh_node_list
node_list_dir=$(dirname $FILE)
[ $node_list_dir != "/" ] && mkdir -p $nodelist_dir
if [ ! -f $FILE ]; then
  ( for n in $nodes; do
      echo "$n"
    done
  ) > $FILE
  echo "$FILE changed for adding ${nodes}."
else
  # Store existing node names in "existing" array
  unset existing
  typeset -a existing
  existing_i=-1
  while read n; do
    ((existing_i++))
    existing+=($n)
  done < $FILE

  # Delete unwanted entries
  delete_cmd=""
  delete_entry_str=""
  if [ $existing_i -ge 0 ]; then
    for i in {0..$existing_i}; do
      matched=0
      for n in $nodes; do
        if [ ${existing[$i]} == $n ]; then
          matched=1
          break
        fi
      done
      if [ $matched -eq 0 ]; then
        delete_cmd="${delete_cmd}/^${existing[$i]}$\nd\n"
        delete_entry_str="${delete_entry_str} ${existing[$i]},"
      fi
    done
  fi
  if [ -n "$delete_cmd" ]; then
    echo "${delete_cmd}w\nq\n" | ed -s $FILE
    echo "$FILE changed for deleting ${delete_entry_str}."
  fi

  # Add wanted entries if non-exist
  delete_cmd=""
  add_cmd=""
  add_entry_str=""
  delete_entry_str=""
  for n in $nodes; do
    count=$(grep -c "^${n}$" $FILE)
    case $count in
      0) add_entry_str="${add_entry_str} ${n},"
         add_cmd="${add_cmd}a\n$n\n.\n"
         ;;
      1) ;;
      *) ((count--))
         for j in {1..$count}; do
           delete_cmd="${delete_cmd}/^${n}$\nd\n"
           delete_entry_str="${delete_entry_str} ${n},"
         done
         ;;
    esac
  done
  if [ -n "$delete_cmd" ]; then
    echo "${delete_cmd}w\nq\n" | ed -s $FILE
    echo "$FILE changed for deleting ${delete_entry_str}."
  fi
  if [ -n "$add_cmd" ]; then
    echo "${add_cmd}w\nq\n" | ed -s $FILE
    echo "$FILE changed for adding ${add_entry_str}."
  fi
fi

exit 0
