#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: $0 <host1> [<host2> ...]"
  exit 1
fi

shift
hosts=("$@")

for host in "${hosts[@]}"; do
  echo "Checking SSH connectivity from Ansible controller to $host"

  ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$host" date >/dev/null 2>&1
  rc=$?

  if [ $rc -ne 0 ]; then
    echo "SSH FAILED for $host"
    exit 1
  else
    echo "SSH SUCCESS for $host"
  fi
done

echo "All SSH checks passed"
