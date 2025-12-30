#!/bin/bash
echo "=== ACTIVELY CONNECTED DEVICES ON OLD SSIDs ==="
echo "(Filtering out stale associations with >30s inactive time)"
echo ""

leases=$(ssh root@192.168.1.1 "cat /tmp/dhcp.leases")

for node_ip in 192.168.1.1 192.168.1.101 192.168.1.167; do
    node_name=$(ssh -o ConnectTimeout=2 root@$node_ip "uci get system.@system[0].hostname 2>/dev/null" 2>/dev/null)
    
    for iface in phy0-ap3 phy0-ap4; do
        ssid=$(ssh -o ConnectTimeout=2 root@$node_ip "iw dev $iface info 2>/dev/null | grep ssid | sed 's/.*ssid //' " 2>/dev/null)
        
        active_devices=$(ssh -o ConnectTimeout=3 root@$node_ip "
            iw dev $iface station dump 2>/dev/null | awk '
                /^Station/ {mac=\$2}
                /inactive time:/ {
                    inactive=\$3
                    if (inactive < 30000) print mac
                }
            '
        " 2>/dev/null)
        
        if [ -n "$active_devices" ]; then
            count=$(echo "$active_devices" | wc -l)
            echo "--- $node_name ($iface: $ssid) - $count active ---"
            echo "$active_devices" | while read mac; do
                info=$(echo "$leases" | grep -i "$mac" | head -1)
                if [ -n "$info" ]; then
                    name=$(echo "$info" | awk '{print $4}')
                    ip=$(echo "$info" | awk '{print $3}')
                    printf "  %-30s %s\n" "$name" "$ip"
                else
                    printf "  %-30s\n" "$mac"
                fi
            done
            echo ""
        fi
    done
done
