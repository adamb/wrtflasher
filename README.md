# OpenWRT Batman-adv Mesh Network Builder

Build custom OpenWRT firmware for a self-healing wireless mesh network using batman-adv, with VLAN segmentation and seamless WiFi 6 roaming (802.11r/k/v).

## What This Does

This project builds custom OpenWRT firmware that creates a **mesh network** where multiple access points work together as one seamless WiFi network:

- **Self-healing mesh**: APs automatically route traffic through each other using batman-adv (Better Approach To Mobile Ad-hoc Networking)
- **VLAN isolation**: Three separate networks (LAN, IoT, Guest) with firewall rules
- **WiFi 6 (802.11ax)**: Modern wireless standard on both 2.4GHz (HE20) and 5GHz (HE80) for better performance
- **Seamless roaming**: Devices move between APs without disconnection using 802.11r/k/v (Fast Roaming + Neighbor Reports + BSS Transition)
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

| Network | VLAN | Subnet | Encryption | Roaming | Purpose |
|---------|------|--------|------------|---------|---------|
| **Finca** (LAN) | 10 | 192.168.1.0/24 | WPA3-SAE-Mixed | 802.11r/k/v | Trusted devices, seamless roaming |
| **IOT** | 20 | 192.168.3.0/24 | WPA2-PSK | None | IoT devices, isolated, legacy compat |
| **Guest** | 30 | 192.168.4.0/24 | WPA3-SAE-Mixed | 802.11r/k/v | Guest WiFi, fully isolated, seamless roaming |

### Firewall Security Model

- **LAN zone**: Full access to WAN and IoT networks
- **IoT zone**: Internet only, isolated from LAN/Guest (except configured exceptions)
- **Guest zone**: Internet only, fully isolated from LAN/IoT
- **Stateful firewall**: IoT devices can reply to LAN-initiated connections but cannot initiate to LAN

This prevents compromised IoT devices from attacking trusted LAN devices.

### Wireless Configuration

**Client WiFi (2.4GHz, radio0):**
- Channel 6, WiFi 6 (HE20) for better performance
- Three SSIDs: Finca, IOT, Guest
- Finca and Guest: 802.11r/k/v for seamless roaming across APs
- IOT: WPA2-PSK with no roaming features for maximum legacy compatibility

**Mesh Backhaul (5GHz, radio1):**
- Channel 36, WiFi 6 (HE80, 80MHz wide channel)
- WPA3-SAE encryption
- Hidden SSID (batmesh_network)
- Automatic multi-hop routing via batman-adv

**Roaming Features:**
- **802.11r (Fast Roaming)**: Instant handoff between APs without disconnection
- **802.11k (Neighbor Reports)**: Clients can discover nearby APs without scanning, saving battery
- **802.11v (BSS Transition)**: APs can suggest clients move to better APs for optimal performance

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

# Get MAC address and hostname for all nodes
./mesh-exec.sh "cat /sys/class/net/eth0/address && uci get system.@system[0].hostname"

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

SQM is **pre-installed on the gateway** to reduce bufferbloat and improve latency under load. This is especially important for satellite connections like Starlink.

**What is SQM:**
- Reduces bufferbloat (high latency when network is saturated)
- Keeps connection responsive during downloads/uploads
- Uses CAKE qdisc (Common Applications Kept Enhanced)
- Pre-installed on gateway, just needs configuration
- Applies only to gateway WAN interfaces

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
# Test WAN2 speeds first: curl --interface eth2 -o /dev/null -w 'Speed: %{speed_download}\n' \
#   https://speed.cloudflare.com/__down?bytes=200000000
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
- Set download/upload to **85-90% of actual WAN speeds** (test first with speedtest)
- **Example configurations:**
  - Starlink (250 down / 40 up): download='210000' upload='30000'
  - T-Mobile 5G USB tethering (230 down / 85 up): download='200000' upload='75000'
  - Cable/fiber: adjust overhead to 22-38 for pure Ethernet
- **Interface name:** Use `eth1`/`eth2` for physical interfaces, or `wan`/`wan2` for logical interfaces
- If you get "interface does not exist" error, change `interface='wan'` to `interface='eth1'`
- **Test WAN2 speeds before configuring:** Use `curl --interface eth2` to test without failover
- Test bufferbloat before/after at dslreports.com/speedtest (look for grade A/B)

**To disable SQM if needed:**
```bash
ssh root@192.168.1.1 "uci set sqm.wan.enabled='0' && uci commit sqm && /etc/init.d/sqm restart"
```

### Testing SQM Performance

**Verify SQM Status:**
```bash
ssh root@192.168.1.1 "
# Check SQM is running
/etc/init.d/sqm status

# View CAKE qdisc on both WANs
tc qdisc show dev eth1  # Starlink
tc qdisc show dev eth2  # T-Mobile

# View detailed statistics
tc -s qdisc show dev eth1 | head -5
tc -s qdisc show dev eth2 | head -5
"
```

**Test Download Speed:**
```bash
ssh root@192.168.1.1 "
# Test primary WAN (Starlink/eth1)
curl -o /dev/null -w 'Time: %{time_total}s | Speed: %{speed_download} bytes/sec\n' \
  https://speed.cloudflare.com/__down?bytes=100000000

# Test secondary WAN (T-Mobile/eth2) without failing over
curl --interface eth2 -o /dev/null -w 'Time: %{time_total}s | Speed: %{speed_download} bytes/sec\n' \
  https://speed.cloudflare.com/__down?bytes=200000000
"
```

**Bufferbloat Test (Latency Under Load):**

Open TWO SSH sessions to the gateway:

*Session 1 - Monitor ping/latency:*
```bash
ssh root@192.168.1.1 "ping 1.1.1.1"
```

*Session 2 - Generate heavy download+upload load:*
```bash
ssh root@192.168.1.1 "
curl -o /dev/null https://speed.cloudflare.com/__down?bytes=100000000 &
dd if=/dev/zero bs=1M count=100 2>/dev/null | curl -T - -o /dev/null http://speedtest.tele2.net/upload.php
"
```

**Expected Results:**
- **Without SQM:** Ping spikes to 500-2000ms under load (bufferbloat)
- **With SQM:** Ping stays under 100ms under load (good QoS)

Watch ping times in Session 1 while load runs in Session 2. SQM is working if latency remains stable.

## Future Enhancements / TODO

### IPv6 Support

Enable IPv6 on your network for full dual-stack connectivity. Starlink provides native IPv6, which also enables WireGuard VPN access (since you're behind CGNAT on IPv4).

**Benefits:**
- Real public IPv6 address (no CGNAT)
- Better performance for IPv6-native services
- Enables inbound VPN connections without relay servers
- Future-proof networking

**Configuration:** (Requires physical access - brief network restart)
```bash
ssh root@192.168.1.1 "
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
"
```

**Verify:** `curl -6 ifconfig.me` should show your public IPv6 address (2xxx:xxxx::)

### WireGuard VPN Server

Set up WireGuard to securely access your home network remotely. Requires IPv6 (since both WANs use CGNAT on IPv4) or a VPS relay.

**Options:**
1. **WireGuard over IPv6** (recommended - free, direct access)
   - Requires IPv6 enabled (see above)
   - Works for clients with IPv6 connectivity (most mobile networks)

2. **Tailscale** (easiest - works behind CGNAT)
   - Mesh VPN using WireGuard protocol
   - Free for personal use
   - No public IP needed

3. **VPS Relay** (advanced - full control)
   - Requires VPS with public IP (~$5/month)
   - WireGuard tunnel from gateway to VPS
   - Clients connect to VPS, traffic routes to home

**Installation:** (Documentation coming soon)

### DNS-over-HTTPS / DNS-over-TLS

Encrypt DNS queries for privacy and security.

**Status:** Planned enhancement

### VLAN Guest Portal

Captive portal for guest network with custom terms/authentication.

**Status:** Planned enhancement

## Advanced Topics

### Dual-WAN Failover

The gateway supports automatic WAN failover using mwan3:

1. Edit `config.sh` and set `WAN2_ENABLED="yes"`
2. Rebuild firmware
3. Configure WAN2 interface in LuCI (USB tethering, secondary ISP, etc.)
4. mwan3 automatically fails over when primary WAN goes down

**How it works:**
- **Health monitoring**: Pings 8.8.8.8 and 1.1.1.1 every 5 seconds to detect WAN failures
- **Metric-based routing**: eth1 (metric 1) is primary, wan2 (metric 2) is backup
- **DNS failover**: Static DNS servers (Cloudflare 1.1.1.1/1.0.0.1, Quad9 9.9.9.9) ensure DNS resolution works on both WANs
- **Automatic failback**: When primary WAN recovers, traffic automatically switches back

**DNS configuration:**
The gateway uses static public DNS servers instead of WAN-provided DNS to ensure DNS resolution continues working during failover. Without this, you could ping IP addresses but not resolve domain names when failed over.

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

The IOT network is configured for maximum compatibility with older devices:
- **WPA2-PSK encryption** (not WPA3) for legacy device support
- **WiFi 6 (HE20)** with backwards compatibility to WiFi 4 (802.11n)
- **No roaming features**: 802.11r/k/v and 802.11w management frame protection disabled
- Works with: ESP8266/ESP32, older smart home devices, legacy WiFi cameras, pool controllers

Even on WiFi 6, older devices can connect - they'll negotiate down to WiFi 4 speeds while modern devices benefit from WiFi 6 improvements.

### Remote Access with Tailscale

Access your entire home network remotely using Tailscale VPN with subnet routing. Tailscale runs on the Debian box (deb), not the gateway.

**Installation (on deb):**
```bash
# Install/update Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure subnet routing
sudo tailscale up --advertise-routes=192.168.1.0/24 --reset
```

**Approve subnet routes:**
1. Go to https://login.tailscale.com/admin/machines
2. Find "deb" and approve subnet route 192.168.1.0/24

**Testing:**

From any device on your Tailscale network (phone, laptop, etc.), use local IPs:
- Home Assistant: http://192.168.1.151:8123
- Gateway LuCI: http://192.168.1.1
- Deb: ssh adam@192.168.1.164

**Important:**
- **MUST use SNAT** (default) - do NOT add `--snat-subnet-routes=false`
- **Only deb runs Tailscale** - gateway should NOT run Tailscale (causes IP conflicts)
- Settings persist across reboots automatically

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
- [802.11r/k/v Roaming](https://openwrt.org/docs/guide-user/network/wifi/80211r)
