#!/bin/bash
# Find a device by MAC address (full or partial) or IP address across all APs

if [ -z "$1" ]; then
    echo "Usage: $0 <MAC address|IP address|partial MAC>"
    echo ""
    echo "Examples:"
    echo "  $0 f4:91:1e:6f:db:ad    # Full MAC"
    echo "  $0 db:ad                 # Partial MAC (last bytes)"
    echo "  $0 192.168.3.158         # IP address"
    exit 1
fi

SEARCH="$1"

echo "=== Searching for device: $SEARCH ==="
echo ""

# If it looks like an IP, look it up in DHCP leases first
if [[ "$SEARCH" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "→ Looking up MAC from IP..."
    lease=$(ssh root@192.168.1.1 "cat /tmp/dhcp.leases | grep '$SEARCH'")
    if [ -n "$lease" ]; then
        mac=$(echo "$lease" | awk '{print $2}')
        hostname=$(echo "$lease" | awk '{print $4}')
        echo "  Found: $mac"
        if [ "$hostname" != "*" ]; then
            echo "  Hostname: $hostname"
        fi
        echo ""
        SEARCH="$mac"
    else
        echo "  IP not found in DHCP leases"
        exit 1
    fi
fi

# Search all APs for the device
FOUND=false
for node_ip in 192.168.1.1 192.168.1.101 192.168.1.167; do
    node_name=$(ssh -o ConnectTimeout=2 root@$node_ip "uci get system.@system[0].hostname 2>/dev/null" 2>/dev/null)

    for iface in phy0-ap0 phy0-ap1 phy0-ap2 phy0-ap3 phy0-ap4 phy1-mesh0; do
        result=$(ssh -o ConnectTimeout=2 root@$node_ip "iw dev $iface station dump 2>/dev/null | grep -i '$SEARCH'" 2>/dev/null)

        if [ -n "$result" ]; then
            # Extract full MAC from result
            full_mac=$(echo "$result" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)

            ssid=$(ssh -o ConnectTimeout=2 root@$node_ip "iw dev $iface info 2>/dev/null | grep ssid | sed 's/.*ssid //'" 2>/dev/null)

            echo "✓ Found on: $node_name"
            echo "  Interface: $iface"
            echo "  SSID: $ssid"
            echo "  MAC: $full_mac"
            echo ""

            # Get detailed station info
            echo "→ Connection details:"
            ssh root@$node_ip "iw dev $iface station get $full_mac 2>/dev/null | grep -E 'signal|bitrate|inactive|connected time|tx bytes|rx bytes'" 2>/dev/null | sed 's/^/  /'
            echo ""

            # Try to get DHCP info
            lease=$(ssh root@192.168.1.1 "cat /tmp/dhcp.leases | grep -i '$full_mac'" 2>/dev/null)
            if [ -n "$lease" ]; then
                ip=$(echo "$lease" | awk '{print $3}')
                hostname=$(echo "$lease" | awk '{print $4}')
                echo "→ Network info:"
                echo "  IP: $ip"
                if [ "$hostname" != "*" ]; then
                    echo "  Hostname: $hostname"
                fi

                # Determine network based on IP
                if [[ "$ip" =~ ^192\.168\.1\. ]]; then
                    echo "  Network: LAN (192.168.1.0/24)"
                elif [[ "$ip" =~ ^192\.168\.3\. ]]; then
                    echo "  Network: IoT (192.168.3.0/24)"
                elif [[ "$ip" =~ ^192\.168\.4\. ]]; then
                    echo "  Network: Guest (192.168.4.0/24)"
                fi
            fi

            FOUND=true
            break 2
        fi
    done
done

if [ "$FOUND" = false ]; then
    echo "✗ Device not found on any wireless interface"
    echo ""

    # Check if device has ARP entry (recently communicated)
    arp_entry=$(ssh root@192.168.1.1 "cat /proc/net/arp | grep -i '$SEARCH'" 2>/dev/null)
    if [ -n "$arp_entry" ]; then
        arp_ip=$(echo "$arp_entry" | awk '{print $1}')
        arp_iface=$(echo "$arp_entry" | awk '{print $6}')
        echo "→ Device has recent network activity:"
        echo "  IP: $arp_ip"
        echo "  Interface: $arp_iface"

        # Try to ping it
        if ssh root@192.168.1.1 "ping -c 1 -W 2 $arp_ip >/dev/null 2>&1" 2>/dev/null; then
            echo "  Status: ✓ Online (responds to ping)"
        else
            echo "  Status: ✗ Offline (no ping response)"
        fi
        echo ""
        echo "This device is not currently connected via WiFi but may be:"
        echo "  - On a wired ethernet connection"
        echo "  - Recently disconnected (ARP cache not expired)"
        echo "  - Intermittently connecting/disconnecting"
    else
        echo "Possible reasons:"
        echo "  - Device is not connected to WiFi"
        echo "  - MAC address is incorrect"
        echo "  - Device is on a wired connection (not checked by this script)"
    fi
    exit 1
fi
