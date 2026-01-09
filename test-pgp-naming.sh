#!/bin/bash
# Test script to show PGP-style naming for different MAC addresses

source config.sh

echo "=== Testing PGP Hostname Generation ==="
echo ""

# Function to convert MAC to hostname
mac_to_hostname() {
    local mac=$1
    local byte5=$(echo "$mac" | cut -d: -f5)
    local byte6=$(echo "$mac" | cut -d: -f6)
    local idx1=$((0x$byte5))
    local idx2=$((0x$byte6))

    # Convert space-separated word list to array
    local words=($PGP_WORDS)
    local word1=${words[$idx1]}
    local word2=${words[$idx2]}

    echo "ap-$word1-$word2"
}

# Test with some example MAC addresses
echo "Example MAC addresses and their hostnames:"
echo ""

# Your existing APs (if you know their MACs)
test_macs=(
    "94:83:c4:12:3e:5f"
    "94:83:c4:12:a2:b4"
    "aa:bb:cc:dd:01:65"
    "aa:bb:cc:dd:02:9a"
    "aa:bb:cc:dd:ff:00"
)

for mac in "${test_macs[@]}"; do
    hostname=$(mac_to_hostname "$mac")
    byte5=$(echo "$mac" | cut -d: -f5)
    byte6=$(echo "$mac" | cut -d: -f6)
    echo "  MAC: $mac (bytes: $byte5:$byte6) → $hostname"
done

echo ""
echo "To see your actual AP names, flash the firmware and check:"
echo "  ssh root@192.168.1.X 'hostname'"
