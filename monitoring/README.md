# Mesh Network Monitor for Home Assistant

A Python service that monitors OpenWRT mesh network health and publishes telemetry to Home Assistant via MQTT. Runs as a systemd service on a Debian host with persistent SSH connections for low overhead.

## Features

- **Persistent SSH (ControlMaster):** Reuses SSH connections to minimize overhead on mesh nodes
- **Parallel Polling:** Queries all nodes simultaneously using thread pools
- **Comprehensive Metrics:** Mesh health, client counts, signal strength, WAN status
- **MQTT Discovery:** Sensors automatically appear in Home Assistant (no manual YAML)
- **Service Monitoring:** MQTT Last Will and Testament (LWT) alerts if monitor goes offline

## Collected Metrics

**Per Node (All 5 nodes):**
- Mesh neighbor count (redundancy check)
- Signal strength to each neighbor (dBm)
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
Debian Server (cron or systemd)
    ↓
main.py (Python)
    ↓ SSH ControlMaster (persistent connections)
    ↓
All mesh nodes (192.168.1.1, .101, .114, .157, .167)
    ↓ Collect stats (batctl, iw, uptime, etc.)
    ↓
MQTT Broker (on Home Assistant)
    ↓ MQTT Discovery Protocol
    ↓
Home Assistant
    → Auto-discovered sensors
    → Custom dashboard
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
│       └── dashboard.yaml     # HA dashboard example
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

This creates a service account for the monitoring script. The Mosquitto broker uses username/password authentication (not API tokens).

**Note:** MQTT password is stored in Bitwarden for reference.

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

# Or manually:
pip install paho-mqtt pyyaml

# Deactivate when done (venv will be used by systemd service)
deactivate
```

**Note:** Debian 12+ requires using virtual environments for Python packages. The systemd service is configured to use `venv/bin/python` automatically.

### 3. SSH Key Setup

The existing `mesh_nodes` SSH key should already be set up. Verify:

```bash
# Check if key exists
ls -la ~/.ssh/mesh_nodes

# Test access to all nodes
for ip in 192.168.1.1 192.168.1.101 192.168.1.114 192.168.1.157 192.168.1.167; do
    ssh -i ~/.ssh/mesh_nodes -o ConnectTimeout=2 root@$ip "hostname"
done
```

If the key doesn't exist, see the main README for SSH key distribution instructions.

### 4. Configure SSH ControlMaster

Run the setup script to enable persistent SSH connections:

```bash
./setup-ssh.sh
```

This configures your SSH client to reuse connections, reducing overhead on mesh nodes from ~100ms handshake to <1ms per command.

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

Run the monitor manually to verify:

```bash
# Run using the virtual environment's Python
./venv/bin/python main.py

# Or activate venv first, then run
source venv/bin/activate
python3 main.py
# Press Ctrl+C to stop, then deactivate
deactivate
```

You should see:
- "Connected to MQTT broker"
- "Publishing MQTT discovery configs..."
- "Published discovery for gw-office"
- "Collected stats from gw-office" (and all 6 APs)
- "Poll completed in X.Xs"
- No errors in output

Check Home Assistant:
- Settings → Devices & Services → MQTT
- Should see 7 devices (gw-office and 6 APs)
- Each device has multiple sensors (neighbors, signal, clients, uptime, etc.)

### 7. Install as Systemd Service

```bash
# Copy service file
sudo cp owmm.service /etc/systemd/system/

# Edit service file if needed (username is 'adam', venv path already configured)
sudo nano /etc/systemd/system/owmm.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable owmm.service
sudo systemctl start owmm.service

# Check status
sudo systemctl status owmm.service

# View logs
sudo journalctl -u owmm.service -f
```

**Note:** The service file is pre-configured to use `venv/bin/python` from the virtual environment. If your username or paths differ, edit the service file accordingly.

## Configuration Reference

### config.yaml

```yaml
mqtt:
  broker: "192.168.1.151"           # Home Assistant IP
  port: 1883
  username: "mqtt_monitor"           # Dedicated MQTT user (password in Bitwarden)
  password: "your_mqtt_password"
  lwt_topic: "homeassistant/sensor/mesh_monitor/availability"
  discovery_prefix: "homeassistant"  # HA default

nodes:
  - name: "gw-office"
    ip: "192.168.1.1"
    type: "gateway"
  - name: "ap-central"
    ip: "192.168.1.101"
    type: "ap"
  - name: "ap-jade"
    ip: "192.168.1.114"
    type: "ap"
  - name: "ap-casita"
    ip: "192.168.1.157"
    type: "ap"
  - name: "ap-toilet"
    ip: "192.168.1.167"
    type: "ap"

ssh:
  key_file: "~/.ssh/mesh_nodes"
  connect_timeout: 3
  user: "root"

settings:
  poll_interval: 60                  # Seconds between polls
  mesh_interface: "phy1-mesh0"       # 5GHz mesh backhaul
  ap_interfaces:                     # Client WiFi interfaces
    - "phy0-ap0"  # Finca (LAN)
    - "phy0-ap1"  # IOT
    - "phy0-ap3"  # Guest
```

## MQTT Topics

The monitor uses **Home Assistant MQTT Discovery** to automatically create sensors. Topics follow this pattern:

**Discovery (published once on startup):**
```
homeassistant/sensor/mesh_gw_office_neighbors/config
homeassistant/sensor/mesh_ap_central_signal_avg/config
homeassistant/sensor/mesh_ap_jade_clients_finca/config
...
```

**State (published every poll_interval):**
```
homeassistant/sensor/mesh_gw_office/state
homeassistant/sensor/mesh_ap_central/state
...
```

**Availability (LWT):**
```
homeassistant/sensor/mesh_monitor/availability
  → "online" (monitor running)
  → "offline" (monitor crashed/stopped)
```

## Home Assistant Dashboard

Import the example dashboard:

1. Settings → Dashboards → Add Dashboard
2. Copy content from `homeassistant/dashboard.yaml`
3. Paste into dashboard YAML editor

The dashboard shows:
- Mesh topology map with signal strengths
- Per-node neighbor counts
- Client counts by SSID
- WAN failover status (gateway)
- Alerts for weak links (<-80 dBm)

## Metrics Details

### Mesh Health Metrics

**Per node:**
- `mesh_{node}_neighbors` - Count of mesh neighbors (expect 2-3 for redundancy)
- `mesh_{node}_signal_avg` - Average signal to all neighbors (dBm)
- `mesh_{node}_signal_min` - Weakest neighbor signal (dBm)
- `mesh_{node}_signal_max` - Strongest neighbor signal (dBm)

**Per neighbor link:** (published as attributes)
- Neighbor MAC address
- Signal strength (dBm)
- TX bitrate (Mbps)
- Last seen (seconds)

### Client Metrics

**Per SSID:**
- `mesh_{node}_clients_finca` - Count of clients on Finca SSID
- `mesh_{node}_clients_iot` - Count of clients on IOT SSID
- `mesh_{node}_clients_guest` - Count of clients on Guest SSID
- `mesh_{node}_clients_total` - Total clients on this node

### System Metrics

**All nodes:**
- `mesh_{node}_uptime` - Uptime in seconds
- `mesh_{node}_load_avg` - 1-minute load average

**Gateway only:**
- `mesh_gw_wan_active` - Active WAN interface (eth1 or eth2)
- `mesh_gw_wan1_status` - Starlink status (up/down)
- `mesh_gw_wan2_status` - T-Mobile status (up/down)
- `mesh_gw_batman_mode` - Gateway mode (server/client/off)

## Troubleshooting

### Monitor won't start
```bash
# Check logs
sudo journalctl -u owmm.service -n 50

# Common issues:
# - MQTT credentials wrong → Check HA MQTT integration
# - SSH key missing → Run setup instructions in main README
# - Python deps missing → pip3 install -r requirements.txt
```

### SSH connections timing out
```bash
# Test SSH manually
ssh -i ~/.ssh/mesh_nodes root@192.168.1.1 "hostname"

# Check ControlMaster sockets
ls -la ~/.ssh/sockets/

# Clean up stale sockets
rm ~/.ssh/sockets/*
```

### Sensors not appearing in HA
```bash
# Check MQTT integration in HA
# Settings → Devices & Services → MQTT → Configure
# Enable discovery (should be on by default)

# Check MQTT messages are being published
# Developer Tools → MQTT → Listen to topic: homeassistant/sensor/#

# Restart HA to force discovery refresh
# Settings → System → Restart
```

### Metrics are stale/not updating
```bash
# Check service is running
sudo systemctl status owmm.service

# Check for errors in logs
sudo journalctl -u owmm.service -f

# Manually run to see errors
python3 ~/code/wrtflasher/monitoring/main.py
```

## Development

### Testing Changes

```bash
# Stop service
sudo systemctl stop owmm.service

# Run manually with debug output
python3 main.py

# Ctrl+C to stop

# Restart service
sudo systemctl start owmm.service
```

### Adding New Metrics

1. Add collection logic in `collect_node_stats()` function
2. Add metric to `publish_discovery()` with proper device_class and unit
3. Test manually to verify MQTT messages
4. Restart service

### Changing Poll Interval

Edit `config.yaml`:
```yaml
settings:
  poll_interval: 300  # 5 minutes
```

Then restart:
```bash
sudo systemctl restart owmm.service
```

## Performance

**Resource usage (on Debian server):**
- CPU: <1% average (spikes to ~5% during 1-second poll)
- Memory: ~50MB (Python + SSH connections)
- Network: ~10KB per poll (5 nodes × ~2KB each)

**Impact on mesh nodes:**
- Minimal: Commands execute in <100ms per node
- ControlMaster reuses SSH connection (no repeated handshakes)
- Commands are read-only (no configuration changes)

**MQTT traffic:**
- Discovery: ~5KB once on startup (all sensor configs)
- State: ~2KB per poll (5 nodes × ~400 bytes JSON)
- At 60-second interval: ~120KB/hour

## Security Notes

- SSH key is read-only access to mesh nodes
- MQTT credentials should use dedicated user (not admin)
- Monitor runs as non-root user on Debian server
- No ports exposed (only outbound SSH and MQTT)
- ControlMaster sockets are user-only (chmod 700)

## Future Enhancements

- [ ] Add bandwidth monitoring (iperf3 tests between nodes)
- [ ] Add alerting (Telegram/email on mesh failures)
- [ ] Add historical graphing (InfluxDB integration)
- [ ] Add WiFi channel utilization metrics
- [ ] Add batman-adv routing table changes detection
- [ ] Add automatic mesh topology diagram generation
