#!/bin/bash
set -e  # Exit on error

# Source the user's config
source config.sh

echo "=== Generating OpenWRT mesh configurations ==="
echo ""

# Clean up old generated configs
rm -rf files-gateway files-ap
mkdir -p files-gateway files-ap

echo "→ Generating gateway configuration..."
mkdir -p files-gateway/etc/config

cat > files-gateway/etc/config/network <<EOF
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config interface 'bat0'
	option proto 'batadv'
	option routing_algo 'BATMAN_IV'
	option gw_mode 'server'

config interface 'lan'
	option device 'br-lan'
	option proto 'static'
	option ipaddr '$LAN_GATEWAY'
	option netmask '255.255.255.0'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'bat0'

config interface 'iot'
	option device 'br-iot'
	option proto 'static'
	option ipaddr '$IOT_GATEWAY'
	option netmask '255.255.255.0'

config device
	option name 'br-iot'
	option type 'bridge'

config interface 'guest'
	option device 'br-guest'
	option proto 'static'
	option ipaddr '$GUEST_GATEWAY'
	option netmask '255.255.255.0'

config device
	option name 'br-guest'
	option type 'bridge'
EOF

cat > files-gateway/etc/config/wireless <<EOF
config wifi-device 'radio0'
	option type 'mac80211'
	option channel '36'
	option band '5g'
	option htmode 'HE80'
	option disabled '0'

config wifi-device 'radio1'
	option type 'mac80211'
	option channel '149'
	option band '5g'
	option htmode 'HE80'
	option disabled '0'

config wifi-iface
	option device 'radio1'
	option mode 'mesh'
	option mesh_id '$MESH_ID'
	option encryption 'sae'
	option key '$MESH_KEY'
	option network 'bat0'
	option mesh_fwding '0'

config wifi-iface
	option device 'radio0'
	option mode 'ap'
	option ssid '$LAN_SSID'
	option encryption 'sae-mixed'
	option key '$LAN_PASSWORD'
	option network 'lan'
	option ieee80211r '1'
	option mobility_domain '$LAN_MOBILITY_DOMAIN'

config wifi-iface
	option device 'radio0'
	option mode 'ap'
	option ssid '$IOT_SSID'
	option encryption 'sae-mixed'
	option key '$IOT_PASSWORD'
	option network 'iot'
	option ieee80211r '1'
	option mobility_domain '$IOT_MOBILITY_DOMAIN'

config wifi-iface
	option device 'radio0'
	option mode 'ap'
	option ssid '$GUEST_SSID'
	option encryption 'sae-mixed'
	option key '$GUEST_PASSWORD'
	option network 'guest'
	option ieee80211r '1'
	option mobility_domain '$GUEST_MOBILITY_DOMAIN'
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
	option input 'REJECT'
	option output 'ACCEPT'
	option forward 'REJECT'

config zone
	option name 'guest'
	list network 'guest'
	option input 'REJECT'
	option output 'ACCEPT'
	option forward 'REJECT'

config zone
	option name 'wan'
	list network 'wan'
	option input 'REJECT'
	option output 'ACCEPT'
	option forward 'REJECT'
	option masq '1'
	option mtu_fix '1'

config forwarding
	option src 'lan'
	option dest 'wan'

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

config interface 'lan'
	option device 'br-lan'
	option proto 'dhcp'

config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'bat0'
EOF

# 
cat > files-ap/etc/config/wireless <<EOF
config wifi-device 'radio0'
	option type 'mac80211'
	option channel '36'
	option band '5g'
	option htmode 'HE80'
	option disabled '0'

config wifi-device 'radio1'
	option type 'mac80211'
	option channel '149'
	option band '5g'
	option htmode 'HE80'
	option disabled '0'

config wifi-iface
	option device 'radio1'
	option mode 'mesh'
	option mesh_id '$MESH_ID'
	option encryption 'sae'
	option key '$MESH_KEY'
	option network 'bat0'
	option mesh_fwding '0'

config wifi-iface
	option device 'radio0'
	option mode 'ap'
	option ssid '$LAN_SSID'
	option encryption 'sae-mixed'
	option key '$LAN_PASSWORD'
	option network 'lan'
	option ieee80211r '1'
	option mobility_domain '$LAN_MOBILITY_DOMAIN'

config wifi-iface
	option device 'radio0'
	option mode 'ap'
	option ssid '$IOT_SSID'
	option encryption 'sae-mixed'
	option key '$IOT_PASSWORD'
	option network 'iot'
	option ieee80211r '1'
	option mobility_domain '$IOT_MOBILITY_DOMAIN'

config wifi-iface
	option device 'radio0'
	option mode 'ap'
	option ssid '$GUEST_SSID'
	option encryption 'sae-mixed'
	option key '$GUEST_PASSWORD'
	option network 'guest'
	option ieee80211r '1'
	option mobility_domain '$GUEST_MOBILITY_DOMAIN'
EOF

echo ""
echo "✓ Configuration generation complete!"