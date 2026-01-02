# OpenWRT Batman-adv Mesh Network Builder

Build custom OpenWRT firmware for a self-healing wireless mesh network using batman-adv, with VLAN segmentation and 802.11r fast roaming.

## What This Does

This project builds custom OpenWRT firmware that creates a **mesh network** where multiple access points work together as one seamless WiFi network:

- **Self-healing mesh**: APs automatically route traffic through each other using batman-adv (Better Approach To Mobile Ad-hoc Networking)
- **VLAN isolation**: Three separate networks (LAN, IoT, Guest) with firewall rules
- **Fast roaming**: Devices seamlessly move between APs without disconnection (802.11r)
- **Single configuration**: Configure once, flash many APs
- **Auto-discovery**: APs automatically join the mesh when powered on

### Use Cases

- Large homes or properties where a single router doesn't provide enough coverage
- Multi-building networks (house + garage + guest house)
- Networks where running ethernet between buildings is impractical
- IoT device isolation with controlled LAN access
- Guest networks completely isolated from your main network

## Network Architecture

### VLANs and Networks

Three isolated networks using VLANs over the batman-adv mesh:

| Network | VLAN | Subnet | Encryption | Purpose |
|---------|------|--------|------------|---------|
| **Finca** (LAN) | 10 | 192.168.1.0/24 | WPA3-SAE-Mixed + 802.11r | Trusted devices |
| **IOT** | 20 | 192.168.3.0/24 | WPA2-PSK (legacy compat) | IoT devices, isolated |
| **Guest** | 30 | 192.168.4.0/24 | WPA3-SAE-Mixed + 802.11r | Guest WiFi, fully isolated |

### Firewall Security Model

- **LAN zone**: Full access to WAN and IoT networks
- **IoT zone**: Internet only, isolated from LAN/Guest (except configured exceptions)
- **Guest zone**: Internet only, fully isolated from LAN/IoT
- **Stateful firewall**: IoT devices can reply to LAN-initiated connections but cannot initiate to LAN

This prevents compromised IoT devices from attacking trusted LAN devices.

### Wireless Configuration

**Client WiFi (2.4GHz, radio0):**
- Channel 6, HT20 mode (legacy device compatibility)
- Three SSIDs: Finca, IOT, Guest
- IOT uses WPA2-PSK for maximum compatibility (no 802.11r/w)

**Mesh Backhaul (5GHz, radio1):**
- Channel 36, WPA3-SAE encryption
- Hidden SSID (batmesh_network)
- Automatic multi-hop routing via batman-adv

## Hardware Support

### Tested Devices

- **OpenWRT One** - Gateway with dual WAN failover
- **GL-MT3000 (BerylAX)** - Mesh access points

Both use MediaTek MT7981 platform (mediatek/filogic target).

### Adding New Devices

To support different hardware:
1. Find your device's OpenWRT profile name
2. Download the appropriate ImageBuilder for your platform
3. Update `build.sh` with your profile
4. Adjust network interface names in `generate-config.sh` if needed

## Quick Start

### Prerequisites

- Linux or macOS with Docker
- 500MB free disk space for ImageBuilder
- Git
- OpenWRT compatible router(s)

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd wrtflasher

# Download OpenWRT ImageBuilder
mkdir -p downloads
cd downloads
wget https://downloads.openwrt.org/releases/24.10.0/targets/mediatek/filogic/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64.tar.zst
cd ..
```

### 2. Configure Your Network

```bash
# Copy example environment file
cp .env-example .env

# Edit .env with your passwords
nano .env
```

Set these passwords in `.env`:
- `MESH_KEY` - Mesh backhaul encryption key (WPA3-SAE)
- `LAN_PASSWORD` - Finca (LAN) SSID password
- `IOT_PASSWORD` - IOT SSID password
- `GUEST_PASSWORD` - Guest SSID password

**Optional**: Edit `config.sh` to customize:
- Network ranges (VLAN IPs)
- SSID names
- DHCP ranges
- Home Assistant IP (for IoT access exception)
- Dual-WAN settings

### 3. Build Firmware

```bash
./build.sh
```

This will:
1. Generate UCI configuration files from templates
2. Build Docker image with OpenWRT ImageBuilder
3. Create firmware for gateway (OpenWRT One)
4. Create firmware for APs (GL-MT3000)
5. Output `.bin` files to `firmware/` directory

**Build outputs:**
- `firmware/openwrt-*-openwrt_one-*-sysupgrade.bin` - Gateway firmware
- `firmware/openwrt-*-glinet_gl-mt3000-*-sysupgrade.bin` - AP firmware

### 4. Flash Your Devices

**Gateway (first device):**
1. Flash gateway firmware via OpenWRT LuCI web interface (System → Backup/Flash Firmware)
2. Gateway will become DHCP server and mesh root at 192.168.1.1
3. Configure WAN connection(s) via LuCI

**Access Points:**
1. Flash AP firmware via LuCI
2. APs will auto-generate hostnames as `ap-XXXX` (from MAC address)
3. APs automatically join mesh and get DHCP from gateway (192.168.1.100+)
4. No additional configuration needed!

### 5. Verify Mesh Health

Use the included monitoring tools:

```bash
# Check mesh connectivity and link quality
./tools/mesh-health.sh

# Monitor AP temperatures
./tools/check-temps.sh

# Find devices with poor signal
./tools/weak-devices.sh
```

See `tools/README.md` for complete tool documentation.

## Configuration Files

### Generated (Don't Edit Directly)

These are auto-generated by `generate-config.sh`:
- `files-gateway/` - Gateway UCI configuration
- `files-ap/` - AP UCI configuration

### Source Files (Edit These)

- **config.sh** - Network settings, VLAN ranges, DHCP, firewall rules
- **.env** - Passwords (gitignored, copy from `.env-example`)
- **templates/wifi-setup.sh** - WiFi configuration template
- **templates/batman-attach.sh** - Mesh attachment script
- **generate-config.sh** - Configuration generator (reads config.sh + .env)

## Network Management

### Mesh Management Script

Run commands on all mesh nodes simultaneously:

```bash
# Check all node hostnames
./mesh-exec.sh "cat /proc/sys/kernel/hostname"

# Check mesh neighbors
./mesh-exec.sh "batctl meshif bat0 n"

# Reload WiFi on all nodes
./mesh-exec.sh "wifi reload"
```

### Monitoring Tools

Located in `tools/` directory:

- **mesh-health.sh** - Comprehensive mesh health assessment
- **check-temps.sh** - Monitor CPU and WiFi radio temperatures
- **weak-devices.sh** - Find clients with poor signal strength
- **active-old-ssid.sh** - Track SSID migration progress
- **toggle-ssid.sh** - Enable/disable SSIDs across all nodes
- **check-ring-ssids.sh** - Verify Ring camera SSID migration

See `tools/README.md` for detailed documentation.

## Post-Installation Tuning

### Smart Queue Management (SQM) for Bufferbloat Reduction

After installation, configure SQM on the gateway to reduce bufferbloat and improve latency under load. This is especially important for satellite connections like Starlink.

**What is SQM:**
- Reduces bufferbloat (high latency when network is saturated)
- Keeps connection responsive during downloads/uploads
- Uses CAKE qdisc (Common Applications Kept Enhanced)
- Applies only to gateway WAN interfaces

**Installation and Configuration:**

```bash
ssh root@192.168.1.1 "
# Install SQM packages
opkg update && opkg install sqm-scripts luci-app-sqm

# Configure SQM for PRIMARY WAN
uci set sqm.wan=queue
uci set sqm.wan.enabled='1'
uci set sqm.wan.interface='wan'
uci set sqm.wan.download='210000'   # Set to 85% of your actual download speed
uci set sqm.wan.upload='30000'      # Set to 75-85% of your actual upload speed
uci set sqm.wan.script='piece_of_cake.qos'
uci set sqm.wan.qdisc='cake'
uci set sqm.wan.link_layer='ethernet'
uci set sqm.wan.overhead='44'

# Optional: Configure SQM for SECONDARY WAN (if using dual-WAN)
uci set sqm.wan2=queue
uci set sqm.wan2.enabled='1'
uci set sqm.wan2.interface='wan2'
uci set sqm.wan2.download='50000'   # Adjust for your backup WAN speeds
uci set sqm.wan2.upload='20000'
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
- Set download/upload to **85-90% of actual WAN speeds** (test first with speedtest)
- For Starlink (250 down / 40 up): use download='210000' upload='30000'
- For cable/fiber: adjust overhead to 22-38 for pure Ethernet
- Test bufferbloat before/after at dslreports.com/speedtest (look for grade A/B)

**To disable SQM if needed:**
```bash
ssh root@192.168.1.1 "uci set sqm.wan.enabled='0' && uci commit sqm && /etc/init.d/sqm restart"
```

## Advanced Topics

### Dual-WAN Failover

The gateway supports automatic WAN failover using mwan3:

1. Edit `config.sh` and set `WAN2_ENABLED="yes"`
2. Rebuild firmware
3. Configure WAN2 interface in LuCI (USB tethering, secondary ISP, etc.)
4. mwan3 automatically fails over when primary WAN goes down

Monitoring: 8.8.8.8 and 1.1.1.1 via ping, metric-based routing (eth1=1, wan2=2).

### Adding More Access Points

The mesh automatically scales:

1. Flash new AP with the same AP firmware
2. Power on within range of existing mesh
3. AP auto-joins mesh and starts serving all SSIDs
4. Verify with `./tools/mesh-health.sh`

**Optimal placement:**
- Space APs 30+ feet apart on 5GHz to avoid interference
- Each AP should see 2-3 mesh neighbors for redundancy
- Monitor signal strength with `./tools/weak-devices.sh`

### IoT Device Access from LAN

By default, IoT network is isolated. To allow specific LAN devices (like Home Assistant) to access IoT:

1. Edit `config.sh` and set `HOME_ASSISTANT_IP="192.168.1.151"` (or your HA's IP)
2. Rebuild and reflash gateway firmware
3. Stateful firewall allows that IP to initiate connections to IoT network

### Legacy Device Compatibility

The IOT network uses WPA2-PSK (not WPA3) and HT20 channel width for maximum compatibility with:
- Older smart home devices
- ESP8266/ESP32 devices
- Legacy WiFi cameras
- Pool controllers and similar IoT hardware

802.11r fast roaming and 802.11w management frame protection are disabled on IOT network.

## Troubleshooting

### AP Not Joining Mesh

1. Check mesh neighbors: `ssh root@<AP-IP> "batctl meshif bat0 n"`
2. Should see 2+ neighbors with last-seen < 5 seconds
3. If no neighbors, AP is too far from mesh - relocate closer

### Device Has Poor Signal

```bash
./tools/weak-devices.sh
```

Shows all devices below -75 dBm. Solutions:
- Add more APs in weak coverage areas
- Relocate existing APs
- Use `iw dev <iface> station del <MAC>` to force device roaming

### Renaming Access Points

**IMPORTANT**: Never use `/etc/init.d/network restart` on mesh APs - it breaks batman-adv and requires physical reboot.

**Correct method:**
```bash
ssh root@<AP-IP> "
  uci set system.@system[0].hostname='NEW-NAME'
  uci set network.lan.hostname='NEW-NAME'
  uci commit
  reboot
"
```

See `NETWORK.md` for detailed maintenance procedures.

## File Structure

```
.
├── README.md                 # This file
├── NETWORK.md               # Network architecture and maintenance docs
├── CLAUDE.md                # Instructions for Claude Code AI assistant
├── build.sh                 # Main build script
├── config.sh                # Network configuration (edit this)
├── .env                     # Passwords (create from .env-example)
├── .env-example             # Example password file
├── generate-config.sh       # UCI config generator
├── mesh-exec.sh            # Run commands on all nodes
├── Dockerfile              # OpenWRT ImageBuilder container
├── downloads/              # ImageBuilder tarball (gitignored)
├── firmware/               # Built firmware files (gitignored)
├── files-gateway/          # Generated gateway configs (gitignored)
├── files-ap/              # Generated AP configs (gitignored)
├── templates/             # Configuration templates
│   ├── wifi-setup.sh      # WiFi configuration
│   ├── batman-attach.sh   # Mesh attachment
│   └── mwan3              # Dual-WAN config
└── tools/                 # Network monitoring tools
    ├── README.md          # Tool documentation
    ├── mesh-health.sh     # Mesh status check
    ├── check-temps.sh     # Temperature monitoring
    ├── weak-devices.sh    # Signal strength check
    └── toggle-ssid.sh     # SSID management
```

## Security Considerations

- **Mesh encryption**: WPA3-SAE on backhaul prevents unauthorized mesh joining
- **VLAN isolation**: Separate networks prevent cross-contamination
- **Stateful firewall**: IoT cannot initiate connections to LAN
- **No WPS**: Disabled on all networks
- **Strong passwords**: Required in .env file
- **Management access**: SSH keys recommended for AP management

## Contributing

This is a personal project but feel free to:
- Fork for your own network
- Submit issues for bugs
- Share improvements via pull requests

## License

MIT License - Use freely for personal or commercial networks.

## Credits

Built with:
- [OpenWRT](https://openwrt.org/) - Linux OS for embedded devices
- [batman-adv](https://www.open-mesh.org/projects/batman-adv/) - Mesh routing protocol
- [OpenWRT ImageBuilder](https://openwrt.org/docs/guide-user/additional-software/imagebuilder) - Firmware build system

## Further Reading

- **NETWORK.md** - Detailed network documentation, maintenance procedures, troubleshooting
- **tools/README.md** - Complete monitoring tool documentation
- [OpenWRT Documentation](https://openwrt.org/docs/start)
- [batman-adv Documentation](https://www.open-mesh.org/projects/batman-adv/wiki)
- [802.11r Fast Roaming](https://openwrt.org/docs/guide-user/network/wifi/80211r)
