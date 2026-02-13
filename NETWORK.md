# Network Documentation

## Overview

Three isolated networks using VLANs over a batman-adv mesh:
- **Finca (VLAN 10)**: Trusted devices - 192.168.1.0/24
- **IOT (VLAN 20)**: Untrusted IoT devices - 192.168.3.0/24
- **Guest (VLAN 30)**: WiFi-only, internet access - 192.168.4.0/24

## Hardware

### Gateway: OpenWRT One (gw-office)
- **eth0** (2.5G): LAN trunk to Zyxel switch (VLAN 10,20,30 tagged)
- **eth1** (1G): WAN - Starlink (primary)
- **eth2** (USB): WAN2 - T-Mobile via USB ethernet (failover)
- **IP**: 192.168.1.1

### Access Points: GL-MT3000 (BerylAX)
- Mesh nodes, no routing
- Hostnames auto-generated as `ap-XXXX` from MAC
- eth0/eth1 bridged to br-lan for wired devices

**AP Locations:**
| Hostname | IP | Location |
|----------|-----|----------|
| gw-office | 192.168.1.1 | Office (gateway) |
| ap-central | 192.168.1.101 | Main living room |
| ap-jade | 192.168.1.114 | Gate |
| ap-repay-ruffled | 192.168.1.125 | Porche |
| ap-casita | 192.168.1.157 | Cuarito |
| ap-repay-surrender | 192.168.1.159 | Carport |
| ap-toilet | 192.168.1.167 | Master toilet |
| ap-prov | 192.168.1.117 | Bedroom |
| ap-news | 192.168.1.175 | Tesla room |
| ap-cust | 192.168.1.197 | Jade bedroom |

### Debian Box (deb)
- **Hostname**: deb (via /etc/hosts on Mac)
- **LAN IP**: 192.168.1.163 (VLAN 10) - Primary management interface
- **IoT IP**: 192.168.3.164 (VLAN 20) - For IoT device management
- **WiFi**: Disabled (was 192.168.3.197, now down)
- **Connection**: Wired via Switch Port 3 (VLANs 10,20 tagged)
- **Purpose**: Management/automation server with dual-VLAN access
- **Tailscale**: Runs subnet router for remote access to 192.168.1.0/24

**Network Configuration:**
- `enp1s0.10` - LAN interface (192.168.1.163, 192.168.1.164)
- `enp1s0.20` - IoT interface (192.168.3.164)
- Default route via LAN (192.168.1.1)

**SSH from LAN devices:** `ssh adam@192.168.1.163` or `ssh adam@deb`

### Switch: Zyxel GS1200-8
- **Management**: 192.168.1.3 (VLAN 10)

| Port | Device | VLAN | Mode |
|------|--------|------|------|
| 1 | Gateway (eth0) | 10,20,30 | Tagged (trunk) |
| 2 | Spare | - | - |
| 3 | Debian box | 10,20 | Tagged |
| 4 | Home Assistant | 10 | Untagged |
| 5 | Time Capsule | 10 | Untagged |
| 6 | Power cable | 20 | Untagged |
| 7 | Ring Alarm | 20 | Untagged |
| 8 | Spare | 1 | Untagged |

**PVID Settings**: Port 4-5 = 10, Port 6-7 = 20, others = 1

## WiFi Networks

| SSID | VLAN | Network | WiFi Mode | Encryption | Roaming | Purpose |
|------|------|---------|-----------|------------|---------|---------|
| Finca | 10 | 192.168.1.0/24 | WiFi 6 (HE20) | WPA3-SAE-Mixed | 802.11r/k/v | Trusted devices, seamless roaming |
| IOT | 20 | 192.168.3.0/24 | WiFi 6 (HE20) | WPA2-PSK | None | IoT devices (legacy compat) |
| Guest | 30 | 192.168.4.0/24 | WiFi 6 (HE20) | WPA3-SAE-Mixed | 802.11r/k/v | Guest access, seamless roaming |

**Mesh backhaul**: `batmesh_network` on 5GHz WiFi 6 (radio1, channel 36, HE80, WPA3-SAE)
**Client WiFi**: 2.4GHz WiFi 6 (radio0, channel 6, HE20)

**WiFi 6 Benefits:**
- Better performance with multiple devices (OFDMA)
- Improved efficiency and battery life for clients
- Backwards compatible - WiFi 4/5 devices still work

**Roaming Features (Finca & Guest only):**
- **802.11r**: Fast handoff between APs without disconnection
- **802.11k**: Neighbor discovery without channel scanning (saves battery)
- **802.11v**: APs can suggest clients move to better APs

**IOT Network Compatibility:**
- Uses WPA2-PSK (not WPA3) for legacy device support
- No roaming features (802.11r/k/v) or management frame protection (802.11w)
- WiFi 6 with backwards compatibility to WiFi 4 (802.11n)
- Works with ESP8266/ESP32, older cameras, pool controllers, etc.

## Firewall Rules

### Zone Configuration
- **LAN zone**: Can access WAN and IoT networks
- **IoT zone**: Can only access WAN (internet), isolated from LAN/Guest
- **Guest zone**: Can only access WAN (internet), fully isolated from LAN/IoT

### Forwarding Rules
| Source | Destination | Status | Notes |
|--------|-------------|--------|-------|
| LAN | WAN | ✅ | Internet access |
| LAN | IoT | ✅ | Manage IoT devices (Remootio, Ring cameras, etc.) |
| LAN | Guest | ❌ | Guest network isolated |
| IoT | WAN | ✅ | Internet access only |
| IoT | LAN | 🔄 | Replies only (stateful firewall) |
| IoT | Guest | ❌ | Fully isolated |
| Guest | WAN | ✅ | Internet access only |
| Guest | LAN | ❌ | Fully isolated |
| Guest | IoT | ❌ | Fully isolated |

### Special Rules
- **Home Assistant → IoT**: Device at 192.168.1.151 can access IoT network (configured in config.sh)
- **IoT → Home Assistant MQTT**: IoT devices can connect to Home Assistant MQTT broker (port 1883) for sensor data publishing

### Security Model
The firewall uses **stateful connection tracking**:
- LAN devices can initiate connections to IoT devices
- IoT devices can reply to LAN-initiated connections
- IoT devices **cannot** initiate new connections to LAN
- This prevents compromised IoT devices from attacking trusted LAN devices

### Implementation
Firewall rules are generated by `generate-config.sh` from `config.sh` and applied on first boot. To modify:
1. Edit firewall section in `generate-config.sh`
2. Run `./build.sh` to rebuild firmware
3. Or manually apply with UCI commands and update repo

## Dual-WAN Failover

- **Primary (wan)**: eth1 - Starlink
- **Failover (wan2)**: eth2 - T-Mobile USB ethernet (or any USB ethernet device)
- **mwan3** handles automatic failover based on health monitoring

### How Failover Works

**Health Monitoring:**
- Pings 8.8.8.8 and 1.1.1.1 every 20 seconds on wan, every 5 seconds on wan2
- wan: Requires 10 consecutive failures to mark down, 2 successes to mark up
- wan2: Requires 3 consecutive failures to mark down, 3 successes to mark up
- Timeout: 5 seconds (wan), 2 seconds (wan2)

**Routing:**
- wan (eth1) has metric 10 (preferred)
- wan2 (eth2) has metric 20 (backup)
- Traffic automatically routes through lowest metric healthy interface

### Starlink DHCP Flap Protection

**Problem:** Starlink uses short (300 second) DHCP leases, and under heavy download load, the Starlink router becomes unresponsive to DHCP renewals. When udhcpc loses the lease, netifd brings down the interface, triggering mwan3 failover - even though the lease is re-obtained within seconds.

**Solution:** Custom `/lib/netifd/dhcp.script` that skips the `deconfig` action for the wan interface. This keeps the IP configured even when DHCP renewal temporarily fails, preventing unnecessary failovers.

**How it works:**
1. Normal DHCP renewal: udhcpc sends renewal → Starlink responds → IP stays configured
2. Failed renewal under load: udhcpc times out → calls `deconfig` → **our script skips deconfig for wan** → IP stays configured → udhcpc retries → eventually succeeds
3. Without this fix: deconfig would remove the IP → netifd signals ifdown → mwan3 fails over to T-Mobile

**Risk:** If Starlink actually assigns a different IP (rare with CGNAT), there could be brief routing issues. In practice, Starlink consistently assigns the same IP (100.90.x.x range).

**SQM Settings:** To reduce load on Starlink during heavy downloads, SQM is configured conservatively:
- Download: 30 Mbps (actual speeds vary 20-90 Mbps)
- Upload: 8 Mbps
- This prevents buffer bloat but doesn't fully prevent DHCP timeouts, hence the dhcp.script fix

**DNS Configuration:**
The gateway uses **static public DNS servers** to ensure DNS resolution works during failover:
- **Primary**: Cloudflare 1.1.1.1, 1.0.0.1
- **Backup**: Quad9 9.9.9.9

Without static DNS, the gateway would use DNS servers provided by the primary WAN via DHCP. During failover, those DNS servers would be unreachable, causing DNS resolution to fail even though the backup WAN is working (you could ping 8.8.8.8 but not resolve google.com).

### Checking Failover Status

```bash
# Check which WAN is active
ssh root@192.168.1.1 "mwan3 status"

# Check WAN interface status
ssh root@192.168.1.1 "ifstatus wan && echo '---' && ifstatus wan2"

# Test DNS resolution
ssh root@192.168.1.1 "nslookup google.com"
```

## Useful Commands

```bash
# Mesh status
batctl meshif bat0 n          # neighbors
batctl meshif bat0 o          # all nodes with link quality

# WiFi clients
iw dev phy0-ap0 station dump | grep -E "Station|signal"

# Network status
ip link | grep br-            # bridges
cat /tmp/dhcp.leases          # DHCP clients

# mwan3
mwan3 status                  # failover status
```

## Mesh Management

Use `mesh-exec.sh` to run commands on all nodes simultaneously:

```bash
# Check all node hostnames
./mesh-exec.sh "cat /proc/sys/kernel/hostname"

# Check mesh neighbors on all nodes
./mesh-exec.sh "batctl meshif bat0 n"

# Check WiFi channel configuration
./mesh-exec.sh "uci show wireless.radio0.channel && uci show wireless.radio1.channel"

# Reload WiFi on all nodes
./mesh-exec.sh "wifi reload"

# Change IOT network to WPA2-PSK for legacy device compatibility
./mesh-exec.sh "uci set wireless.iot0.encryption='psk2'; uci set wireless.iot0.ieee80211r='0'; uci set wireless.iot0.ieee80211w='0'; uci commit wireless; wifi reload"

# Check uptime on all nodes
./mesh-exec.sh "uptime"

# Check batman gateway mode
./mesh-exec.sh "batctl meshif bat0 gw"
```

## IP Reservations

| Device | IP | MAC | Notes |
|--------|----|----|-------|
| Gateway | 192.168.1.1 | - | OpenWRT One |
| Switch | 192.168.1.3 | - | Zyxel GS1200-8 |
| Home Assistant | 192.168.1.151 | 20:f8:3b:00:03:e9 | Port 4, VLAN 10 (untagged) |
| Debian (deb) | 192.168.1.163 | 84:47:09:1c:29:26 | Port 3, VLANs 10,20. Also has 192.168.3.164 (IoT) |
| APs | 192.168.1.100+ | DHCP | Auto-generated hostnames |

## Traffic Flow

```
Device → SSID/wired port → VLAN (10/20/30) → switch/mesh → Gateway → mwan3 → Internet
```

## Remote Access (Tailscale)

Tailscale runs on the Debian box (deb) for subnet routing to the home network.

### Setup

```bash
# Install/update Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure subnet routing
sudo tailscale up --advertise-routes=192.168.1.0/24 --reset
```

### Admin Console

1. Go to https://login.tailscale.com/admin/machines
2. Find "deb" and approve subnet route 192.168.1.0/24

### Access

From any Tailscale device, use local IPs:
- Home Assistant: http://192.168.1.151:8123
- Gateway: ssh root@192.168.1.1
- Deb: ssh adam@192.168.1.164

### Important Notes

- **MUST use SNAT** (default) - do NOT add `--snat-subnet-routes=false`
- **Only deb runs Tailscale** - gateway should NOT run Tailscale (causes IP conflicts)
- Settings persist across reboots automatically

## Maintenance Tasks

### Renaming Access Points

APs auto-generate hostnames as `ap-XXXX` from MAC addresses. To rename an AP:

**IMPORTANT:** DO NOT use `/etc/init.d/network restart` on mesh APs - it breaks batman-adv mesh connectivity and requires physical reboot to recover.

**Correct Method (using reboot):**

```bash
# 1. Set hostname on the AP and reboot
ssh root@<AP-IP> "
  uci set system.@system[0].hostname='NEW-NAME'
  uci set network.lan.hostname='NEW-NAME'
  uci commit
  reboot
"

# 2. (Optional) Clear stale DHCP lease on gateway
ssh root@192.168.1.1 "
  sed -i '/<AP-IP>/d' /tmp/dhcp.leases
  /etc/init.d/dnsmasq restart
"

# 3. Wait 1-2 minutes for AP to boot and verify
ssh root@192.168.1.1 "cat /tmp/dhcp.leases | grep NEW-NAME"
```

**Why this works:**
- `system.@system[0].hostname` - Sets the local hostname
- `network.lan.hostname` - Tells DHCP client to send this name to gateway
- Reboot ensures clean reconnection to mesh and DHCP
- Gateway's dnsmasq learns the new name from DHCP request

**Why network restart fails on mesh APs:**
- Disrupts batman-adv mesh interface (phy1-mesh0)
- Breaks bridge configuration (br-lan)
- DHCP client loses connection
- Requires physical power cycle to recover

### Forcing Device Roaming Between APs

To force a device to disconnect from one AP and reconnect to another (e.g., when device has "sticky client" syndrome):

```bash
# Disconnect device from current AP
ssh root@<CURRENT-AP-IP> "iw dev <interface> station del <MAC-ADDRESS>"

# Device will automatically reconnect to strongest available AP
# Example:
ssh root@192.168.1.167 "iw dev phy0-ap1 station del 38:1f:8d:9a:27:c4"
```

**Temporarily ban a device from an AP** (force it to use a different AP for a period):

```bash
# Ban device for 5 minutes (300000 ms)
ssh root@<AP-IP> "iw dev <interface> station del <MAC-ADDRESS>"
# Device cannot reconnect to this AP for ban duration
```

### Finding Devices on the Mesh

**Find which AP a device is connected to:**

```bash
# Search all APs for a specific MAC
./mesh-exec.sh "
  for iface in phy0-ap0 phy0-ap1 phy0-ap3 phy0-ap4; do
    if iw dev \$iface station dump 2>/dev/null | grep -qi '<MAC>'; then
      signal=\$(iw dev \$iface station dump 2>/dev/null | grep -i -A 10 '<MAC>' | grep 'signal avg')
      echo \$(uci get system.@system[0].hostname) - \$iface - \$signal
    fi
  done
" | grep -v "Running\|===\|Success"
```

**Check signal strength for a specific device:**

```bash
ssh root@<AP-IP> "iw dev <interface> station dump | grep -i -A 10 '<MAC>' | grep signal"
```

### Checking Mesh Health

**View all mesh neighbors:**

```bash
# On gateway
ssh root@192.168.1.1 "batctl meshif bat0 n"

# On specific AP
ssh root@<AP-IP> "batctl meshif bat0 n"
```

**View mesh topology (all nodes and paths):**

```bash
ssh root@192.168.1.1 "batctl meshif bat0 o"
```

**Check if an AP can reach mesh from its location:**

```bash
ssh root@<AP-IP> "batctl meshif bat0 n"
# Should show 2+ neighbors with last-seen < 5 seconds
# If no neighbors or high last-seen times (>10s), AP is too far from mesh
```
