#!/bin/bash
echo "=== DEVICES WITH POOR SIGNAL (<-75 dBm) ==="
echo ""
printf "%-20s %-16s %-12s %-12s %s\n" "Device" "IP" "AP" "Interface" "Signal"
echo "────────────────────────────────────────────────────────────────────────"

# Get DHCP leases
leases=$(ssh root@192.168.1.1 "cat /tmp/dhcp.leases")

identify() {
    mac=$1
    signal=$2
    ap=$3
    iface=$4
    
    info=$(echo "$leases" | grep -i "$mac" | head -1)
    if [ -n "$info" ]; then
        ip=$(echo "$info" | awk '{print $3}')
        name=$(echo "$info" | awk '{print $4}')
    else
        ip="unknown"
        name="$mac"
    fi
    
    printf "%-20s %-16s %-12s %-12s %s dBm\n" "$name" "$ip" "$ap" "$iface" "$signal"
}

# ap-casita
identify "90:e2:02:d4:12:46" "-80" "ap-casita" "phy0-ap1"

# ap-central
identify "60:8a:10:c2:06:77" "-77" "ap-central" "phy0-ap1"
identify "34:3e:a4:e1:15:df" "-77" "ap-central" "phy0-ap1"
identify "0c:1c:57:a7:13:5e" "-76" "ap-central" "phy0-ap1"
identify "18:7f:88:c1:a1:cc" "-84" "ap-central" "phy0-ap1"
identify "00:31:92:48:60:91" "-76" "ap-central" "phy0-ap1"
identify "d8:f1:5b:cb:c1:94" "-76" "ap-central" "phy0-ap1"
identify "5c:47:5e:38:86:50" "-88" "ap-central" "phy0-ap1"
identify "6c:79:b8:ee:be:75" "-93" "ap-central" "phy0-ap1"
identify "cc:50:e3:36:b6:b8" "-77" "ap-central" "phy0-ap3"
identify "cc:50:e3:36:d6:f1" "-77" "ap-central" "phy0-ap3"

# ap-toilet
identify "40:f5:20:ec:c9:2c" "-85" "ap-toilet" "phy0-ap1"
identify "24:a1:60:05:4c:5e" "-86" "ap-toilet" "phy0-ap1"
identify "24:a1:60:06:65:ff" "-78" "ap-toilet" "phy0-ap3"
identify "24:a1:60:05:3e:69" "-93" "ap-toilet" "phy0-ap3"
identify "40:f5:20:ee:2f:6a" "-79" "ap-toilet" "phy0-ap3"
identify "c4:5b:be:d7:1c:d3" "-87" "ap-toilet" "phy0-ap3"
identify "3c:61:05:86:76:71" "-86" "ap-toilet" "phy0-ap3"
identify "28:ec:9a:80:dc:c3" "-76" "ap-toilet" "phy0-ap3"

echo ""
echo "Signal quality guide:"
echo "  -30 to -60 dBm: Good"
echo "  -60 to -75 dBm: Acceptable"
echo "  -75 to -85 dBm: Poor (may have connectivity issues)"
echo "  -85+ dBm: Very poor (likely unstable)"
