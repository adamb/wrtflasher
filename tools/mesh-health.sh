#!/bin/bash
echo "=== MESH NETWORK HEALTH REPORT ==="
echo ""
echo "Generated: $(date)"
echo ""

# Build MAC to hostname mapping
MAC_MAP_FILE=$(mktemp)
trap "rm -f $MAC_MAP_FILE" EXIT

NODES=(
    "192.168.1.1:gw-office"
    "192.168.1.101:ap-central"
    "192.168.1.114:ap-jade"
    "192.168.1.125:ap-repay-ruffled"
    "192.168.1.157:ap-casita"
    "192.168.1.159:ap-replay-surrender"
    "192.168.1.167:ap-toilet"
    "192.168.1.117:ap-prov"
    "192.168.1.175:ap-news"
    "192.168.1.197:ap-cust"
)

for node in "${NODES[@]}"; do
    ip="${node%%:*}"
    name="${node##*:}"
    mac=$(ssh -o ConnectTimeout=2 root@$ip "cat /sys/class/ieee80211/phy1/macaddress 2>/dev/null | tr -d '\n'" 2>/dev/null)
    if [ -n "$mac" ]; then
        echo "$mac|$name" >> "$MAC_MAP_FILE"
    fi
done

# Lookup function to convert MAC to hostname
mac_to_name() {
    local mac=$1
    local name=$(grep "^${mac}|" "$MAC_MAP_FILE" 2>/dev/null | head -1 | cut -d'|' -f2)
    if [ -n "$name" ]; then
        echo "$name"
    else
        echo "$mac"
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. NEIGHBOR COUNT (Redundancy Check)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check_node() {
    ip=$1
    name=$2
    # Count only neighbors with good or excellent signal (>= -70 dBm)
    count=$(ssh -o ConnectTimeout=2 root@$ip "
        batctl meshif bat0 n 2>/dev/null | grep phy1-mesh0 | while read line; do
            neighbor_mac=\$(echo \$line | awk '{print \$2}')
            signal=\$(iw dev phy1-mesh0 station get \$neighbor_mac 2>/dev/null | grep 'signal avg' | awk '{print \$3}')
            if [ -n \"\$signal\" ] && [ \"\$signal\" -ge -70 ]; then
                echo \"\$neighbor_mac\"
            fi
        done | wc -l
    " 2>/dev/null | tr -d ' ')
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
check_node "192.168.1.125" "ap-repay-ruffled"
check_node "192.168.1.157" "ap-casita"
check_node "192.168.1.159" "ap-replay-surrender"
check_node "192.168.1.167" "ap-toilet"
check_node "192.168.1.117" "ap-prov"
check_node "192.168.1.175" "ap-news"
check_node "192.168.1.197" "ap-cust"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. MESH BACKHAUL SIGNAL STRENGTH (5GHz)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "%-15s → %-20s %10s  %s\n" "From Node" "To Neighbor" "Signal" "Quality"
echo "─────────────────────────────────────────────────────────────────────────"

check_signals() {
    from_ip=$1
    from_name=$2

    ssh -o ConnectTimeout=3 root@$from_ip "
        batctl meshif bat0 n 2>/dev/null | grep phy1-mesh0 | while read line; do
            neighbor_mac=\$(echo \$line | awk '{print \$2}')
            signal=\$(iw dev phy1-mesh0 station get \$neighbor_mac 2>/dev/null | grep 'signal avg' | awk '{print \$3}')
            if [ -n \"\$signal\" ]; then
                echo \"NEIGHBOR|\$neighbor_mac|\$signal\"
            fi
        done
    " 2>/dev/null | while IFS='|' read prefix mac signal; do
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

            # Lookup hostname from MAC
            neighbor_name=$(mac_to_name "$mac")

            printf "%-15s → %-20s %8s dBm  %s\n" "$from_name" "$neighbor_name" "$signal" "$quality"
        fi
    done
}

check_signals "192.168.1.1" "gw-office"
check_signals "192.168.1.101" "ap-central"
check_signals "192.168.1.114" "ap-jade"
check_signals "192.168.1.125" "ap-repay-ruffled"
check_signals "192.168.1.157" "ap-casita"
check_signals "192.168.1.159" "ap-replay-surrender"
check_signals "192.168.1.167" "ap-toilet"
check_signals "192.168.1.117" "ap-prov"
check_signals "192.168.1.175" "ap-news"
check_signals "192.168.1.197" "ap-cust"

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
for ip in 192.168.1.1 192.168.1.101 192.168.1.114 192.168.1.125 192.168.1.157 192.168.1.159 192.168.1.167 192.168.1.117 192.168.1.175 192.168.1.197; do
    # Count only neighbors with good or excellent signal (>= -70 dBm)
    count=$(ssh -o ConnectTimeout=2 root@$ip "
        batctl meshif bat0 n 2>/dev/null | grep phy1-mesh0 | while read line; do
            neighbor_mac=\$(echo \$line | awk '{print \$2}')
            signal=\$(iw dev phy1-mesh0 station get \$neighbor_mac 2>/dev/null | grep 'signal avg' | awk '{print \$3}')
            if [ -n \"\$signal\" ] && [ \"\$signal\" -ge -70 ]; then
                echo \"\$neighbor_mac\"
            fi
        done | wc -l
    " 2>/dev/null | tr -d ' ')
    if [ -n "$count" ] && [ "$count" -eq 1 ]; then
        weak=$((weak + 1))
    fi
done

if [ "$weak" -eq 0 ]; then
    echo "✅ All nodes have 2+ quality mesh neighbors (good redundancy)"
else
    echo "⚠️  $weak node(s) have only 1 quality mesh neighbor (single point of failure)"
fi

echo ""
