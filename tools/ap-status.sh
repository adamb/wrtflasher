#!/bin/bash

# Check AP status: clients, WiFi modes, mesh connectivity
# Uses gateway as SSH jump host for APs, direct SSH for gateway

GATEWAY="192.168.1.1"

APS=(
    "192.168.1.159"
    "192.168.1.157"
    "192.168.1.114"
    "192.168.1.167"
    "192.168.1.101"
    "192.168.1.125"
    "192.168.1.117"
    "192.168.1.175"
    "192.168.1.197"
)

echo "=== MESH NODE STATUS REPORT ==="
echo "Generated: $(date)"
echo ""
printf "%-20s %-15s %8s | %-12s | %-12s | %s\n" "Hostname" "IP" "Clients" "2.4GHz Mode" "5GHz Mode" "Mesh"
echo "────────────────────────────────────────────────────────────────────────────────────────"

# Check gateway first (direct SSH, no jump host)
hostname=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$GATEWAY "uci get system.@system[0].hostname 2>/dev/null" 2>/dev/null)
clients=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$GATEWAY "iw dev 2>/dev/null | grep Interface | while read a iface; do iw dev \$iface station dump 2>/dev/null; done | grep -c '^Station'" 2>/dev/null)
htmode0=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$GATEWAY "uci get wireless.radio0.htmode 2>/dev/null" 2>/dev/null)
htmode1=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$GATEWAY "uci get wireless.radio1.htmode 2>/dev/null" 2>/dev/null)
mesh_neighbors=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$GATEWAY "batctl meshif bat0 n 2>/dev/null | grep -c phy1-mesh0" 2>/dev/null)

if [ -n "$clients" ]; then
    mode0="${htmode0:-auto}"
    mode1="${htmode1:-auto}"

    if [[ "$mode0" == HE* ]]; then
        mode0_label="$mode0 (WiFi 6)"
    else
        mode0_label="$mode0 (WiFi 4)"
    fi

    if [[ "$mode1" == HE* ]]; then
        mode1_label="$mode1 (WiFi 6)"
    else
        mode1_label="$mode1"
    fi

    mesh_status="${mesh_neighbors:-0} neighbors"
    printf "%-20s %-15s %8s | %-12s | %-12s | %s\n" "${hostname:-$GATEWAY}" "$GATEWAY" "$clients" "$mode0_label" "$mode1_label" "$mesh_status"
else
    printf "%-20s %-15s %8s | %-12s | %-12s | %s\n" "${hostname:-$GATEWAY}" "$GATEWAY" "OFFLINE" "-" "-" "-"
fi

# Check APs (via gateway jump host)
for ip in "${APS[@]}"; do
    hostname=$(ssh -J root@$GATEWAY -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$ip "uci get system.@system[0].hostname 2>/dev/null" 2>/dev/null)
    clients=$(ssh -J root@$GATEWAY -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$ip "iw dev 2>/dev/null | grep Interface | while read a iface; do iw dev \$iface station dump 2>/dev/null; done | grep -c '^Station'" 2>/dev/null)
    htmode0=$(ssh -J root@$GATEWAY -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$ip "uci get wireless.radio0.htmode 2>/dev/null" 2>/dev/null)
    htmode1=$(ssh -J root@$GATEWAY -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$ip "uci get wireless.radio1.htmode 2>/dev/null" 2>/dev/null)
    mesh_neighbors=$(ssh -J root@$GATEWAY -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$ip "batctl meshif bat0 n 2>/dev/null | grep -c phy1-mesh0" 2>/dev/null)

    if [ -n "$clients" ]; then
        # Determine if WiFi 6
        mode0="${htmode0:-auto}"
        mode1="${htmode1:-auto}"

        if [[ "$mode0" == HE* ]]; then
            mode0_label="$mode0 (WiFi 6)"
        else
            mode0_label="$mode0 (WiFi 4)"
        fi

        if [[ "$mode1" == HE* ]]; then
            mode1_label="$mode1 (WiFi 6)"
        else
            mode1_label="$mode1"
        fi

        mesh_status="${mesh_neighbors:-0} neighbors"

        printf "%-20s %-15s %8s | %-12s | %-12s | %s\n" "${hostname:-$ip}" "$ip" "$clients" "$mode0_label" "$mode1_label" "$mesh_status"
    else
        printf "%-20s %-15s %8s | %-12s | %-12s | %s\n" "${hostname:-$ip}" "$ip" "OFFLINE" "-" "-" "-"
    fi
done

echo ""
