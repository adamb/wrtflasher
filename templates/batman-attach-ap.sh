#!/bin/sh /etc/rc.common
START=99

start() {
    sleep 10
    ip link set phy1-mesh0 mtu 1532 2>/dev/null || true
    batctl meshif bat0 if add phy1-mesh0 2>/dev/null || true

    # Identify G.hn nodes by MAC address to attach wired backhaul
    # and set higher hop penalty (shared, limited bandwidth G.hn relay)
    ETH0_MAC=$(cat /sys/class/net/eth0/address 2>/dev/null)
    if [ "$ETH0_MAC" = "94:83:c4:7f:bb:ec" ] || [ "$ETH0_MAC" = "94:83:c4:7f:a1:44" ]; then
        batctl meshif bat0 if add eth1.99 2>/dev/null || true
        batctl meshif bat0 hp 60  # Higher penalty — G.hn relay with shared bandwidth
    else
        batctl meshif bat0 hp 30  # Standard penalty for WiFi-only nodes
    fi
}
