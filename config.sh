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
# IOT_PASSWORD from .env

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
HOME_ASSISTANT_IP="192.168.1.151"  # Change to your HA IP

# -------- FTP Server --------
FTP_SERVER_IP="192.168.1.164"  # Debian FTP server (deb.lan)

# -------- Multi-WAN Failover (gateway only) --------
WAN2_ENABLED="yes"  # Set to "yes" to enable USB tethering failover

# -------- PGP Word List for AP Hostnames --------
# 256 phonetically distinct words for MAC-to-hostname mapping
# Each byte (0-255) of the MAC address maps to one word
PGP_WORDS="aardvark adroitness absurd adviser aftermath aggregate alkali almighty amulet amusement antenna applicant apollo arena armistice assume atlas aztec baboon backfield bandwagon banjo baptist beaming bedlamp beehive beeswax behalf berserk bidding bifocals bodyguard bookseller borderline brickyard briefcase burlington businessman butterfat camelot candidate cannonball capricorn caravan caretaker celebrate cellulose certify chambermaid cherokee chicago clergyman coherence combustion commando component concurrent confidence conformist congregate consensus consulting corporate corrosion councilman crossover crucifix cumbersome customer dakota decadence december decimal designing detector determine dictator dinosaur direction disable disbelief disruptive distortion document embezzle enchanting enrollment enterprise equation equipment escapade eskimo everyday examine existence exodus fascinate filament finicky forever fortitude frequency gadgetry galveston gatsby getaway glossary gossamer graduate gravity guitarist hamburger hamilton handiwork hazardous headwaters hemisphere hesitate hideaway holiness hurricane hydraulic impartial impetus inception indigo inertia infancy inferno informant insincere insurgent integrate intention inventive istanbul Jamaica Jupiter leprosy letterhead liberty linguist marigold maritime matchmaker maverick megaton memo microscope microwave midsummer millionaire miracle misnomer molasses molecule montana monument mosquito narrative nebula newsletter norwegian objection obsession olympics orlando outfielder pacific pandemic paragon paragraph paramount passenger pedigree pembroke penetrate perceptual performance pharmacy phonetic photograph pioneer playhouse pluto potato processor provincial proximate puberty publisher pyramid quantity racketeer rebellion recipe recover repay retouch revenge reward rhythm ribcage rocker ruffled sailboat sawdust scallion scenario scorecard scotland seabird select sentence shadyside shamrock showgirl skullcap skydive smartphone snapshot sociable souvenir specialist speculate stairway standard stapler steamship sterling stockman stopwatch stormy subscriber subtlety supportive surrender suspense swelter tactics tailgate tambourine telephone therapist tobacco tolerance topmost tracker transit trauma treadmill trojan trouble truncated tumor tunnel tycoon ultima undaunted unify upcoming universe unravel untoward upcoming vapor vehicle ventilate vertigo virginia visitor vocalist voyager wallet wayside willow winnipeg wyoming yesteryear yucatan zenith zulu"