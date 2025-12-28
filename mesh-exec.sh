#!/bin/bash

# Run a command on all mesh nodes via SSH

if [ -z "$1" ]; then
    echo "Usage: $0 \"command to run\""
    echo "Example: $0 \"uci show wireless.radio0.channel\""
    exit 1
fi

COMMAND="$1"

NODES=(
    "192.168.1.1"      # gw-office (gateway)
    "192.168.1.114"    # ap-XXXX
    "192.168.1.157"    # ap-XXXX
    "192.168.1.101"    # ap-central
    "192.168.1.167"    # ap-XXXX
)

echo "Running command on all nodes: $COMMAND"
echo "========================================"
echo ""

for node in "${NODES[@]}"; do
    echo "→ $node"
    ssh -i ~/.ssh/mesh_nodes -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$node "$COMMAND" 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ Success"
    else
        echo "✗ Failed"
    fi
    echo ""
done

echo "========================================"
echo "Done"
