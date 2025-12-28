#!/bin/bash

# Debug SSH key issues

echo "=== Debugging SSH key setup ==="
echo ""

NODE="192.168.1.1"

echo "1. Testing password-based SSH to $NODE..."
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@$NODE "echo 'Password auth works'" 2>&1
echo ""

echo "2. Checking authorized_keys file on $NODE..."
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@$NODE "ls -la /etc/dropbear/ /root/.ssh/ 2>/dev/null" 2>&1
echo ""

echo "3. Checking authorized_keys content on $NODE..."
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@$NODE "cat /etc/dropbear/authorized_keys /root/.ssh/authorized_keys 2>/dev/null | tail -1" 2>&1
echo ""

echo "4. Our public key:"
cat ~/.ssh/mesh_nodes.pub
echo ""

echo "5. Testing key-based auth with verbose output..."
ssh -v -i ~/.ssh/mesh_nodes -o PreferredAuthentications=publickey root@$NODE "hostname" 2>&1 | grep -E "Offering|Authentications|publickey"
