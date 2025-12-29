#!/bin/bash
set -e  # Exit on error

# Source the user's config
source .env # don't forget to put passwords here!
source config.sh

echo "=== Generating OpenWRT mesh configurations ==="
echo ""

# Clean up old generated configs
rm -rf files-gateway files-ap
mkdir -p files-gateway files-ap

# Generate root password hash
if [ -n "$ROOT_PASSWORD" ]; then
	ROOT_PASSWORD_HASH=$(openssl passwd -6 "$ROOT_PASSWORD")
	echo "  - Root password hash generated"
fi

echo "→ Generating gateway configuration..."
mkdir -p files-gateway/etc/config

cat > files-gateway/etc/config/network <<EOF
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config interface 'wan'
	option device 'eth1'
	option proto 'dhcp'

config interface 'wan2'
	option device 'eth2'
	option proto 'dhcp'

config interface 'bat0'
	option proto 'batadv'
	option routing_algo 'BATMAN_IV'
	option gw_mode 'server'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'bat0.10'
	list ports 'eth0.10'

config device
	option name 'br-iot'
	option type 'bridge'
	list ports 'bat0.20'
	list ports 'eth0.20'

config device
	option name 'br-guest'
	option type 'bridge'
	list ports 'bat0.30'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '$LAN_GATEWAY'
	option netmask '255.255.255.0'

config interface 'iot'
	option device 'br-iot'
	option proto 'static'
	option ipaddr '$IOT_GATEWAY'
	option netmask '255.255.255.0'

config interface 'guest'
	option device 'br-guest'
	option proto 'static'
	option ipaddr '$GUEST_GATEWAY'
	option netmask '255.255.255.0'
EOF

cat > files-gateway/etc/config/dhcp <<EOF
config dnsmasq
	option domainneeded '1'
	option localise_queries '1'
	option rebind_protection '1'
	option rebind_localhost '1'
	option local '/lan/'
	option domain 'lan'
	option expandhosts '1'
	option authoritative '1'
	option readethers '1'
	option leasefile '/tmp/dhcp.leases'

config dhcp 'lan'
	option interface 'lan'
	option start '$DHCP_START'
	option limit '$DHCP_LIMIT'
	option leasetime '$LAN_LEASE_TIME'

config dhcp 'iot'
	option interface 'iot'
	option start '$DHCP_START'
	option limit '$DHCP_LIMIT'
	option leasetime '$IOT_LEASE_TIME'

config dhcp 'guest'
	option interface 'guest'
	option start '$DHCP_START'
	option limit '$DHCP_LIMIT'
	option leasetime '$GUEST_LEASE_TIME'
EOF

cat > files-gateway/etc/config/firewall <<EOF
config defaults
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'REJECT'
	option synflood_protect '1'

config zone
	option name 'lan'
	list network 'lan'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'ACCEPT'

config zone
	option name 'iot'
	list network 'iot'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'REJECT'

config zone
	option name 'guest'
	list network 'guest'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'REJECT'

config zone
	option name 'wan'
	list network 'wan'
	list network 'wan2'
	option input 'REJECT'
	option output 'ACCEPT'
	option forward 'REJECT'
	option masq '1'
	option mtu_fix '1'

config forwarding
	option src 'lan'
	option dest 'wan'

config forwarding
	option src 'lan'
	option dest 'iot'

config forwarding
	option src 'iot'
	option dest 'wan'

config forwarding
	option src 'guest'
	option dest 'wan'

config rule
	option name 'Allow-Home-Assistant-to-IoT'
	option src 'lan'
	option dest 'iot'
	option src_ip '$HOME_ASSISTANT_IP'
	option target 'ACCEPT'

config rule
	option name 'Allow-DHCP-Renew'
	option src 'wan'
	option proto 'udp'
	option dest_port '68'
	option target 'ACCEPT'
	option family 'ipv4'

config rule
	option name 'Allow-Ping'
	option src 'wan'
	option proto 'icmp'
	option icmp_type 'echo-request'
	option family 'ipv4'
	option target 'ACCEPT'
EOF

if [ "$WAN2_ENABLED" = "yes" ]; then
	echo "  - Configuring mwan3 failover"
	cp templates/mwan3 files-gateway/etc/config/mwan3
fi

# Set root password if configured
if [ -n "$ROOT_PASSWORD_HASH" ]; then
	echo "  - Setting root password"
	cat > files-gateway/etc/shadow <<EOF
root:$ROOT_PASSWORD_HASH:0:0:99999:7:::
daemon:*:0:0:99999:7:::
ftp:*:0:0:99999:7:::
network:*:0:0:99999:7:::
nobody:*:0:0:99999:7:::
EOF
	chmod 600 files-gateway/etc/shadow
fi

echo "→ Generating AP configuration..."
mkdir -p files-ap/etc/config

cat > files-ap/etc/config/network <<EOF
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config interface 'bat0'
	option proto 'batadv'
	option routing_algo 'BATMAN_IV'
	option gw_mode 'client'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'bat0.10'
	list ports 'eth0'
	list ports 'eth1'

config device
	option name 'br-iot'
	option type 'bridge'
	list ports 'bat0.20'

config device
	option name 'br-guest'
	option type 'bridge'
	list ports 'bat0.30'

config interface 'lan'
	option device 'br-lan'
	option proto 'dhcp'

config interface 'iot'
	option device 'br-iot'
	option proto 'none'

config interface 'guest'
	option device 'br-guest'
	option proto 'none'
EOF

# Set root password for AP if configured
if [ -n "$ROOT_PASSWORD_HASH" ]; then
	echo "  - Setting root password"
	cat > files-ap/etc/shadow <<EOF
root:$ROOT_PASSWORD_HASH:0:0:99999:7:::
daemon:*:0:0:99999:7:::
ftp:*:0:0:99999:7:::
network:*:0:0:99999:7:::
nobody:*:0:0:99999:7:::
EOF
	chmod 600 files-ap/etc/shadow
fi

echo "→ Generating UCI wireless setup scripts..."
mkdir -p files-gateway/etc/uci-defaults files-ap/etc/uci-defaults

for dir in files-gateway files-ap; do
    cp templates/wifi-setup.sh $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/MESH_ID_PLACEHOLDER/$MESH_ID/g" $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/MESH_KEY_PLACEHOLDER/$MESH_KEY/g" $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/LAN_SSID_PLACEHOLDER/$LAN_SSID/g" $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/LAN_PASSWORD_PLACEHOLDER/$LAN_PASSWORD/g" $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/LAN_MOBILITY_DOMAIN_PLACEHOLDER/$LAN_MOBILITY_DOMAIN/g" $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/IOT_SSID_PLACEHOLDER/$IOT_SSID/g" $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/IOT_PASSWORD_PLACEHOLDER/$IOT_PASSWORD/g" $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/IOT_MOBILITY_DOMAIN_PLACEHOLDER/$IOT_MOBILITY_DOMAIN/g" $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/GUEST_SSID_PLACEHOLDER/$GUEST_SSID/g" $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/GUEST_PASSWORD_PLACEHOLDER/$GUEST_PASSWORD/g" $dir/etc/uci-defaults/99-wifi-setup
    sed -i '' "s/GUEST_MOBILITY_DOMAIN_PLACEHOLDER/$GUEST_MOBILITY_DOMAIN/g" $dir/etc/uci-defaults/99-wifi-setup
    chmod +x $dir/etc/uci-defaults/99-wifi-setup
done

echo "→ Setting up batman-adv mesh attachment init script..."
mkdir -p files-gateway/etc/init.d files-gateway/etc/rc.d
mkdir -p files-ap/etc/init.d files-ap/etc/rc.d

cp templates/batman-attach.sh files-gateway/etc/init.d/batman-attach
cp templates/batman-attach.sh files-ap/etc/init.d/batman-attach
chmod +x files-gateway/etc/init.d/batman-attach
chmod +x files-ap/etc/init.d/batman-attach
ln -sf ../init.d/batman-attach files-gateway/etc/rc.d/S99batman-attach
ln -sf ../init.d/batman-attach files-ap/etc/rc.d/S99batman-attach

echo ""
echo "✓ Configuration generation complete!"