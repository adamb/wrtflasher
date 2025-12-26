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
3. **generate-config.sh** - Reads config.sh and .env, then generates UCI configuration files in `files-gateway/` and `files-ap/`
4. **build.sh** - Orchestrates the entire build: runs generate-config.sh, builds Docker image, and creates firmware for both device types

### Network Architecture

**VLAN Segmentation** (batman-adv VLANs over 802.11s mesh):
- VLAN 10: LAN network (trusted devices)
- VLAN 20: IoT network (isolated, except Home Assistant access)
- VLAN 30: Guest network (isolated)

**Gateway node** bridges VLANs to physical ethernet (eth0.10, eth0.20) for wired devices. **AP nodes** only bridge to bat0.X VLANs.

**Wireless configuration**:
- radio1 (5GHz, channel 149): 802.11s mesh backhaul with SAE encryption
- radio0 (5GHz, channel 36): Three AP SSIDs, one per VLAN, with 802.11r roaming enabled

**Firewall isolation**:
- LAN zone: full access to WAN and other networks
- IoT/Guest zones: WAN access only, blocked from other networks
- Exception: Home Assistant IP (from LAN) can access IoT network

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

## Making Configuration Changes

To modify mesh settings, SSIDs, network ranges, or firewall rules:

1. Edit **config.sh** with your changes (non-sensitive settings)
2. Edit **.env** for password changes
3. Run `./build.sh` to regenerate configs and rebuild firmware

Do NOT edit files in `files-gateway/` or `files-ap/` directly - they are auto-generated.

## Key Files

- **config.sh** - Master configuration (VLAN IPs, SSID names, mobility domains, Home Assistant IP)
- **.env** - Sensitive passwords (gitignored)
- **generate-config.sh** - Template-based UCI config generator
- **build.sh** - Main build orchestration script
- **Dockerfile** - Ubuntu 22.04 with ImageBuilder extraction
- **downloads/** - ImageBuilder tarball (gitignored, ~500MB)
- **files-gateway/** - Generated UCI configs for gateway node (gitignored)
- **files-ap/** - Generated UCI configs for AP nodes (gitignored)
- **firmware/** - Built firmware .bin files (gitignored)

## Device Profiles

- **openwrt_one** - OpenWRT One (gateway)
- **glinet_gl-mt3000** - GL.iNet GL-MT3000 BerylAX (APs)

Both devices use the mediatek/filogic platform.

## Required Packages

All firmware builds include:
- kmod-batman-adv - batman-adv kernel module
- batctl-default - batman-adv control utility
- luci - Web interface
- luci-ssl - HTTPS support for LuCI
