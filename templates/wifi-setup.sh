#!/bin/sh

# Delete default interfaces if they exist (ignore errors)
uci delete wireless.default_radio0 2>/dev/null || true
uci delete wireless.default_radio1 2>/dev/null || true

uci batch <<EOF
set wireless.radio0.disabled='0'
set wireless.radio0.country='US'
set wireless.radio0.channel='6'

set wireless.radio1.disabled='0'
set wireless.radio1.country='US'
set wireless.radio1.channel='36'

set wireless.mesh0=wifi-iface
set wireless.mesh0.device='radio1'
set wireless.mesh0.mode='mesh'
set wireless.mesh0.mesh_id='MESH_ID_PLACEHOLDER'
set wireless.mesh0.encryption='sae'
set wireless.mesh0.key='MESH_KEY_PLACEHOLDER'
set wireless.mesh0.network='bat0'
set wireless.mesh0.mesh_fwding='0'

set wireless.lan0=wifi-iface
set wireless.lan0.device='radio0'
set wireless.lan0.mode='ap'
set wireless.lan0.ssid='LAN_SSID_PLACEHOLDER'
set wireless.lan0.encryption='sae-mixed'
set wireless.lan0.key='LAN_PASSWORD_PLACEHOLDER'
set wireless.lan0.network='lan'
set wireless.lan0.ieee80211r='1'
set wireless.lan0.mobility_domain='LAN_MOBILITY_DOMAIN_PLACEHOLDER'

set wireless.iot0=wifi-iface
set wireless.iot0.device='radio0'
set wireless.iot0.mode='ap'
set wireless.iot0.ssid='IOT_SSID_PLACEHOLDER'
set wireless.iot0.encryption='sae-mixed'
set wireless.iot0.key='IOT_PASSWORD_PLACEHOLDER'
set wireless.iot0.network='iot'
set wireless.iot0.ieee80211r='1'
set wireless.iot0.mobility_domain='IOT_MOBILITY_DOMAIN_PLACEHOLDER'

set wireless.guest0=wifi-iface
set wireless.guest0.device='radio0'
set wireless.guest0.mode='ap'
set wireless.guest0.ssid='GUEST_SSID_PLACEHOLDER'
set wireless.guest0.encryption='sae-mixed'
set wireless.guest0.key='GUEST_PASSWORD_PLACEHOLDER'
set wireless.guest0.network='guest'
set wireless.guest0.ieee80211r='1'
set wireless.guest0.mobility_domain='GUEST_MOBILITY_DOMAIN_PLACEHOLDER'
EOF

uci commit wireless
wifi
