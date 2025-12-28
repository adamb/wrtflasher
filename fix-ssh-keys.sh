#!/bin/bash

# Fix SSH keys for OpenWRT nodes (using dropbear)
# OpenWRT stores keys in /etc/dropbear/authorized_keys

echo "=== Setting up SSH keys for OpenWRT nodes ==="
echo ""

PUBKEY=$(cat ~/.ssh/mesh_nodes.pub)

NODES=(
    "192.168.1.1"
    "192.168.1.114"
    "192.168.1.157"
    "192.168.1.101"
    "192.168.1.167"
)

for ip in "${NODES[@]}"; do
    echo "→ Setting up key on $ip"

    # Create directory and add key using password auth
    ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@$ip "
        mkdir -p /etc/dropbear
        echo '$PUBKEY' >> /etc/dropbear/authorized_keys
        chmod 600 /etc/dropbear/authorized_keys
        echo 'Key added to /etc/dropbear/authorized_keys'
    " 2>&1

    if [ $? -eq 0 ]; then
        echo "✓ Success"
        # Test key-based auth
        echo "  Testing key auth..."
        result=$(ssh -i ~/.ssh/mesh_nodes -o PreferredAuthentications=publickey root@$ip "cat /proc/sys/kernel/hostname" 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "  ✓ Key auth works! ($result)"
        else
            echo "  ✗ Key auth still failing"
        fi
    else
        echo "✗ Failed"
    fi
    echo ""
done

echo "Done!"
