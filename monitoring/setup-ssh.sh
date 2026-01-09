#!/bin/bash
#
# Setup SSH ControlMaster for persistent connections
# This reduces SSH overhead from ~100ms per command to <1ms
#

set -e

SOCKET_DIR="$HOME/.ssh/sockets"

echo "=== SSH ControlMaster Setup ==="
echo ""

# Create socket directory
if [ ! -d "$SOCKET_DIR" ]; then
    echo "Creating socket directory: $SOCKET_DIR"
    mkdir -p "$SOCKET_DIR"
    chmod 700 "$SOCKET_DIR"
else
    echo "✓ Socket directory exists: $SOCKET_DIR"
fi

# Ensure ~/.ssh has correct permissions
chmod 700 "$HOME/.ssh" 2>/dev/null || true

# Check if ControlMaster already configured
if grep -q "^Host 192.168.1.\*" "$HOME/.ssh/config" 2>/dev/null; then
    echo "✓ SSH config already has mesh network configuration"
else
    echo ""
    echo "Adding ControlMaster config to ~/.ssh/config..."

    # Backup existing config
    if [ -f "$HOME/.ssh/config" ]; then
        cp "$HOME/.ssh/config" "$HOME/.ssh/config.backup.$(date +%s)"
        echo "  (backed up existing config)"
    fi

    # Add mesh network specific config
    cat >> "$HOME/.ssh/config" <<'EOF'

# Mesh network nodes - persistent connections
Host 192.168.1.*
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h:%p
    ControlPersist 10m
    ServerAliveInterval 30
    ServerAliveCountMax 3
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF

    echo "✓ SSH config updated"
fi

echo ""
echo "=== Testing SSH Access ==="
echo ""

# Test access to all nodes
NODES=(
    "192.168.1.1:gw-office"
    "192.168.1.101:ap-central"
    "192.168.1.114:ap-jade"
    "192.168.1.157:ap-casita"
    "192.168.1.167:ap-toilet"
)

SUCCESS=0
FAILED=0

for node in "${NODES[@]}"; do
    ip=$(echo $node | cut -d: -f1)
    name=$(echo $node | cut -d: -f2)

    printf "%-15s (%s) ... " "$name" "$ip"

    if ssh -i ~/.ssh/mesh_nodes -o ConnectTimeout=3 root@$ip "hostname" >/dev/null 2>&1; then
        echo "✓"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "✗ FAILED"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "Results: $SUCCESS successful, $FAILED failed"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo "✓ Setup complete! ControlMaster is ready."
    echo ""
    echo "Next steps:"
    echo "  1. Copy config.yaml.example to config.yaml"
    echo "  2. Edit config.yaml with your MQTT credentials"
    echo "  3. Run: python3 main.py"
else
    echo ""
    echo "⚠ Some nodes failed SSH access."
    echo "Make sure SSH key is distributed to all nodes:"
    echo "  ssh-copy-id -i ~/.ssh/mesh_nodes root@<node-ip>"
fi

echo ""
