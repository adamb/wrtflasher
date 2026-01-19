#!/bin/bash
# Continuously monitor for a device to connect
# Usage: ./monitor-device.sh <MAC|partial MAC>

if [ -z "$1" ]; then
    echo "Usage: $0 <MAC address|partial MAC>"
    echo ""
    echo "Examples:"
    echo "  $0 cc:22:93:35:96:6d"
    echo "  $0 96:6d"
    exit 1
fi

SEARCH="$1"
INTERVAL="${2:-5}"  # Check every 5 seconds by default

echo "=== Monitoring for device: $SEARCH ==="
echo "Checking every ${INTERVAL} seconds (Ctrl+C to stop)"
echo ""

while true; do
    # Discover all nodes
    ap_ips=$(ssh root@192.168.1.1 "cat /tmp/dhcp.leases | grep -E 'ap-' | awk '{print \$3}' | sort" 2>/dev/null)
    all_nodes="192.168.1.1 $ap_ips"

    # Search all APs for the device
    for node_ip in $all_nodes; do
        # Use jump host for APs, direct connection for gateway
        if [ "$node_ip" = "192.168.1.1" ]; then
            SSH_CMD="ssh -o ConnectTimeout=2 root@$node_ip"
        else
            SSH_CMD="ssh -J root@192.168.1.1 -o ConnectTimeout=3 root@$node_ip"
        fi

        node_name=$($SSH_CMD "uci get system.@system[0].hostname 2>/dev/null" 2>/dev/null)

        for iface in phy0-ap0 phy0-ap1 phy0-ap2; do
            result=$($SSH_CMD "iw dev $iface station dump 2>/dev/null | grep -i '$SEARCH'" 2>/dev/null)

            if [ -n "$result" ]; then
                # Extract full MAC from result
                full_mac=$(echo "$result" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
                ssid=$($SSH_CMD "iw dev $iface info 2>/dev/null | grep ssid | sed 's/.*ssid //'" 2>/dev/null)

                timestamp=$(date '+%Y-%m-%d %H:%M:%S')
                echo "[$timestamp] ✓ DEVICE CONNECTED!"
                echo "  Node: $node_name ($node_ip)"
                echo "  Interface: $iface"
                echo "  SSID: $ssid"
                echo "  MAC: $full_mac"
                echo ""

                # Get detailed station info
                echo "  Connection details:"
                $SSH_CMD "iw dev $iface station get $full_mac 2>/dev/null | grep -E 'signal|bitrate|inactive|connected time'" 2>/dev/null | sed 's/^/    /'
                echo ""
            fi
        done
    done

    sleep $INTERVAL
done
