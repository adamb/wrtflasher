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

### Switch: Zyxel GS1200-8
- **Management**: 192.168.1.3 (VLAN 10)

| Port | Device | VLAN | Mode |
|------|--------|------|------|
| 1 | Gateway (eth0) | 10,20,30 | Tagged (trunk) |
| 2 | Home Assistant | 10,20 | Tagged |
| 3 | Debian box | 10,20 | Tagged |
| 4 | NAS | 10 | Untagged |
| 5 | Time Capsule | 10 | Untagged |
| 6 | Power cable | 20 | Untagged |
| 7 | Ring Alarm | 20 | Untagged |
| 8 | Spare | 1 | Untagged |

**PVID Settings**: Port 4-5 = 10, Port 6-7 = 20, others = 1

## WiFi Networks

| SSID | VLAN | Network | Purpose |
|------|------|---------|---------|
| Finca | 10 | 192.168.1.0/24 | Trusted devices |
| IOT | 20 | 192.168.3.0/24 | IoT devices |
| Guest | 30 | 192.168.4.0/24 | Guest access |

**Mesh backhaul**: `batmesh_network` on 5GHz (radio1, channel 36)
**Client WiFi**: 2.4GHz (radio0, channel 6)

## Firewall Rules

- Finca → Internet: ✅
- IOT → Internet: ✅
- Guest → Internet: ✅
- Finca → IOT: ❌ (except Home Assistant)
- IOT → Finca: ❌
- Guest → local networks: ❌

Home Assistant IP exception configured to allow Finca→IOT access.

## Dual-WAN Failover

- **Primary (wan)**: eth1 - Starlink
- **Failover (wan2)**: eth2 - T-Mobile USB ethernet
- **mwan3** handles automatic failover

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

## IP Reservations

| Device | IP | MAC |
|--------|----|----|
| Gateway | 192.168.1.1 | - |
| Switch | 192.168.1.3 | - |
| APs | 192.168.1.100+ | DHCP |

## Traffic Flow

```
Device → SSID/wired port → VLAN (10/20/30) → switch/mesh → Gateway → mwan3 → Internet
```
