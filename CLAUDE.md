# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository builds custom OpenWRT firmware images for a batman-adv mesh network with three isolated VLANs (LAN, IoT, Guest) and 802.11r fast roaming support. The build system uses OpenWRT ImageBuilder to create firmware for two device types:

- **Gateway node** (OpenWRT One): Runs DHCP servers, firewall, and acts as the mesh gateway
- **AP nodes** (GL-MT3000 BerylAX): Mesh clients that extend the wireless network

## Architecture

### Configuration Flow

The project uses a single-source-of-truth configuration system:

1. **config.sh** - Master configuration defining mesh settings, SSIDs, passwords, network ranges, and firewall rules
2. **.env** - Sensitive passwords (MESH_KEY, LAN_PASSWORD, IOT_PASSWORD, GUEST_PASSWORD) - sourced by generate-config.sh
3. **generate-config.sh** - Reads config.sh and .env, then generates:
   - UCI configuration files (network, dhcp, firewall) in `files-gateway/` and `files-ap/`
   - First-boot wireless setup script (`/etc/uci-defaults/99-wifi-setup`) from templates
   - Boot-time batman-adv attachment script (`/etc/init.d/batman-attach`)
4. **build.sh** - Orchestrates the entire build: runs generate-config.sh, builds Docker image, and creates firmware for both device types

### First Boot Process

When a device boots with the custom firmware:

1. **OpenWRT auto-detects hardware** - Creates default wireless config with correct radio bands/capabilities
2. **UCI defaults scripts run** (`/etc/uci-defaults/99-wifi-setup`):
   - Deletes default wireless interfaces
   - Configures radio settings (country=US, channels)
   - Creates mesh interface on radio1 (5GHz)
   - Creates three AP interfaces on radio0 (2.4GHz) for LAN/IoT/Guest
   - Auto-deletes after successful execution
3. **Init scripts run** (`/etc/init.d/batman-attach`):
   - Runs late in boot (START=99)
   - Waits 10 seconds for WiFi initialization
   - Manually attaches mesh interface (phy1-mesh0) to batman-adv (bat0)
   - Runs on every boot to ensure mesh attachment

### Network Architecture

**VLAN Segmentation** (batman-adv VLANs over 802.11s mesh):
- VLAN 10: LAN network (trusted devices)
- VLAN 20: IoT network (isolated, except Home Assistant access)
- VLAN 30: Guest network (isolated)

**Gateway node** bridges VLANs to physical ethernet (eth0.10, eth0.20) for wired devices. **AP nodes** only bridge to bat0.X VLANs.

**WAN Configuration**:
- eth1 = Primary WAN (DHCP)
- Optional WAN2 (USB tethering) with mwan3 failover
- When WAN2_ENABLED="yes", automatic failover: eth1 (metric 1) → USB (metric 2)

**Wireless configuration**:
- radio1 (5GHz, channel 36): 802.11s mesh backhaul with SAE encryption
- radio0 (2.4GHz, channel 6): Three AP SSIDs, one per VLAN
  - Finca/Guest: WPA3-SAE-Mixed with 802.11r fast roaming
  - IOT: WPA2-PSK (legacy compatibility, no 802.11r/w)

**Firewall isolation**:
- LAN zone: Can access WAN and IoT networks (can manage IoT devices)
- IoT zone: WAN access only, can only reply to LAN-initiated connections (stateful firewall)
- Guest zone: WAN access only, fully isolated from LAN/IoT
- IoT/Guest cannot initiate connections to LAN (security)
- Exception: Home Assistant IP (192.168.1.151 from LAN) can access IoT network

## Common Commands

### Prerequisites

Download the OpenWRT ImageBuilder before first build:
```bash
mkdir -p downloads
cd downloads
wget https://downloads.openwrt.org/releases/24.10.0/targets/mediatek/filogic/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64.tar.zst
cd ..
```

Copy .env-example to .env and set passwords:
```bash
cp .env-example .env
# Edit .env with real passwords
```

### Build Firmware

```bash
./build.sh
```

This script:
1. Runs generate-config.sh to create UCI config files
2. Builds the Docker image (openwrt-builder:24.10.0)
3. Builds gateway firmware (OpenWRT One) with files from files-gateway/
4. Builds AP firmware (GL-MT3000) with files from files-ap/
5. Outputs .bin files to firmware/

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

### Serial Console Access

Connect to the OpenWRT One serial console (useful for monitoring boot and flashing):

```bash
screen /dev/tty.usbmodem* 115200
```

**Note**: The `/dev/tty.usbmodem*` device persists even during flash cycles, making it ideal for monitoring the entire flash and boot process.

**Exit screen**: Press `Ctrl-A` then `K` then `Y` to kill the session.

## Making Configuration Changes

To modify mesh settings, SSIDs, network ranges, or firewall rules:

1. Edit **config.sh** with your changes (non-sensitive settings)
2. Edit **.env** for password changes
3. Run `./build.sh` to regenerate configs and rebuild firmware

Do NOT edit files in `files-gateway/` or `files-ap/` directly - they are auto-generated.

### Enabling Multi-WAN Failover

To enable USB tethering failover on the gateway:

1. Edit **config.sh** and set `WAN2_ENABLED="yes"`
2. Rebuild firmware with `./build.sh`
3. Configure wan2 interface in OpenWRT (LuCI or UCI) to use USB device
4. mwan3 will automatically failover: eth1 (primary) → USB (backup)

The mwan3 config uses ping monitoring (8.8.8.8, 1.1.1.1) to detect WAN failures.

## Key Files

- **config.sh** - Master configuration (VLAN IPs, SSID names, mobility domains, Home Assistant IP)
- **.env** - Sensitive passwords (gitignored)
- **generate-config.sh** - Template-based UCI config generator
- **build.sh** - Main build orchestration script (suppresses LD_PRELOAD warnings)
- **Dockerfile** - Ubuntu 22.04 with ImageBuilder extraction
- **templates/** - Script templates for wireless setup and batman-adv attachment
  - `wifi-setup.sh` - First-boot wireless configuration (uci-defaults)
  - `batman-attach.sh` - Boot-time mesh interface attachment (init.d)
  - `mwan3` - Multi-WAN failover configuration (conditionally included if WAN2_ENABLED="yes")
- **downloads/** - ImageBuilder tarball (gitignored, ~500MB)
- **files-gateway/** - Generated UCI configs and scripts for gateway node (gitignored)
- **files-ap/** - Generated UCI configs and scripts for AP nodes (gitignored)
- **firmware/** - Built firmware .bin/.itb files (gitignored)

## Device Profiles

- **openwrt_one** - OpenWRT One (gateway)
- **glinet_gl-mt3000** - GL.iNet GL-MT3000 BerylAX (APs)

Both devices use the mediatek/filogic platform.

## Required Packages

**Gateway packages:**
- kmod-batman-adv - batman-adv kernel module
- batctl-default - batman-adv control utility
- luci - Web interface
- luci-ssl - HTTPS support for LuCI
- luci-proto-batman-adv - LuCI protocol handler for batman-adv
- kmod-usb-net-rndis - USB RNDIS ethernet support (for USB tethering)
- kmod-usb-net-cdc-ether - USB CDC ethernet support (for USB tethering)
- mwan3 - Multi-WAN routing and failover
- luci-app-mwan3 - LuCI web interface for mwan3
- sqm-scripts - Smart Queue Management (CAKE/fq_codel)
- luci-app-sqm - LuCI web interface for SQM

**AP packages:**
- Same as gateway except mwan3/luci-app-mwan3/sqm-scripts (APs don't need WAN features)
