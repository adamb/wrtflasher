#!/bin/bash
# Client count script - shows WiFi clients per AP (not mesh neighbors)
# Only counts clients on 2.4GHz AP interfaces (Finca, IOT, Guest)

echo "=== WiFi Client Count per Node ==="
echo "Date: $(date)"
echo ""
echo "Counting clients on 2.4GHz AP interfaces only (Finca, IOT, Guest)"
echo "Note: 5GHz interfaces are mesh-only (no client WiFi)"
echo ""

# Node list: name IP
NAMES=("gw-office" "ap-central" "ap-prov" "ap-jade" "ap-ruffled" "ap-cust" "ap-news" "ap-surrender")
IPS=("192.168.1.1" "192.168.1.101" "192.168.1.117" "192.168.1.114" "192.168.1.125" "192.168.1.197" "192.168.1.175" "192.168.1.159")

total_all=0

for i in "${!NAMES[@]}"; do
    name="${NAMES[$i]}"
    ip="${IPS[$i]}"

    count=$(ssh -o ConnectTimeout=5 root@$ip "iw dev phy0-ap0 station dump 2>/dev/null | grep -E '^Station' | wc -l" 2>/dev/null)

    if [ -z "$count" ]; then
        echo "$name ($ip): SSH failed"
        continue
    fi

    printf "%-20s (%s): %2d clients\n" "$name" "$ip" "$count"
    total_all=$((total_all + count))
done

echo ""
echo "Total clients across all nodes: $total_all"
