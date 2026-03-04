#!/bin/sh /etc/rc.common
START=99

start() {
    sleep 10
    ip link set phy1-mesh0 mtu 1532 2>/dev/null || true
    batctl meshif bat0 if add phy1-mesh0 2>/dev/null || true
    batctl meshif bat0 if add eth0.99 2>/dev/null || true  # VLAN 99 wired backhaul to ap-prov via G.hn
}
