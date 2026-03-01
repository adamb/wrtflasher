#!/bin/sh /etc/rc.common
START=99

start() {
    sleep 10
    batctl meshif bat0 if add phy1-mesh0 2>/dev/null || true
    batctl meshif bat0 if add eth1 2>/dev/null || true  # wired backhaul (G.hn or ethernet) if present
}
