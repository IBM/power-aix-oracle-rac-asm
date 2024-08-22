#!/bin/bash

# Check if username and hosts are provided as arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <username> <host1> [<host2> ...]"
    exit 1
fi

# Extract username and hosts from arguments
username=$1
shift
hosts=("$@")



# Function to update known_hosts with SSH keys
update_known_hosts() {
    for host in "${hosts[@]}"; do
        aliases=$(awk -v hst="$host" '$2 == hst { for (i=3; i<=NF; i++) { if ($i != hst) print $i } }' /etc/hosts)
        echo "Updating known_hosts with SSH keys for $host..."
        su - "$username" -c "ssh-keyscan -H $aliases >> /home/$username/.ssh/known_hosts"
    done
}

# Update known_hosts file
update_known_hosts



# Function to check SSH connectivity for a specific user
check_ssh_connectivity() {
    for host in "${hosts[@]}"; do
        echo "Checking SSH connectivity from $username@$2 to $host..."
        ssh -q -o BatchMode=yes -o ConnectTimeout=5 $username@$2 ssh -q -o BatchMode=yes -o ConnectTimeout=5 $username@$host date
        if [ $? -eq 0 ]; then
            echo "SSH connectivity from $username@$2 to $host: Success"
        else
            echo "SSH connectivity from $username@$2 to $host: Failed"
        fi
    done
}

# Iterate through each host and check connectivity
for host in "${hosts[@]}"; do
    check_ssh_connectivity $username $host
done

