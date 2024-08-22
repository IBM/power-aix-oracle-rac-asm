#!/bin/bash

# Check if username is provided as an argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

# Define the list of hosts
hosts=("p224n95.pbm.ihost.com" "p224n96.pbm.ihost.com")

# Function to check SSH connectivity for a specific user
check_ssh_connectivity() {
    for host in "${hosts[@]}"; do
        echo "Checking SSH connectivity from $1@$2 to $host..."
        ssh -q -o BatchMode=yes -o ConnectTimeout=5 $1@$2 ssh -q -o BatchMode=yes -o ConnectTimeout=5 $1@$host exit
        if [ $? -eq 0 ]; then
            echo "SSH connectivity from $1@$2 to $host: Success"
        else
            echo "SSH connectivity from $1@$2 to $host: Failed"
        fi
    done
}

# Iterate through each host and check connectivity
for host in "${hosts[@]}"; do
    check_ssh_connectivity $1 $host
done

