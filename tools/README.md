# Network Management Tools

Utility scripts for monitoring and managing the OpenWRT mesh network.

## Scripts

### mesh-health.sh
Comprehensive mesh network health assessment.

**Checks:**
- Neighbor count for each AP (redundancy)
- Mesh backhaul signal strength (5GHz)
- Batman-adv link quality (TQ scores)
- Overall mesh status and recommendations

**Usage:**
```bash
./tools/mesh-health.sh
```

**Output:**
- Neighbor counts with status indicators (✅ GOOD, ⚠️ OK, ❌ WEAK)
- Signal strength for all mesh links
- Batman-adv topology with link quality scores
- Health summary and recommendations

---

### weak-devices.sh
Find client devices with poor WiFi signal (<-75 dBm).

**Checks:**
- All wireless interfaces on all APs
- Identifies devices with poor signal strength
- Maps MAC addresses to device names via DHCP

**Usage:**
```bash
./tools/weak-devices.sh
```

**Output:**
- List of devices with signal below -75 dBm
- Device name, IP, AP, interface, and signal strength
- Signal quality guide

**Use case:** Identify devices that might benefit from AP relocation or adding more APs.

---

### active-old-ssid.sh
List devices actively connected to old "FincaDelMar" SSIDs.

**Filters:**
- Only shows devices with <30s inactive time (truly active)
- Excludes stale wireless associations
- Checks both "FincaDelMar" (main) and "FincaDelMar Guest"

**Usage:**
```bash
./tools/active-old-ssid.sh
```

**Output:**
- Devices on old SSIDs by AP and interface
- Device names and IPs from DHCP leases
- Total count of devices needing migration

**Use case:** Track progress when migrating from old SSIDs to new "IOT" SSID.

---

### check-ring-ssids.sh
Check which SSID each Ring camera is connected to.

**Checks:**
- All Ring cameras in DHCP leases
- Determines if on old "FincaDelMar" or new "IOT" SSID
- Identifies offline cameras

**Usage:**
```bash
./tools/check-ring-ssids.sh
```

**Output:**
- Status for each Ring camera (✅ Migrated, ❌ Old SSID, ⚠️ Offline)
- Summary of migration progress

**Use case:** Verify Ring camera migration status when switching SSIDs.

---

### check-temps.sh
Monitor temperature sensors on all APs.

**Monitors:**
- CPU/SoC temperature
- WiFi radio temperatures (2.4GHz and 5GHz)
- Fan speed (RPM)

**Usage:**
```bash
./tools/check-temps.sh
```

**Output:**
- Temperature readings for all APs
- Color-coded status (✅ <65°C, ⚠️ 65-75°C, ❌ >75°C)
- Fan speeds in RPM

**Use case:** Monitor AP thermal performance, especially after relocating APs or during hot weather. GL-MT3000 APs have active cooling and comprehensive thermal sensors.

---

### toggle-ssid.sh
Enable or disable SSIDs across all mesh nodes.

**Capabilities:**
- Shows current status of all SSIDs
- Enable/disable any SSID on all nodes simultaneously
- Confirmation prompt before applying changes
- Automatic WiFi reload after changes

**Usage:**
```bash
# Show current status of all SSIDs
./tools/toggle-ssid.sh

# Disable old "FincaDelMar Guest" SSID
./tools/toggle-ssid.sh eero_guest disable

# Disable old "FincaDelMar" main SSID
./tools/toggle-ssid.sh eero_main disable

# Re-enable if needed
./tools/toggle-ssid.sh eero_guest enable
```

**Available interfaces:**
- `lan0` - Finca (new LAN SSID)
- `iot0` - IOT (new IoT SSID)
- `guest0` - Guest (new guest SSID)
- `eero_main` - FincaDelMar (old main SSID)
- `eero_guest` - FincaDelMar Guest (old guest SSID)

**Use case:** Disable old SSIDs after migrating devices to new networks. Forces remaining devices to reconnect to new SSIDs.

---

### watch-roaming.sh
Monitor a device's WiFi roaming between APs in real-time.

**Monitors:**
- Which AP the device is connected to
- Signal strength changes
- Roaming transitions between APs
- Device activity (inactive time)

**Usage:**
```bash
# Monitor by IP address
./tools/watch-roaming.sh 192.168.1.119

# Monitor by MAC address
./tools/watch-roaming.sh 46:f2:12:7e:9d:72

# Monitor IoT device
./tools/watch-roaming.sh 192.168.3.200 phy0-ap1
```

**Output:**
- Real-time updates every 2 seconds
- 🔄 ROAMED indicator when device switches APs
- Signal strength in dBm
- Inactive time (shows if device is actively transmitting)

**Use case:** Test 802.11r fast roaming behavior by watching a device as you move it around. Verify devices roam to the closest AP with best signal. Identify roaming ping-pong issues.

---

## Requirements

All scripts require:
- SSH access to gateway (192.168.1.1) and all APs
- SSH keys configured for passwordless access
- OpenWRT tools: `batctl`, `iw`, `uci`

## Notes

- Scripts use `mesh-exec.sh` for parallel execution across all APs
- Signal strength guide:
  - -30 to -60 dBm: Good
  - -60 to -75 dBm: Acceptable
  - -75 to -85 dBm: Poor
  - -85+ dBm: Very poor
- Batman-adv TQ scores: 255 = perfect, 200+ = good, <150 = poor
