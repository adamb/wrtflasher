#!/bin/bash

# Setup SSH keys on all mesh nodes
# Run this script and enter the root password when prompted for each node

echo "=== Setting up SSH keys on mesh nodes ==="
echo ""
echo "Public key: ~/.ssh/mesh_nodes.pub"
echo "You'll be prompted for the root password for each node"
echo ""

NODES=(
    "192.168.1.1"      # gw-office
    "192.168.1.114"    # ap-jade
    "192.168.1.157"    # ap-casita
    "192.168.1.101"    # ap-central
    "192.168.1.125"    # ap-repay-ruffled
    "192.168.1.159"    # ap-replay-surrender
    "192.168.1.167"    # ap-toilet
    "192.168.1.117"    # ap-prov
    "192.168.1.175"    # ap-news
    "192.168.1.197"    # ap-cust
)

for ip in "${NODES[@]}"; do
    echo "→ Setting up key on $ip"
    ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/mesh_nodes.pub root@$ip
    if [ $? -eq 0 ]; then
        echo "✓ Success"
    else
        echo "✗ Failed"
    fi
    echo ""
done

echo "=== Testing passwordless SSH ==="
for ip in "${NODES[@]}"; do
    echo "→ Testing $ip"
    result=$(ssh -i ~/.ssh/mesh_nodes root@$ip "cat /proc/sys/kernel/hostname" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "✓ OK - $result"
    else
        echo "✗ Failed"
    fi
done

echo ""
echo "Done! You can now use: ssh -i ~/.ssh/mesh_nodes root@<ip>"
