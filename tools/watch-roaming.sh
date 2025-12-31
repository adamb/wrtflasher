#!/bin/bash

# Monitor a device's roaming between APs in real-time

if [ $# -eq 0 ]; then
    echo "Usage: $0 <device-ip-or-mac> [interface]"
    echo ""
    echo "Monitor a device's WiFi roaming between APs"
    echo ""
    echo "Arguments:"
    echo "  device-ip-or-mac  IP address (192.168.x.x) or MAC address (aa:bb:cc:dd:ee:ff)"
    echo "  interface         WiFi interface to monitor (default: phy0-ap0 = Finca LAN)"
    echo "                    Options: phy0-ap0 (Finca), phy0-ap1 (IOT), phy0-ap3 (Guest)"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.119              # Monitor device by IP"
    echo "  $0 46:f2:12:7e:9d:72          # Monitor device by MAC"
    echo "  $0 192.168.3.200 phy0-ap1     # Monitor IoT device"
    echo ""
    exit 1
fi

DEVICE=$1
INTERFACE=${2:-phy0-ap0}

# If device looks like an IP, look up MAC from DHCP
if [[ $DEVICE =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Looking up MAC address for $DEVICE..."
    MAC=$(ssh -o ConnectTimeout=2 root@192.168.1.1 "cat /tmp/dhcp.leases | grep $DEVICE" 2>/dev/null | awk '{print $2}')

    if [ -z "$MAC" ]; then
        echo "Error: Could not find MAC address for IP $DEVICE"
        echo "Device may not have a DHCP lease"
        exit 1
    fi

    HOSTNAME=$(ssh -o ConnectTimeout=2 root@192.168.1.1 "cat /tmp/dhcp.leases | grep $DEVICE" 2>/dev/null | awk '{print $4}')
    echo "Found: $HOSTNAME ($MAC)"
else
    MAC=$DEVICE
    HOSTNAME="unknown"
fi

echo ""
echo "Monitoring: $MAC on interface $INTERFACE"
echo "Press Ctrl+C to stop"
echo ""

LAST_AP=""
LAST_SIGNAL=""

while true; do
    FOUND=false
    for node in "192.168.1.1:gw-office" "192.168.1.101:ap-central" "192.168.1.114:ap-jade" "192.168.1.157:ap-casita" "192.168.1.167:ap-toilet"; do
        ip=$(echo $node | cut -d: -f1)
        name=$(echo $node | cut -d: -f2)

        result=$(ssh -o ConnectTimeout=1 root@$ip "iw dev $INTERFACE station get $MAC 2>/dev/null | grep -E 'signal avg|inactive time'" 2>/dev/null)

        if [ -n "$result" ]; then
            signal=$(echo "$result" | grep "signal avg" | awk '{print $3}')
            inactive=$(echo "$result" | grep "inactive time" | awk '{print $3}')

            # Only show if recently active (less than 10 seconds)
            inactive_val=${inactive% ms}
            if [ "$inactive_val" -lt 10000 ]; then
                FOUND=true

                # Check if roamed to different AP
                if [ "$LAST_AP" != "$name" ] && [ -n "$LAST_AP" ]; then
                    echo "$(date '+%H:%M:%S') 🔄 ROAMED: $LAST_AP ($LAST_SIGNAL dBm) → $name ($signal dBm)"
                    LAST_AP="$name"
                    LAST_SIGNAL="$signal"
                elif [ "$LAST_AP" != "$name" ]; then
                    # First connection
                    echo "$(date '+%H:%M:%S') ✓ Connected to $name - Signal: $signal dBm"
                    LAST_AP="$name"
                    LAST_SIGNAL="$signal"
                else
                    # Same AP, just update
                    echo "$(date '+%H:%M:%S')   $name - Signal: $signal dBm (inactive: $inactive)"
                    LAST_SIGNAL="$signal"
                fi
            fi
        fi
    done

    if [ "$FOUND" = false ]; then
        if [ -n "$LAST_AP" ]; then
            echo "$(date '+%H:%M:%S') ⚠️  Not connected (last seen on $LAST_AP)"
            LAST_AP=""
        else
            echo "$(date '+%H:%M:%S') ⚠️  Device not found on any AP"
        fi
    fi

    sleep 2
done
