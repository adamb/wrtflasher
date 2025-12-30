#!/bin/bash
echo "=== RING CAMERAS: OLD vs NEW SSID ==="
echo ""

check_ring() {
    mac=$1
    name=$2
    
    # Check old SSID (phy0-ap3)
    old_found=0
    for ip in 192.168.1.1 192.168.1.101 192.168.1.167; do
        if ssh -o ConnectTimeout=1 root@$ip "iw dev phy0-ap3 station dump 2>/dev/null | grep -qi $mac" 2>/dev/null; then
            old_found=1
            break
        fi
    done
    
    # Check new SSID (phy0-ap1 = IOT)
    new_found=0
    for ip in 192.168.1.1 192.168.1.101 192.168.1.114 192.168.1.157 192.168.1.167; do
        if ssh -o ConnectTimeout=1 root@$ip "iw dev phy0-ap1 station dump 2>/dev/null | grep -qi $mac" 2>/dev/null; then
            new_found=1
            break
        fi
    done
    
    if [ $old_found -eq 1 ]; then
        echo "❌ $name - OLD SSID (FincaDelMar)"
    elif [ $new_found -eq 1 ]; then
        echo "✅ $name - NEW SSID (IOT)"
    else
        echo "⚠️  $name - OFFLINE?"
    fi
}

check_ring "64:9a:63:41:19:9b" "Ring-649a6341199B"
check_ring "90:48:6c:21:b4:56" "Ring-90486C21B456"
check_ring "34:3e:a4:e1:15:df" "Ring-e115df"
check_ring "90:48:6c:2c:10:c2" "Ring-90486C2C10C2"
check_ring "54:e0:19:00:91:10" "RingStickUpCam-10"
check_ring "6c:79:b8:ef:35:12" "Ring-ef3512"
check_ring "6c:79:b8:ee:be:75" "Ring-eebe75"
check_ring "18:7f:88:c1:a1:cc" "Ring-187f88C1A1CC"
check_ring "5c:47:5e:38:86:50" "RingStickUpCam-50"
check_ring "54:e0:19:00:93:82" "RingStickUpCam-82"
check_ring "90:48:6c:2c:10:cc" "Ring-90486C2C10CC"

echo ""
echo "Summary: ✅ = Migrated to IOT, ❌ = Still on old FincaDelMar"
