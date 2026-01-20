# gemini.md

This file provides guidance to Gemini when working with code in this repository. It combines essential information from `README.md` and `CLAUDE.md` to give a comprehensive overview of the project, its architecture, and common operations.

## Project Overview

This repository builds custom OpenWRT firmware images for a self-healing wireless mesh network using `batman-adv`, with VLAN segmentation and seamless WiFi 6 roaming (802.11r/k/v). The project's primary goal is to build firmware for two device types:

-   **Gateway node** (OpenWRT One): Runs DHCP servers, firewall, and acts as the mesh gateway, handling WAN connectivity (including dual-WAN failover).
-   **AP nodes** (GL-MT3000 BerylAX): Mesh clients that extend the wireless network, automatically joining the mesh when powered on.

## Architecture

### What This Does

This project builds custom OpenWRT firmware that creates a **mesh network** where multiple access points work together as one seamless WiFi network:

-   **Self-healing mesh**: APs automatically route traffic through each other using `batman-adv` (Better Approach To Mobile Ad-hoc Networking).
-   **VLAN isolation**: Three separate networks (LAN, IoT, Guest) with firewall rules.
-   **WiFi 6 (802.11ax)**: Modern wireless standard on both 2.4GHz (HE20) and 5GHz (HE80) for better performance.
-   **Seamless roaming**: Devices move between APs without disconnection using 802.11r/k/v (Fast Roaming + Neighbor Reports + BSS Transition).
-   **Single configuration**: Configure once, flash many APs.
-   **Auto-discovery**: APs automatically join the mesh when powered on.

### Configuration Flow

The project uses a single-source-of-truth configuration system:

1.  **config.sh** - Master configuration defining mesh settings, SSIDs, passwords, network ranges, and firewall rules.
2.  **.env** - Sensitive passwords (`MESH_KEY`, `LAN_PASSWORD`, `IOT_PASSWORD`, `GUEST_PASSWORD`) - sourced by `generate-config.sh`.
3.  **generate-config.sh** - Reads `config.sh` and `.env`, then generates:
    -   UCI configuration files (`network`, `dhcp`, `firewall`) in `files-gateway/` and `files-ap/`.
    -   First-boot wireless setup script (`/etc/uci-defaults/99-wifi-setup`) from templates.
    -   Boot-time `batman-adv` attachment script (`/etc/init.d/batman-attach`).
4.  **build.sh** - Orchestrates the entire build: runs `generate-config.sh`, builds Docker image with OpenWRT ImageBuilder, and creates firmware for both device types.

### First Boot Process

When a device boots with the custom firmware:

1.  **OpenWRT auto-detects hardware** - Creates default wireless config with correct radio bands/capabilities.
2.  **UCI defaults scripts run** (`/etc/uci-defaults/99-wifi-setup`):
    -   Deletes default wireless interfaces.
    -   Configures radio settings (country=US, channels).
    -   Creates mesh interface on radio1 (5GHz).
    -   Creates three AP interfaces on radio0 (2.4GHz) for LAN/IoT/Guest.
    -   Auto-deletes after successful execution.
3.  **Init scripts run** (`/etc/init.d/batman-attach`):
    -   Runs late in boot (`START=99`).
    -   Waits 10 seconds for WiFi initialization.
    -   Manually attaches mesh interface (`phy1-mesh0`) to `batman-adv` (`bat0`).
    -   Runs on every boot to ensure mesh attachment.

## Network Architecture

### VLANs and Networks

Three isolated networks using VLANs over the `batman-adv` mesh:

| Network       | VLAN | Subnet          | Encryption       | Roaming     | Purpose                                |
| :------------ | :--- | :-------------- | :--------------- | :---------- | :------------------------------------- |
| **Finca** (LAN) | 10   | 192.168.1.0/24  | WPA3-SAE-Mixed   | 802.11r/k/v | Trusted devices, seamless roaming      |
| **IOT**       | 20   | 192.168.3.0/24  | WPA2-PSK         | None        | IoT devices, isolated, legacy compat   |
| **Guest**     | 30   | 192.168.4.0/24  | WPA3-SAE-Mixed   | 802.11r/k/v | Guest WiFi, fully isolated, seamless roaming |

**Gateway node** bridges VLANs to physical ethernet (eth0.10, eth0.20) for wired devices. **AP nodes** only bridge to bat0.X VLANs.

### Firewall Security Model

-   **LAN zone**: Full access to WAN and IoT networks.
-   **IoT zone**: Internet only, isolated from LAN/Guest (except configured exceptions). Can only reply to LAN-initiated connections.
-   **Guest zone**: Internet only, fully isolated from LAN/IoT.
-   **Stateful firewall**: IoT devices can reply to LAN-initiated connections but cannot initiate to LAN.
-   **Exception**: Home Assistant IP (e.g., 192.168.1.151 from LAN) can be configured to access the IoT network.

### Wireless Configuration

-   **Client WiFi (2.4GHz, radio0):**
    -   Channel 6, WiFi 6 (HE20).
    -   Three SSIDs: Finca, IOT, Guest.
    -   Finca and Guest: 802.11r/k/v for seamless roaming across APs.
    -   IOT: WPA2-PSK with no roaming features for maximum legacy compatibility.
-   **Mesh Backhaul (5GHz, radio1):**
    -   Channel 36, WiFi 6 (HE80, 80MHz wide channel).
    -   WPA3-SAE encryption.
    -   Hidden SSID (`batmesh_network`).
    -   Automatic multi-hop routing via `batman-adv`.
-   **Roaming Features:**
    -   **802.11r (Fast Roaming)**: Instant handoff between APs without disconnection.
    -   **802.11k (Neighbor Reports)**: Clients can discover nearby APs without scanning.
    -   **802.11v (BSS Transition)**: APs can suggest clients move to better APs for optimal performance.

### WAN Configuration

-   `eth1` = Primary WAN (DHCP).
-   Optional `WAN2` (USB tethering) with `mwan3` failover.
-   When `WAN2_ENABLED="yes"` (in `config.sh`), automatic failover: `eth1` (metric 1) → USB (metric 2).
-   DNS: Static DNS servers (Cloudflare 1.1.1.1/1.0.0.1, Quad9 9.9.9.9 backup) ensure DNS resolution works during WAN failover.

## Hardware Support

### Tested Devices

-   **OpenWRT One** - Gateway with dual WAN failover
-   **GL-MT3000 (BerylAX)** - Mesh access points

Both use MediaTek MT7981 platform (mediatek/filogic target).

### Adding New Devices

To support different hardware:

1.  Find your device's OpenWRT profile name.
2.  Download the appropriate ImageBuilder for your platform.
3.  Update `build.sh` with your profile.
4.  Adjust network interface names in `generate-config.sh` if needed.

## Quick Start & Common Commands

### Prerequisites

-   Linux or macOS with Docker.
-   500MB free disk space for ImageBuilder.
-   Git.
-   OpenWRT compatible router(s).

Before first build, download the OpenWRT ImageBuilder:

```bash
mkdir -p downloads
cd downloads
wget https://downloads.openwrt.org/releases/24.10.0/targets/mediatek/filogic/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64.tar.zst
cd ..
```

Copy `.env-example` to `.env` and set passwords:

```bash
cp .env-example .env
# Edit .env with real passwords for MESH_KEY, LAN_PASSWORD, IOT_PASSWORD, GUEST_PASSWORD
```

### Build Firmware

```bash
./build.sh
```

This script will:
1.  Run `generate-config.sh` to create UCI config files.
2.  Build the Docker image (`openwrt-builder:24.10.0`).
3.  Build gateway firmware (OpenWRT One) with files from `files-gateway/`.
4.  Build AP firmware (GL-MT3000) with files from `files-ap/`.
5.  Output `.bin` files to `firmware/`.

**Build outputs:**
-   `firmware/openwrt-*-openwrt_one-*-sysupgrade.bin` - Gateway firmware
-   `firmware/openwrt-*-glinet_gl-mt3000-*-sysupgrade.bin` - AP firmware

### Generate Configs Only

```bash
./generate-config.sh
```

Useful for previewing UCI configuration changes without building firmware.

### Manual Docker Build

```bash
docker build -t openwrt-builder:24.10.0 .
```

### Manual Firmware Build (inside Docker)

```bash
# Gateway
docker run --rm -v $(pwd)/files-gateway:/files -v $(pwd)/firmware:/output openwrt-builder:24.10.0 \
  bash -c "cd /builder/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64 && \
  make image PROFILE='openwrt_one' PACKAGES='kmod-batman-adv batctl-default luci luci-ssl' FILES=/files && \
  cp bin/targets/mediatek/filogic/*sysupgrade* /output/"

# AP
docker run --rm -v $(pwd)/files-ap:/files -v $(pwd)/firmware:/output openwrt-builder:24.10.0 \
  bash -c "cd /builder/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64 && \
  make image PROFILE='glinet_gl-mt3000' PACKAGES='kmod-batman-adv batctl-default luci luci-ssl' FILES=/files && \
  cp bin/targets/mediatek/filogic/*sysupgrade* /output/"
```

## Making Configuration Changes

To modify mesh settings, SSIDs, network ranges, or firewall rules:

1.  Edit **config.sh** with your changes (non-sensitive settings).
2.  Edit **.env** for password changes.
3.  Run `./build.sh` to regenerate configs and rebuild firmware.

Do NOT edit files in `files-gateway/` or `files-ap/` directly - they are auto-generated.

### Enabling Multi-WAN Failover

To enable USB tethering failover on the gateway:

1.  Edit **config.sh** and set `WAN2_ENABLED="yes"`.
2.  Rebuild firmware with `./build.sh`.
3.  Configure `wan2` interface in OpenWRT (LuCI or UCI) to use USB device.
4.  `mwan3` will automatically failover: `eth1` (primary) → USB (backup).

The `mwan3` config uses ping monitoring (8.8.8.8, 1.1.1.1) to detect WAN failures.

## Post-Installation Tuning

### Smart Queue Management (SQM) for Bufferbloat Reduction

SQM is **pre-installed on the gateway** to reduce bufferbloat and improve latency under load. This is especially important for satellite connections like Starlink. It uses CAKE qdisc and applies only to gateway WAN interfaces.

**Configuration:**

```bash
ssh root@192.168.1.1 "
# SQM packages already installed in gateway firmware

# Configure SQM for PRIMARY WAN
 uci set sqm.wan=queue
 uci set sqm.wan.enabled='1'
 uci set sqm.wan.interface='eth1'  # Use 'eth1' for physical interface (or 'wan' if using logical interface)
 uci set sqm.wan.download='210000'   # Set to 85% of your actual download speed
 uci set sqm.wan.upload='30000'      # Set to 75-85% of your actual upload speed
 uci set sqm.wan.script='piece_of_cake.qos'
 uci set sqm.wan.qdisc='cake'
 uci set sqm.wan.link_layer='ethernet'
 uci set sqm.wan.overhead='44'

# Configure SQM for SECONDARY WAN (if using dual-WAN)
 uci set sqm.wan2=queue
 uci set sqm.wan2.enabled='1'
 uci set sqm.wan2.interface='eth2'   # Use actual interface (eth2 for USB tethering)
 uci set sqm.wan2.download='200000'  # Adjust: 85-90% of actual WAN2 download speed
 uci set sqm.wan2.upload='75000'     # Adjust: 85-90% of actual WAN2 upload speed
 uci set sqm.wan2.script='piece_of_cake.qos'
 uci set sqm.wan2.qdisc='cake'
 uci set sqm.wan2.link_layer='ethernet'
 uci set sqm.wan2.overhead='44'

# Apply configuration (no reboot required)
 uci commit sqm
 /etc/init.d/sqm enable
 /etc/init.d/sqm restart
"
```

**Tuning Guidelines:**
-   Set download/upload to **85-90% of actual WAN speeds** (test first with speedtest).
-   Interface name: Use `eth1`/`eth2` for physical interfaces, or `wan`/`wan2` for logical interfaces.
-   Test bufferbloat before/after at dslreports.com/speedtest (look for grade A/B).

### IPv6 Support

Enable IPv6 on your network for full dual-stack connectivity.

**Configuration:**

```bash
ssh root@192.168.1.1
(
# Enable IPv6 on WAN
 uci set network.wan.ipv6='1'
 uci set network.wan.ip6assign='60'

# Create WAN6 interface for DHCPv6
 uci set network.wan6=interface
 uci set network.wan6.device='eth1'
 uci set network.wan6.proto='dhcpv6'
 uci set network.wan6.reqaddress='try'
 uci set network.wan6.reqprefix='auto'

# Enable IPv6 on LAN for client devices
 uci set network.lan.ip6assign='60'

# Commit and restart
 uci commit network
 /etc/init.d/network restart
 /etc/init.d/odhcpd restart
)
```

### WireGuard VPN Server

Set up WireGuard to securely access your home network remotely. Requires IPv6 (since both WANs use CGNAT on IPv4) or a VPS relay.

### Remote Access with Tailscale

Access your entire home network remotely using Tailscale VPN. Only the gateway needs Tailscale installed.

**Installation (Gateway only):**
```bash
ssh root@192.168.1.1
opkg update
opkg install tailscale
/etc/init.d/tailscale start
/etc/init.d/tailscale enable
```

**Configuration:**
```bash
# Advertise all three networks as subnet routes
tailscale up --advertise-routes=192.168.1.0/24,192.168.3.0/24,192.168.4.0/24 --accept-routes
```
(Follow authentication URL and approve subnet routes in Tailscale admin panel).

**Firewall configuration:**

```bash
ssh root@192.168.1.1
uci add_list firewall.@zone[0].network='tailscale'
uci commit firewall
/etc/init.d/firewall restart
```

## Troubleshooting

### AP Not Joining Mesh

1.  Check mesh neighbors: `ssh root@<AP-IP> "batctl meshif bat0 n"`
2.  Should see 2+ neighbors with last-seen < 5 seconds.
3.  If no neighbors, AP is too far from mesh - relocate closer.

### Device Has Poor Signal

```bash
./tools/weak-devices.sh
```

Shows all devices below -75 dBm. Solutions:
-   Add more APs in weak coverage areas.
-   Relocate existing APs.
-   Use `iw dev <iface> station del <MAC>` to force device roaming.

### Renaming Access Points

**IMPORTANT**: Never use `/etc/init.d/network restart` on mesh APs - it breaks `batman-adv` and requires physical reboot.

**Correct method:**

```bash
ssh root@<AP-IP> "
  uci set system.@system[0].hostname='NEW-NAME'
  uci set network.lan.hostname='NEW-NAME'
  uci commit
  reboot
"
```

## File Structure

```
.
├── README.md                 # Original user documentation
├── NETWORK.md                # Network architecture and maintenance docs
├── CLAUDE.md                 # Guidance for Claude Code AI assistant
├── gemini.md                 # This file (guidance for Gemini AI assistant)
├── build.sh                  # Main build script
├── config.sh                 # Network configuration (edit this)
├── .env                      # Passwords (create from .env-example)
├── .env-example              # Example password file
├── generate-config.sh        # UCI config generator
├── mesh-exec.sh              # Run commands on all nodes
├── Dockerfile                # OpenWRT ImageBuilder container
├── downloads/                # ImageBuilder tarball (gitignored)
├── firmware/                 # Built firmware files (gitignored)
├── files-gateway/            # Generated gateway configs (gitignored)
├── files-ap/                 # Generated AP configs (gitignored)
├── templates/
│   ├── wifi-setup.sh         # WiFi configuration
│   ├── batman-attach.sh      # Mesh attachment
│   └── mwan3                 # Dual-WAN config
└── tools/
    ├── README.md             # Tool documentation
    ├── mesh-health.sh        # Mesh status check
    ├── check-temps.sh        # Temperature monitoring
    ├── weak-devices.sh       # Signal strength check
    └── toggle-ssid.sh        # SSID management
```

## Security Considerations

-   **Mesh encryption**: WPA3-SAE on backhaul prevents unauthorized mesh joining.
-   **VLAN isolation**: Separate networks prevent cross-contamination.
-   **Stateful firewall**: IoT cannot initiate connections to LAN.
-   **No WPS**: Disabled on all networks.
-   **Strong passwords**: Required in `.env` file.
-   **Management access**: SSH keys recommended for AP management.

## Credits & Further Reading

-   [OpenWRT](https://openwrt.org/) - Linux OS for embedded devices
-   [batman-adv](https://www.open-mesh.org/projects/batman-adv/) - Mesh routing protocol
-   [OpenWRT ImageBuilder](https://openwrt.org/docs/guide-user/additional-software/imagebuilder) - Firmware build system
-   **NETWORK.md** - Detailed network documentation, maintenance procedures, troubleshooting
-   **tools/README.md** - Complete monitoring tool documentation
-   [OpenWRT Documentation](https://openwrt.org/docs/start)
-   [batman-adv Documentation](https://www.open-mesh.org/projects/batman-adv/wiki)
-   [802.11r/k/v Roaming](https://openwrt.org/docs/guide-user/network/wifi/80211r)
