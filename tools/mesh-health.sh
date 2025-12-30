#!/bin/bash
echo "=== MESH NETWORK HEALTH REPORT ==="
echo ""
echo "Generated: $(date)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. NEIGHBOR COUNT (Redundancy Check)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check_node() {
    ip=$1
    name=$2
    count=$(ssh -o ConnectTimeout=2 root@$ip "batctl meshif bat0 n 2>/dev/null | grep -c phy1-mesh0" 2>/dev/null)
    if [ -n "$count" ]; then
        if [ "$count" -ge 3 ]; then
            status="✅ GOOD"
        elif [ "$count" -eq 2 ]; then
            status="⚠️  OK"
        else
            status="❌ WEAK"
        fi
        printf "%-15s %-15s %d neighbors  %s\n" "$name" "($ip)" "$count" "$status"
    fi
}

check_node "192.168.1.1" "gw-office"
check_node "192.168.1.101" "ap-central"
check_node "192.168.1.114" "ap-jade"
check_node "192.168.1.157" "ap-casita"
check_node "192.168.1.167" "ap-toilet"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. MESH BACKHAUL SIGNAL STRENGTH (5GHz)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "%-15s → %-15s %10s  %s\n" "From Node" "To Neighbor" "Signal" "Quality"
echo "────────────────────────────────────────────────────────────────"

check_signals() {
    from_ip=$1
    from_name=$2
    
    ssh -o ConnectTimeout=3 root@$from_ip "
        batctl meshif bat0 n 2>/dev/null | grep phy1-mesh0 | while read line; do
            neighbor_mac=\$(echo \$line | awk '{print \$2}')
            signal=\$(iw dev phy1-mesh0 station get \$neighbor_mac 2>/dev/null | grep 'signal avg' | awk '{print \$3}')
            if [ -n \"\$signal\" ]; then
                echo \"NEIGHBOR:\$neighbor_mac:\$signal\"
            fi
        done
    " 2>/dev/null | while IFS=: read prefix mac signal; do
        if [ "$prefix" = "NEIGHBOR" ]; then
            # Determine quality
            if [ "$signal" -ge -60 ]; then
                quality="✅ Excellent"
            elif [ "$signal" -ge -70 ]; then
                quality="✅ Good"
            elif [ "$signal" -ge -80 ]; then
                quality="⚠️  Poor"
            else
                quality="❌ Very Poor"
            fi
            printf "%-15s → %-15s %8s dBm  %s\n" "$from_name" "${mac:0:17}" "$signal" "$quality"
        fi
    done
}

check_signals "192.168.1.1" "gw-office"
check_signals "192.168.1.101" "ap-central"
check_signals "192.168.1.114" "ap-jade"
check_signals "192.168.1.157" "ap-casita"
check_signals "192.168.1.167" "ap-toilet"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. BATMAN-ADV TOPOLOGY (Link Quality Scores)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "TQ scores: 255 = perfect, 200+ = good, <150 = poor"
echo ""

ssh root@192.168.1.1 "batctl meshif bat0 o 2>/dev/null" | head -30

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. HEALTH SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

weak=0
for ip in 192.168.1.1 192.168.1.101 192.168.1.114 192.168.1.157 192.168.1.167; do
    count=$(ssh -o ConnectTimeout=2 root@$ip "batctl meshif bat0 n 2>/dev/null | grep -c phy1-mesh0" 2>/dev/null)
    if [ -n "$count" ] && [ "$count" -eq 1 ]; then
        weak=$((weak + 1))
    fi
done

if [ "$weak" -eq 0 ]; then
    echo "✅ All nodes have 2+ mesh neighbors (good redundancy)"
else
    echo "⚠️  $weak node(s) have only 1 mesh neighbor (single point of failure)"
fi

echo ""
