#!/bin/ash
# One-time mesh + SSID config used by uci-defaults/80-mesh-setup

# -------- Role (per device) --------
# Set to "gateway" on exactly one node; others are "node"
ROLE="${ROLE:-node}"

# -------- Mesh (802.11s) --------
MESH_ID="batmesh_network"
# MESH_KEY="changeme" from .env

# Use UCI device names (radio0/radio1). Typically:
#   radio1 = 5GHz backhaul, radio0 = 2.4/5GHz clients
MESH_DEVICE="radio1"     # 802.11s backhaul
CLIENT_DEVICE="radio0"   # client APs

# -------- SSIDs (must match on all nodes) --------
IOT_SSID="IOT"
IOT_PASSWORD="begueliniot"      # WPA2/3 passphrase

GUEST_SSID="Guest"
# GUEST_PASSWORD="changeme" # from .env

LAN_SSID="Finca"
# LAN_PASSWORD="changeme" # from .env

# -------- 802.11r fast roaming --------
IOT_MOBILITY_DOMAIN="0001"
GUEST_MOBILITY_DOMAIN="0002"
LAN_MOBILITY_DOMAIN="0003"

# -------- IPs/DHCP (gateway only) --------
IOT_NETWORK="192.168.3.0/24";   IOT_GATEWAY="192.168.3.1";   IOT_LEASE_TIME="12h"
GUEST_NETWORK="192.168.4.0/24"; GUEST_GATEWAY="192.168.4.1"; GUEST_LEASE_TIME="1h"
LAN_NETWORK="192.168.1.0/24";   LAN_GATEWAY="192.168.1.1";   LAN_LEASE_TIME="24h"
DHCP_START="100"; DHCP_LIMIT="150"

# -------- Home Assistant --------
HOME_ASSISTANT_IP="192.168.1.50"  # Change to your HA IP