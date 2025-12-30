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
