#!/bin/bash

# Diagnose SSH key issues on one node

NODE="192.168.1.1"

echo "=== Diagnosing SSH setup on $NODE ==="
echo ""

ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@$NODE bash <<'ENDSSH'

echo "1. Checking authorized_keys file:"
ls -la /etc/dropbear/authorized_keys
echo ""

echo "2. Content of authorized_keys:"
cat /etc/dropbear/authorized_keys
echo ""

echo "3. Number of keys in file:"
grep -c "ssh-" /etc/dropbear/authorized_keys
echo ""

echo "4. Dropbear processes:"
ps | grep dropbear
echo ""

echo "5. Restarting dropbear..."
/etc/init.d/dropbear restart
echo ""

echo "6. Checking if dropbear accepts pubkey auth:"
grep -i "pubkey\|RootPasswordAuth" /etc/config/dropbear 2>/dev/null || echo "No dropbear config restrictions found"
echo ""

ENDSSH

echo ""
echo "Now testing key-based auth..."
sleep 2
ssh -i ~/.ssh/mesh_nodes -o PreferredAuthentications=publickey root@$NODE "hostname"

if [ $? -eq 0 ]; then
    echo "✓ Key auth works now!"
else
    echo "✗ Still failing"
    echo ""
    echo "Trying with verbose output:"
    ssh -v -i ~/.ssh/mesh_nodes root@$NODE "hostname" 2>&1 | grep -E "debug1|Offering|Authentications"
fi
