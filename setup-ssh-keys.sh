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
    "192.168.1.114"    # ap
    "192.168.1.157"    # ap
    "192.168.1.101"    # ap
    "192.168.1.167"    # ap
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
    ssh -i ~/.ssh/mesh_nodes root@$ip "hostname" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ OK"
    else
        echo "✗ Failed"
    fi
done

echo ""
echo "Done! You can now use: ssh -i ~/.ssh/mesh_nodes root@<ip>"
