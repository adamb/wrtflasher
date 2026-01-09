#!/bin/bash
echo "=== Scanning All Connected Devices ==="
echo ""

RESULTS=$(mktemp)
trap "rm -f $RESULTS" EXIT

NODES=(
    "192.168.1.1:gw-office"
    "192.168.1.101:ap-central"
    "192.168.1.114:ap-jade"
    "192.168.1.125:ap-repay-ruffled"
    "192.168.1.157:ap-casita"
    "192.168.1.159:ap-replay-surrender"
    "192.168.1.167:ap-toilet"
)

for node in "${NODES[@]}"; do
    ip="${node%%:*}"
    hostname="${node##*:}"

    for iface in phy0-ap0 phy0-ap1 phy0-ap3; do
        case $iface in
            phy0-ap0) ssid="Finca" ;;
            phy0-ap1) ssid="IOT" ;;
            phy0-ap3) ssid="Guest" ;;
        esac

        ssh -o ConnectTimeout=2 root@$ip "iw dev $iface station dump 2>/dev/null" 2>/dev/null | \
        awk -v ap="$hostname" -v ssid="$ssid" '
        /^Station/ {mac=$2}
        /signal avg:/ {
            signal=$3
            gsub(/[^-0-9]/, "", signal)
            if (signal != "") {
                print signal "|" mac "|" ap "|" ssid
            }
        }'  >> $RESULTS
    done
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All Connected Devices (sorted by signal strength - worst first)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-10s  %-17s  %-20s  %-12s  %s\n" "Signal" "MAC Address" "Connected to" "SSID" "Quality"
echo "─────────────────────────────────────────────────────────────────────────────────"

sort -n $RESULTS | while IFS='|' read signal mac ap ssid; do
    if [ "$signal" -le -85 ]; then
        quality="❌ Very Poor"
    elif [ "$signal" -le -80 ]; then
        quality="⚠️  Poor"
    elif [ "$signal" -le -70 ]; then
        quality="⚠️  Fair"
    elif [ "$signal" -le -60 ]; then
        quality="✅ Good"
    else
        quality="✅ Excellent"
    fi
    printf "%-10s  %-17s  %-20s  %-12s  %s\n" "${signal} dBm" "$mac" "$ap" "$ssid" "$quality"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
very_poor=$(awk -F'|' '$1 <= -85 {count++} END {print count+0}' $RESULTS)
poor=$(awk -F'|' '$1 > -85 && $1 <= -80 {count++} END {print count+0}' $RESULTS)
fair=$(awk -F'|' '$1 > -80 && $1 <= -70 {count++} END {print count+0}' $RESULTS)
good=$(awk -F'|' '$1 > -70 {count++} END {print count+0}' $RESULTS)
total=$(wc -l < $RESULTS)

echo "Summary:"
echo "  Total devices: $total"
echo "  Very Poor (≤-85 dBm): $very_poor ❌"
echo "  Poor (-80 to -85 dBm): $poor ⚠️"
echo "  Fair (-70 to -80 dBm): $fair ⚠️"
echo "  Good/Excellent (>-70 dBm): $good ✅"
