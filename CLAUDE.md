# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository builds custom OpenWRT firmware images for a batman-adv mesh network with three isolated VLANs (LAN, IoT, Guest) and 802.11r fast roaming support. The build system uses OpenWRT ImageBuilder to create firmware for two device types:

- **Gateway node** (OpenWRT One): Runs DHCP servers, firewall, and acts as the mesh gateway
- **AP nodes** (GL-MT3000 BerylAX): Mesh clients that extend the wireless network

### CRITICAL OPERATIONAL RULE
- **NEVER** run `/etc/init.d/network restart` on mesh AP nodes. It will reliably lock up the device and require a physical power cycle. **ALWAYS** use `reboot` instead.

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
- DNS: Static DNS servers (Cloudflare 1.1.1.1/1.0.0.1, Quad9 9.9.9.9 backup) ensure DNS resolution works during WAN failover

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
- Exceptions:
  - Home Assistant IP (192.168.1.151 from LAN) can access IoT network
  - IoT devices can connect to Home Assistant MQTT broker (port 1883) for sensor data publishing

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

### SQM (Smart Queue Management)

SQM uses CAKE (`piece_of_cake.qos`) on both WAN interfaces to manage bufferbloat. Settings are configured directly on the gateway via UCI, not via `generate-config.sh`.

| WAN | Interface | Download | Upload |
|-----|-----------|----------|--------|
| Starlink | eth1 | 120 Mbps | 9 Mbps |
| T-Mobile | eth2 | 65 Mbps | 23 Mbps |

SQM limits should be set to ~85-90% of measured link speed. If Starlink or T-Mobile speeds change significantly, adjust via:
```bash
ssh root@192.168.1.1 "uci set sqm.wan.download=120000; uci set sqm.wan.upload=9000; uci commit sqm; /etc/init.d/sqm restart"
```

### Monitoring Performance

The mesh monitoring script (`monitoring/main.py`) runs on deb and SSHes into all mesh nodes every 5 minutes. It uses a **single batched SSH call per node** to collect all metrics (mesh neighbors, signal strength, client counts, system stats, gateway WAN status) in one shot.

**Important**: The previous implementation used 8-12 separate SSH calls per node per poll cycle, which caused the gateway CPU to run at 100% (load average ~6.0 on 2 cores). This was halving network throughput through the gateway. The batched approach reduced gateway load from 5.9 to 0.1.

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

## Home Assistant Integration

### Workflow

HA config files (automations, dashboards, sensors, template sensors) are version-controlled in this repo under `monitoring/homeassistant/`. This repo is the source of truth — edit files here, commit to git, then deploy to HA via `scp`. After deploying automations, reload them in HA: Developer Tools → YAML → Reload Automations.

The `monitoring/` directory contains a Python script that polls mesh nodes via SSH and publishes stats to Home Assistant via MQTT.

- **monitoring/main.py** - MQTT publisher script (runs on deb)
- **monitoring/homeassistant/** - HA config files from live instance:
  - `automations.yaml`, `configuration.yaml`, `sensors.yaml`, `template_sensors.yaml`
  - `automations/` - Individual automation YAML files (loaded via `!include_dir_merge_list`)
  - `dashboards/mesh.yaml` - Mesh network monitoring dashboard
  - `dashboards/casita.yaml` - Casita guest house dashboard
  - `dashboards/ac.yaml` - AC units dashboard (all 8 units, with Tuya setpoint workarounds)
  - `dashboards/climate.yaml` - Temperature & humidity sensor dashboard
  - `dashboards/thread-devices.yaml` - Thread/Matter device dashboard (lights, plugs, door sensors, batteries)
  - `dashboards/lights.yaml` - Lights control dashboard
  - `blueprints/` - Automation blueprints
- **Poll interval**: 300 seconds / 5 minutes (configurable in config.yaml)

### HA UI Notes

- **Services is now Actions** - In Developer Tools, "Services" was renamed to "Actions"
- **Reload automations**: Developer Tools → YAML → Reload Automations
- **Test notifications**: Developer Tools → Actions → notify.mobile_app_*

### Syncing HA Config

**IMPORTANT:** Do NOT edit automations in the HA UI. The UI writes to `/homeassistant/automations.yaml` (root), but HA loads from `/homeassistant/automations/` (directory via `!include_dir_merge_list`). UI edits will appear to save but won't take effect. The root `automations.yaml` is set to `[]` to prevent stale data.

**Automation deployment workflow:**
1. Edit YAML files in `monitoring/homeassistant/automations/`
2. Push to HA: `scp monitoring/homeassistant/automations/*.yaml ha:/homeassistant/automations/`
3. Validate config: use `ha_check_config` (MCP tool) or `ssh ha 'ha core check'`
4. Reload: use `ha_reload_core(target="automations")` (MCP tool) or HA UI → Developer Tools → YAML → Reload Automations
5. Verify: check the automation entity exists and state is `on`

```bash
# Push automations
scp monitoring/homeassistant/automations/*.yaml ha:/homeassistant/automations/

# Push dashboards
scp monitoring/homeassistant/dashboards/*.yaml ha:/homeassistant/dashboards/

# Pull automations from HA (if needed to sync back)
scp ha:/homeassistant/automations/*.yaml monitoring/homeassistant/automations/
```

HA Green config directory is `/homeassistant/` (not `/config/`).

## SSH Access to Home Assistant

The repository includes a convenient shortcut for interacting with the Home Assistant VM via SSH. The default SSH alias is **`ha`**, which resolves to the appropriate host and user (typically `homeassistant` on the HA machine).

Typical commands:

- **List automations folder**:
  ```bash
  ssh ha 'ls -l /homeassistant/automations'
  ```

- **Copy a file to HA**:
  ```bash
  scp <local_path> ha:/homeassistant/automations/
  ```

- **Copy a file from HA**:
  ```bash
  scp ha:/homeassistant/automations/<remote_file> <local_dir>/
  ```

These commands assume the SSH key for the `ha` alias is set up on your workstation. Adjust the paths as needed for other HA directories (e.g., `/homeassistant/configuration.yaml`).

## IoT VLAN Device Management

### ESPHome DHCP Reservations

The 5 Athom temperature/humidity sensors on the IoT VLAN (192.168.3.0/24) have DHCP static leases on the gateway to prevent IP changes after power outages. ESPHome devices are registered in HA by IP address, so if their IPs change, HA loses contact.

| Sensor | MAC Address | Static IP |
|--------|-------------|-----------|
| athom-6089e8 | fc:01:2c:60:89:e8 | 192.168.3.217 |
| athom-604bec | fc:01:2c:60:4b:ec | 192.168.3.207 |
| athom-609ecc | fc:01:2c:60:9e:cc | 192.168.3.168 |
| athom-602e3c | fc:01:2c:60:2e:3c | 192.168.3.110 |
| athom-607f68 | fc:01:2c:60:7f:68 | 192.168.3.229 |

These static leases are configured directly on the gateway via UCI (`dhcp.@host[]`), **not** via `generate-config.sh`. They persist across reboots but would be lost if the gateway is reflashed.

To add a new DHCP reservation:
```bash
ssh root@192.168.1.1 "
uci add dhcp host
uci set dhcp.@host[-1].name='device-name'
uci set dhcp.@host[-1].mac='xx:xx:xx:xx:xx:xx'
uci set dhcp.@host[-1].ip='192.168.3.XXX'
uci commit dhcp
/etc/init.d/dnsmasq restart
"
```

If ESPHome devices go offline after a power outage, check if their IPs changed:
```bash
ssh root@192.168.1.1 'cat /tmp/dhcp.leases' | grep -i athom
```

Then update the HA config entries at `/homeassistant/.storage/core.config_entries` with the new IPs and restart HA Core.

## HA Backup Configuration

Automatic backups are configured in HA (Settings -> System -> Backups):
- **Schedule**: Daily
- **Retention**: 10 copies
- **Includes**: All addons (OTBR, Matter Server, Mosquitto, etc.) + HA Core + database
- **Storage**: Local (`hassio.local`) - 28GB eMMC, ~320MB per backup

Config file: `/homeassistant/.storage/backup`

### Thread/Matter Recovery Notes

Matter device commissioning data is stored in the Matter Server addon. If this data is lost (e.g., power outage corruption), all Matter-over-Thread devices must be factory reset and re-commissioned. There is no way to recover without a backup that includes the `core_matter_server` addon data.

**Do NOT press "Configure" on the ZBT-2 radio** in the HA UI unless you intend to re-flash its firmware. This can reset Thread network credentials and disconnect all Thread devices.

### Re-commissioning Thread/Matter Devices

If the Matter Server loses its node data, all devices must be factory reset and re-paired.

Last re-commissioning: Feb 9, 2026 (power outage Feb 7 wiped Matter Server node data). All devices re-commissioned on new fabric `0CC6CDD83C99E0F0`. A post-recommission backup was created (`Post-Thread-recommission-2026-02-09`).

Current inventory (13 Thread devices + 1 WiFi Matter device):

**IKEA MYGGBETT Door/Window Sensors (7 total):**
- Front Door (named at device level, entity: binary_sensor.myggbett_door_window_sensor_door_8)
- 6 unnamed (binary_sensor.myggbett_door_window_sensor_door_2 thru _7) - need identification by opening/closing each door
- Factory reset: Open the back cover, press the small reset button and hold for 5+ seconds until the LED blinks rapidly
- The reset button is a tiny pinhole next to the battery
- After reset, the LED will blink slowly indicating pairing mode

**Onvis S4 Smart Plugs (5 total):**
- Dehumidifier 1 (switch.s4), Dehumidifier 2 (switch.s4_2), S4 (switch.s4_3), Thread Smart Plug (switch.thread_smart_plug), Spare Plug (switch.s4_4)
- Factory reset: Press and hold the button on the plug for 10+ seconds until the LED flashes rapidly
- LED will blink indicating pairing mode

**Eve Light Switch 20ECE4101 (2 total):**
- Tesla Room (light.tesla_room_light), Cocina Baño (light.cocina_bano)
- Factory reset: Press and hold the button on the switch for 10+ seconds until the LED flashes
- Some Eve switches require pressing the reset button 3 times quickly, then holding on the 4th press

**IKEA BILRESA Dual Button (1 total):**
- Entities: event.bilresa_dual_button_button_1, event.bilresa_dual_button_button_2
- Factory reset: Press the small reset button (pinhole on back) for 5+ seconds with a pin/paperclip until LED blinks

**Re-commissioning steps (after factory reset):**
1. Ensure OTBR addon is running and Thread network is healthy
2. In HA: Settings -> Devices & Services -> Add Integration -> Add Matter device
3. Use the device's Matter pairing code (QR code or 11-digit numeric code, usually on the device or in its packaging)
4. HA will commission the device onto the Thread network via the OTBR
5. The device should appear as a new Matter device in HA
6. Rename the device and assign it to the correct area

**Kasa KS225 WiFi Dimmer (1 total, WiFi Matter - not Thread):**
- Master Bedroom dimmer, currently on tplink integration
- Matter code: `1642-030-5693`
- Needs factory reset: remove from Kasa app, hold dimmer button 10s until LED blinks amber/green
- Re-commission via Matter in HA (must be on LAN WiFi, same subnet as HA for mDNS discovery)
- Direct Matter is preferred over Kasa/tplink integration (fully local, no cloud dependency)

**Tips:**
- Commission devices one at a time and verify each works before moving to the next
- Keep the device close to the HA/OTBR during initial commissioning
- If commissioning fails, try factory resetting the device again
- The Matter pairing code is often on a sticker on the device itself or on the box/manual
- IKEA devices: the code is on the box and on a small card inside the packaging

## Inovelli Switch Config Button Automations

The BBQ area has three Inovelli on/off switches with programmable config buttons (small side button). Each switch exposes `event` entities for button presses:

| Switch | Config Button Entity | Function |
|--------|---------------------|----------|
| BBQ Fan | `event.inovelli_on_off_switch_button_config` | Toggle front gate (Remootio) |
| Bar Lights | `event.inovelli_on_off_switch_button_config_2` | Cycle bar bulb colors + LED strip |
| BBQ Center Fan | `event.inovelli_on_off_switch_button_config_3` | Unassigned |

**Event types**: Inovelli config buttons fire `multi_press_1` (single press), `multi_press_2` (double), etc. — NOT `press`.

**Trigger pattern for Inovelli event entities**: Do NOT use `attribute: event_type to: "multi_press_1"` — consecutive single presses have the same attribute value, so the trigger won't fire after the first press. Instead, trigger on any state change and filter in a condition:
```yaml
triggers:
  - trigger: state
    entity_id: event.inovelli_on_off_switch_button_config
conditions:
  - condition: template
    value_template: "{{ state_attr('event.inovelli_on_off_switch_button_config', 'event_type') == 'multi_press_1' }}"
```

### Gate Button (BBQ Fan Config)
- Automation: `automations/bbq_fan_config_toggle_gate.yaml`
- Calls `cover.toggle` on `cover.front_gate_trigger` (template cover wrapper)

### Color Cycle (Bar Lights Config)
- Automation: `automations/bar_lights_color_cycle.yaml`
- Helper: `input_number.bar_lights_color_index` (tracks current color, wraps via `% 8`)
- Cycles through 8 colors: warm white, red, orange, yellow, green, blue, purple, pink
- Sets color on both `light.bar_bulbs` (bar1/bar2/bar3 group) and `light.inovelli_on_off_switch_light_rgb_indicator_2` (LED strip)

## Remootio Gate (Template Cover)

The Remootio (`cover.remootio_gate`) is a single-button relay gate controller. HA's cover entity won't send `open_cover` when already open or `close_cover` when already closed, which breaks toggle behavior.

**Solution**: A template cover `cover.front_gate_trigger` in `configuration.yaml` wraps the Remootio:
- Reports state from `cover.remootio_gate`
- `open_cover` → calls `cover.open_cover` on Remootio
- `close_cover` → calls `cover.close_cover` on Remootio
- `stop_cover` → calls `cover.open_cover` on Remootio (sends pulse to stop/reverse)

Use `cover.front_gate_trigger` in automations instead of `cover.remootio_gate` directly.

## Bedroom AC Schedule Automations

Automations for `climate.master_ac` with day/night temperature schedules:

| Automation | File | Trigger | Setpoint |
|-----------|------|---------|----------|
| Day schedule | `bedroom_ac_day.yaml` | 10:00 AM | 78°F |
| Night schedule | `bedroom_ac_night.yaml` | 10:00 PM | 73°F |
| Manual override | `bedroom_ac_manual_override.yaml` | Temperature changed manually | Sets override flag |
| Override expiry | `bedroom_ac_override_expiry.yaml` | Timer expires | Clears override flag |
| Away mode | `bedroom_ac_away.yaml` | Away toggle | Turns off AC |
| Return mode | `bedroom_ac_return.yaml` | Away toggle off | Restores last auto temp |

**Guards**: Day/night schedules only fire if:
- `input_boolean.bedroom_ac_manual_override` is off
- `input_boolean.bedroom_ac_away` is off
- `climate.master_ac` is NOT off (won't turn on an AC that's off)

## Balcony Motion Cube Light

Automation: `automations/balcony_motion_cube_light.yaml` (extracted from `automations.yaml`)

Turns on `switch.cube` when `binary_sensor.gym_motion` detects motion at night (below 30 lux).

**Key behaviors:**
- **Skip if cube already on** — won't interfere with manual or gate-triggered usage
- **15-minute no-motion timer** — uses `wait_for_trigger` on motion clearing, not a fixed delay
- **Manual off respected** — detects cube turned off during wait and stops cleanly
- **5-minute cooldown** — after cube is turned off (manually or by automation), motion won't re-trigger for 5 minutes (`state: "off" for: 5 minutes` condition)
- **mode: single** — while waiting, new motion triggers are silently dropped

## HA Assist / Jeeves

The HA Assist menu (top-left of dashboard) has three conversation agents:
- **Home Assistant** — built-in local command parser
- **Home Assistant Cloud** — Nabu Casa cloud NLP
- **Jeeves** — local LLM via **Ollama** integration, running **MiniMax M2.5** model (`conversation.ollama_conversation`)

Configured at: Settings → Voice Assistants (pipeline settings)

## AC Unit Temperature Fixes (Feb 10, 2026)

### Problem

AC integrations report temperatures with mixed units, causing incorrect displays:

- **Main AC** (`climate.lnlinkha_4100f2d7bcac0000b90460129f07`) — MQTT/LinknLink eRemote, platform: `mqtt`. Reports ALL temperatures in °C (current_temp, setpoint, min/max 16-32°C). Without a unit override, HA assumes system unit (°F) and displays raw Celsius values labeled as °F.
- **Cocina** (`climate.casita_kitchen`) and **Cuarito** (`climate.air_conditioner_2`) — Tuya integration. Current temperature is correctly reported in °C (HA auto-converts to °F). But Tuya **pre-converts setpoints to °F** while telling HA they're °C, causing HA to double-convert (e.g., 73°F treated as 73°C → 163°F).

### Solution

**Main AC**: `temperature_unit: °C` override in `configuration.yaml` under `homeassistant.customize`. Tells HA the entity reports in °C → HA correctly converts all values to °F. Thermostat card works normally.

**Cocina/Cuarito**: Template sensors in `template_sensors.yaml` reverse the double-conversion for setpoints:
- `sensor.cocina_ac_setpoint` — `((attr_temp - 32) * 5/9)` recovers the correct °F value
- `sensor.cuarito_ac_setpoint` — same formula
- Current temperatures are correct without any override
- Dashboard uses entities cards (not thermostat cards) to display corrected values

### AC Automations

Two automations for the Main AC, triggered by the **living room Athom sensor** (`sensor.athom_temperature_humidity_sensor_6089e8_temperature`):
- `automations/main_ac_on.yaml` — Living room temp above 78°F for 5 min + AC is off → set to **dry mode** + mobile notification
- `automations/main_ac_off.yaml` — Living room temp below 75°F for 5 min + AC is in dry mode → turn off + mobile notification

### AC Entity Reference

| Name | Entity ID | Platform | Unit Issues |
|------|-----------|----------|-------------|
| Master | climate.master_ac | ? | None (works correctly) |
| Gym | climate.gym_ac | ? | None |
| Jade's | climate.jade_s_ac | ? | None |
| Jared's | climate.jared_s_ac | ? | None |
| Main | climate.lnlinkha_4100f2d7bcac0000b90460129f07 | mqtt (LinknLink eRemote) | Fixed via °C override |
| Big AC | climate.big_ac | ? | Unknown (not investigated) |
| Cocina | climate.casita_kitchen | tuya | Setpoint double-conversion, fixed via template sensor |
| Cuarito | climate.air_conditioner_2 | tuya | Setpoint double-conversion, fixed via template sensor |

### Pending Thread/Matter Tasks

All 16 Matter devices are commissioned (Feb 9, 2026). Remaining cleanup:

- **Duplicate entities on serial-matched devices**: Re-commissioning Onvis/Eve devices created a second entity on each (e.g., `switch.thread_smart_plug` + `switch.thread_smart_plug_2`). The duplicates (`_2` suffixed on Onvis/Eve, plus `switch.dehumidifier`/`switch.dehumidifier_2`, `light.light`, `light.cocina_bano_2`, `switch.s4_5`) should be removed from the entity registry.
- **Kasa KS225 dimmer entity rename**: Currently `light.light_2` - should be renamed to `light.master_bedroom`.
- **6 MYGGBETT door sensors need naming**: Re-commissioned with default names (`binary_sensor.myggbett_door_window_sensor_door_2` thru `_7`). Open/close each door to identify which entity corresponds to which physical door, then rename in HA UI.
- **Orphaned old entities**: Old door sensor entities from deleted devices still exist in entity registry (e.g., `binary_sensor.front_door`, `binary_sensor.costco_door`, `binary_sensor.tesla_door`, etc.) with no device attached. Should be removed.
- **Thread-devices dashboard**: YAML file created and SCPed to HA at `/homeassistant/dashboards/thread-devices.yaml`. Needs to be registered in `configuration.yaml` under `lovelace.dashboards` and old storage-mode entry removed from `/homeassistant/.storage/lovelace.thread_devices`. Wait until all devices are named/cleaned up before finalizing.
