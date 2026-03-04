#!/bin/sh /etc/rc.common
START=99

start() {
    sleep 10
    ip link set phy1-mesh0 mtu 1532 2>/dev/null || true
    batctl meshif bat0 if add phy1-mesh0 2>/dev/null || true
    
    # Identify ap-prov by its MAC address (94:83:c4:7f:bb:ec)
    # This ensures the G.hn backhaul works even on the first boot before hostname is set.
    ETH0_MAC=$(cat /sys/class/net/eth0/address 2>/dev/null)
    if [ "$ETH0_MAC" = "94:83:c4:7f:bb:ec" ]; then
        batctl meshif bat0 if add eth1.99 2>/dev/null || true
        batctl meshif bat0 hp 60  # Optimized penalty for G.hn link
    else
        batctl meshif bat0 hp 30  # Standard penalty for all-wireless nodes
    fi
}
