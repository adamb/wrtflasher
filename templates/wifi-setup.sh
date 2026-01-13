#!/bin/sh

# Delete default interfaces if they exist (ignore errors)
uci delete wireless.default_radio0 2>/dev/null || true
uci delete wireless.default_radio1 2>/dev/null || true

uci batch <<EOF
set wireless.radio0.disabled='0'
set wireless.radio0.country='US'
set wireless.radio0.channel='6'
set wireless.radio0.htmode='HE20'
set wireless.radio0.noscan='1'

set wireless.radio1.disabled='0'
set wireless.radio1.country='US'
set wireless.radio1.channel='36'
set wireless.radio1.htmode='HE80'

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
set wireless.iot0.encryption='psk2'
set wireless.iot0.key='IOT_PASSWORD_PLACEHOLDER'
set wireless.iot0.network='iot'
set wireless.iot0.ieee80211r='0'
set wireless.iot0.ieee80211w='0'

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

# Set unique hostname and stable MAC for APs only
if [ "$(uci get network.bat0.gw_mode 2>/dev/null)" = "client" ]; then
    ETH_MAC=$(cat /sys/class/net/eth0/address)

    # PGP word list for human-readable hostnames
    PGP_WORDS="PGP_WORDS_PLACEHOLDER"

    # Convert MAC last 2 bytes to word indices
    MAC_BYTE5=$(echo "$ETH_MAC" | cut -d: -f5)
    MAC_BYTE6=$(echo "$ETH_MAC" | cut -d: -f6)
    IDX1=$((0x$MAC_BYTE5))
    IDX2=$((0x$MAC_BYTE6))

    # Convert space-separated word list to array and lookup words
    set -- $PGP_WORDS
    shift $IDX1 || true
    WORD1=$1
    set -- $PGP_WORDS
    shift $IDX2 || true
    WORD2=$1

    # Set hostname
    uci set system.@system[0].hostname="ap-$WORD1-$WORD2"
    uci set network.bat0.macaddr="$ETH_MAC"
    uci commit system
    uci commit network
fi

wifi
