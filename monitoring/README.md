# Mesh Network Monitor for Home Assistant

A Python service that monitors OpenWRT mesh network health and publishes telemetry to Home Assistant via MQTT. Runs as a systemd service on a Debian host with persistent SSH connections for low overhead.

## Features

- **Persistent SSH (ControlMaster):** Reuses SSH connections to minimize overhead on mesh nodes
- **Parallel Polling:** Queries all nodes simultaneously using thread pools
- **Comprehensive Metrics:** Mesh health, client counts, signal strength, WAN status
- **MQTT Discovery:** Sensors automatically appear in Home Assistant (no manual YAML)
- **Service Monitoring:** MQTT Last Will and Testament (LWT) alerts if monitor goes offline
- **Best Signal Metric:** Shows strongest neighbor signal (the link actually being used by batman-adv)

## Collected Metrics

**Per Node (All 7 nodes):**
- Mesh neighbor count (redundancy check)
- Best signal strength to neighbors (dBm) - strongest link, which batman-adv uses for routing
- Client count per SSID (Finca, IOT, Guest)
- Uptime
- Load average

**Gateway Only (gw-office):**
- WAN1 status (Starlink)
- WAN2 status (T-Mobile) if enabled
- Active WAN interface
- Batman-adv gateway mode

## Architecture

```
Debian Server (systemd service)
    |
main.py (Python)
    | SSH ControlMaster (persistent connections)
    v
All mesh nodes (7 nodes: gw-office, ap-ec54, ap-d74c, ap-repay-ruffled, ap-gate, ap-repay-surrender, ap-dc99)
    | Collect stats (batctl, iw, uptime, etc.)
    v
MQTT Broker (on Home Assistant)
    | MQTT Discovery Protocol
    v
Home Assistant
    -> Auto-discovered sensors
    -> Custom dashboard
```

## Directory Structure

```
wrtflasher/
├── monitoring/
│   ├── README.md              # This file
│   ├── main.py                # Python poller
│   ├── config.yaml.example    # Configuration template
│   ├── config.yaml            # Your config (gitignored)
│   ├── requirements.txt       # Python dependencies
│   ├── setup-ssh.sh           # SSH ControlMaster setup
│   ├── owmm.service           # Systemd service file
│   └── homeassistant/
│       ├── dashboard.yaml     # HA dashboard (YAML mode)
│       └── template_sensors.yaml  # Aggregate sensors (totals)
```

## Setup

### 1. Install MQTT Broker on Home Assistant

**Install Mosquitto broker:**
1. In Home Assistant: Settings → Add-ons → Add-on Store
2. Search for "Mosquitto broker"
3. Click Install → Start → Enable "Start on boot"

**Create dedicated MQTT user:**
1. Settings → People → Users tab (at top)
2. Add User with these settings:
   - Name: `MQTT Monitor`
   - Username: `mqtt_monitor`
   - Password: (generate strong password - **store in Bitwarden**)
   - Can only login from local network: ✓ (checked)
   - Administrator: ✗ (unchecked)

### 2. Prerequisites

**On your Debian server:**
```bash
cd ~/code/wrtflasher/monitoring

# Create Python virtual environment (Debian 12+ requirement)
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install Python dependencies in venv
pip install -r requirements.txt

# Deactivate when done (venv will be used by systemd service)
deactivate
```

### 3. SSH Key Setup

The existing `mesh_nodes` SSH key should already be set up. Verify:

```bash
# Check if key exists
ls -la ~/.ssh/mesh_nodes

# Test access to all nodes
for ip in 192.168.1.1 192.168.1.101 192.168.1.114 192.168.1.125 192.168.1.157 192.168.1.159 192.168.1.167; do
    ssh -i ~/.ssh/mesh_nodes -o ConnectTimeout=2 root@$ip "hostname"
done
```

### 4. Configure SSH ControlMaster

Run the setup script to enable persistent SSH connections:

```bash
./setup-ssh.sh
```

### 5. Configure Monitoring

Copy the example config and edit:

```bash
cp config.yaml.example config.yaml
nano config.yaml
```

Edit these values:
- `mqtt.broker` - Your Home Assistant IP (e.g., 192.168.1.151)
- `mqtt.username` - `mqtt_monitor`
- `mqtt.password` - Password from Bitwarden
- `poll_interval` - How often to poll (default: 60 seconds)

### 6. Test Manually

```bash
./venv/bin/python main.py
```

You should see:
- "Connected to MQTT broker"
- "Published discovery for gw-office" (and all APs)
- "Collected stats from gw-office" (and all APs)
- "Poll completed in X.Xs"

Check Home Assistant:
- Settings → Devices & Services → MQTT
- Should see 7 devices (one per mesh node)

### 7. Install as Systemd Service

```bash
sudo cp owmm.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable owmm.service
sudo systemctl start owmm.service

# Check status
sudo systemctl status owmm.service

# View logs
sudo journalctl -u owmm.service -f
```

## Home Assistant Setup

### Dashboard (YAML Mode)

The dashboard uses YAML mode for easier version control:

1. **Create dashboards directory:**
   ```bash
   mkdir -p /config/dashboards
   ```

2. **Copy dashboard file:**
   Copy `homeassistant/dashboard.yaml` to `/config/dashboards/mesh.yaml`

3. **Add to configuration.yaml:**
   ```yaml
   lovelace:
     mode: storage
     dashboards:
       mesh-network:
         mode: yaml
         filename: dashboards/mesh.yaml
         title: Mesh Network
         icon: mdi:wifi
         require_admin: false
   ```

4. **Restart Home Assistant**

### Template Sensors (Aggregates)

Template sensors aggregate client counts across all nodes:

1. **Copy template file:**
   Copy `homeassistant/template_sensors.yaml` to `/config/template_sensors.yaml`

2. **Add to configuration.yaml:**
   ```yaml
   template:
     - sensor: !include template_sensors.yaml
   ```

3. **Restart Home Assistant** or reload template entities

This creates:
- `sensor.mesh_total_clients` - Total clients across all nodes
- `sensor.mesh_total_clients_finca` - Total Finca SSID clients
- `sensor.mesh_total_clients_iot` - Total IoT SSID clients
- `sensor.mesh_total_clients_guest` - Total Guest SSID clients

## Entity Naming

Entities follow this pattern:
```
sensor.mesh_node_<node>_<metric>
```

Examples:
- `sensor.mesh_node_gw_office_neighbor_count`
- `sensor.mesh_node_ap_ec54_best_signal`
- `sensor.mesh_node_ap_d74c_clients_total`
- `sensor.mesh_node_gw_office_active_wan`

## Maintenance

### Cleanup Old Entities

If you have old entities with doubled names (from a previous version), run:

```bash
sudo systemctl stop owmm
./venv/bin/python main.py --cleanup
sudo systemctl start owmm
```

This removes old MQTT discovery configs for entities like `mesh_node_gw_office_gw_office_*`.

### Updating

```bash
cd ~/code/wrtflasher
git pull
sudo systemctl restart owmm
```

If dashboard or template_sensors changed, copy the updated files to Home Assistant and restart HA.

## Troubleshooting

### Monitor won't start
```bash
sudo journalctl -u owmm.service -n 50
```

Common issues:
- MQTT credentials wrong → Check HA MQTT integration
- SSH key missing → See SSH setup section
- Python deps missing → `./venv/bin/pip install -r requirements.txt`

### SSH connections timing out
```bash
# Test SSH manually
ssh -i ~/.ssh/mesh_nodes root@192.168.1.1 "hostname"

# Clean up stale ControlMaster sockets
rm ~/.ssh/sockets/*
```

### Sensors not appearing in HA
1. Check MQTT integration: Settings → Devices & Services → MQTT
2. Listen to MQTT: Developer Tools → MQTT → Listen to `homeassistant/sensor/#`
3. Restart HA to force discovery refresh

### Entity shows "Unknown"
The monitor hasn't published data yet. Wait for the next poll cycle (default 60s) or restart the service.

### Entity shows "Entity not found"
The entity name in the dashboard doesn't match what the monitor creates. Check the entity names in Developer Tools → States.

## Performance

**Resource usage (on Debian server):**
- CPU: <1% average
- Memory: ~50MB
- Network: ~10KB per poll

**Impact on mesh nodes:**
- Minimal: Commands execute in <100ms per node
- ControlMaster reuses SSH connections

## Security Notes

- SSH key is read-only access to mesh nodes
- MQTT credentials use dedicated user (not admin)
- Monitor runs as non-root user
- No ports exposed (only outbound SSH and MQTT)
