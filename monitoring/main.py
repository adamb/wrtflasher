#!/usr/bin/env python3
"""
OpenWRT Mesh Network Monitor for Home Assistant
Monitors mesh health, client counts, and WAN status across all nodes
Publishes to Home Assistant via MQTT Discovery
"""

import os
import sys
import time
import json
import yaml
import subprocess
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any
from concurrent.futures import ThreadPoolExecutor, as_completed
import paho.mqtt.client as mqtt
import requests

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('mesh_monitor')


class MeshMonitor:
    """Monitor OpenWRT mesh network and publish metrics to Home Assistant via MQTT"""

    def __init__(self, config_path: str = 'config.yaml'):
        """Initialize monitor with configuration"""
        self.config = self.load_config(config_path)
        self.mqtt_client = None
        self.connected = False

        # Expand and resolve SSH key path
        self.ssh_key = Path(self.config['ssh']['key_file']).expanduser().resolve()
        if not self.ssh_key.exists():
            raise FileNotFoundError(f"SSH key not found: {self.ssh_key}")

        # Debug mode
        if self.config['settings'].get('debug', False):
            logger.setLevel(logging.DEBUG)

    def load_config(self, config_path: str) -> Dict:
        """Load YAML configuration file"""
        if not os.path.exists(config_path):
            raise FileNotFoundError(f"Config file not found: {config_path}")

        with open(config_path, 'r') as f:
            return yaml.safe_load(f)

    def ssh_command(self, node_ip: str, command: str, timeout: int = 5) -> Optional[str]:
        """Execute SSH command on remote node"""
        ssh_opts = [
            '-i', self.ssh_key,
            '-o', 'StrictHostKeyChecking=no',
            '-o', 'UserKnownHostsFile=/dev/null',
            '-o', f'ConnectTimeout={self.config["ssh"]["connect_timeout"]}',
            '-o', 'ControlMaster=auto',
            '-o', 'ControlPath=~/.ssh/sockets/%r@%h:%p',
            '-o', 'ControlPersist=600'
        ]

        cmd = ['ssh'] + ssh_opts + [f'{self.config["ssh"]["user"]}@{node_ip}', command]

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                logger.warning(f"SSH command failed on {node_ip}: {result.stderr}")
                return None
        except subprocess.TimeoutExpired:
            logger.error(f"SSH timeout on {node_ip}")
            return None
        except Exception as e:
            logger.error(f"SSH error on {node_ip}: {e}")
            return None

    def collect_mesh_neighbors(self, node_ip: str) -> Dict[str, Any]:
        """Collect batman-adv mesh neighbor information"""
        output = self.ssh_command(node_ip, "batctl n")
        if not output:
            return {'count': 0, 'neighbors': []}

        neighbors = []
        lines = output.strip().split('\n')[1:]  # Skip header

        for line in lines:
            parts = line.split()
            if len(parts) >= 2:
                neighbor_mac = parts[1]
                # Get signal strength using iw
                mesh_iface = self.config['settings']['mesh_interface']
                signal_output = self.ssh_command(
                    node_ip,
                    f"iw dev {mesh_iface} station get {neighbor_mac} 2>/dev/null | grep 'signal avg' | awk '{{print $3}}'"
                )

                signal = None
                if signal_output:
                    try:
                        signal = int(signal_output.split()[0])
                    except (ValueError, IndexError):
                        pass

                neighbors.append({
                    'mac': neighbor_mac,
                    'signal': signal
                })

        # Calculate statistics
        signals = [n['signal'] for n in neighbors if n['signal'] is not None]
        return {
            'count': len(neighbors),
            'neighbors': neighbors,
            'signal_avg': round(sum(signals) / len(signals), 1) if signals else None,
            'signal_min': min(signals) if signals else None,
            'signal_max': max(signals) if signals else None
        }

    def collect_client_counts(self, node_ip: str) -> Dict[str, int]:
        """Collect WiFi client counts per SSID"""
        clients = {'finca': 0, 'iot': 0, 'guest': 0, 'total': 0}

        for iface in self.config['settings']['ap_interfaces']:
            # Count stations on this interface
            count_output = self.ssh_command(
                node_ip,
                f"iw dev {iface} station dump 2>/dev/null | grep -c '^Station' || echo 0"
            )

            if count_output:
                try:
                    count = int(count_output)
                    clients['total'] += count

                    # Map interface to SSID
                    if 'ap0' in iface:
                        clients['finca'] = count
                    elif 'ap1' in iface:
                        clients['iot'] = count
                    elif 'ap3' in iface:
                        clients['guest'] = count
                except ValueError:
                    pass

        return clients

    def collect_system_stats(self, node_ip: str) -> Dict[str, Any]:
        """Collect system statistics (uptime, load)"""
        # Get uptime
        uptime_output = self.ssh_command(node_ip, "cat /proc/uptime | awk '{print $1}'")
        uptime = None
        if uptime_output:
            try:
                uptime = int(float(uptime_output))
            except ValueError:
                pass

        # Get load average
        load_output = self.ssh_command(node_ip, "cat /proc/loadavg | awk '{print $1}'")
        load_avg = None
        if load_output:
            try:
                load_avg = float(load_output)
            except ValueError:
                pass

        return {
            'uptime': uptime,
            'load_avg': load_avg
        }

    def collect_gateway_stats(self, node_ip: str) -> Dict[str, Any]:
        """Collect gateway-specific stats (WAN status, batman mode)"""
        stats = {}

        # Check WAN interfaces status via mwan3 (uses actual health checks)
        wan1_output = self.ssh_command(node_ip, "ubus call mwan3 status | jsonfilter -e '$.interfaces.wan.status' 2>/dev/null")
        stats['wan1_status'] = wan1_output if wan1_output else 'unknown'

        wan2_output = self.ssh_command(node_ip, "ubus call mwan3 status | jsonfilter -e '$.interfaces.wan2.status' 2>/dev/null")
        stats['wan2_status'] = wan2_output if wan2_output else 'unknown'

        # Get active WAN interface from routing
        active_wan = self.ssh_command(node_ip, "ip route get 8.8.8.8 2>/dev/null | head -1 | awk '{print $5}'")
        stats['active_wan'] = active_wan if active_wan else 'unknown'

        # Get batman-adv gateway mode
        batman_mode = self.ssh_command(node_ip, "batctl gw 2>/dev/null")
        if batman_mode:
            if 'server' in batman_mode.lower():
                stats['batman_mode'] = 'server'
            elif 'client' in batman_mode.lower():
                stats['batman_mode'] = 'client'
            else:
                stats['batman_mode'] = 'off'
        else:
            stats['batman_mode'] = 'unknown'

        return stats

    def collect_ghn_stats(self, device: Dict[str, str]) -> Dict[str, Any]:
        """Collect G.hn PLC connection stats from web interface"""
        from requests.auth import HTTPBasicAuth

        ghn_name = device['name']
        ghn_ip = device['ip']
        username = device.get('username', 'admin')

        # Get password from environment variable
        password_env = device.get('password_env', '')
        password = os.environ.get(password_env, '')
        if not password:
            logger.warning(f"G.hn device {ghn_name}: password environment variable '{password_env}' not set")
            return {'connected': False, 'error': 'password_missing'}

        # Use a session to handle cookies (G.hn devices require session cookies)
        session = requests.Session()

        # First, POST the password to establish a session and get cookies
        root_url = f"http://{ghn_ip}/"
        try:
            # The G.hn device requires a POST with .PASSWORD field to establish session
            session.post(root_url, data={'.PASSWORD': password}, timeout=10)
        except requests.RequestException as e:
            logger.warning(f"G.hn device {ghn_name}: Failed to establish session: {e}")
            return {'connected': False, 'error': 'session_failed'}

        # Now fetch the ghn.html page with the session (including cookies)
        url = f"http://{ghn_ip}/ghn.html"
        try:
            response = session.get(url, timeout=10)
            response.raise_for_status()
        except requests.RequestException as e:
            logger.warning(f"G.hn device {ghn_name}: Failed to fetch: {e}")
            return {'connected': False, 'error': str(e)}

        # Parse the JavaScript variables from the response
        # Extract pcdids (device IDs), pcmastr (MACs), pcptx (Tx rates), pcprx (Rx rates)
        import re

        content = response.text

        # Extract pcdids array
        pcdids_match = re.search(r'var pcdids=new Array\(([^)]+)\)', content)
        # Extract pcmastr array
        pcmastr_match = re.search(r'var pcmastr="([^"]+)"', content)
        # Extract pcptx array
        pcptx_match = re.search(r'var pcptx=new Array\(([^)]+)\)', content)
        # Extract pcprx array
        pcprx_match = re.search(r'var pcprx=new Array\(([^)]+)\)', content)

        if not all([pcdids_match, pcmastr_match, pcptx_match, pcprx_match]):
            logger.warning(f"G.hn device {ghn_name}: Could not parse connection data")
            return {'connected': False, 'error': 'parse_failed'}

        # Parse arrays
        try:
            pcdids = [int(x.strip()) for x in pcdids_match.group(1).split(',')]
            pcmastr = pcmastr_match.group(1).split(',')
            pcptx = [int(x.strip()) for x in pcptx_match.group(1).split(',')]
            pcprx = [int(x.strip()) for x in pcprx_match.group(1).split(',')]

            # Parse own MAC and DID
            mymac_match = re.search(r"var mymac='([^']+)'", content)
            mydid_match = re.search(r"var mydid='([^']+)'", content)
            mymac = mymac_match.group(1) if mymac_match else ''
            mydid = int(mydid_match.group(1)) if mydid_match else 0

            # Build list of connected devices (excluding self and empty entries)
            connections = []
            for i in range(len(pcdids)):
                did = pcdids[i]
                mac = pcmastr[i].strip()
                # Skip self, empty entries
                if did == mydid or mac == mymac or mac == '00:00:00:00:00:00':
                    continue
                # Calculate Tx/Rx rates (values are in 32kbps units)
                tx_mbps = round(pcptx[i] * 32 / 1000, 1)
                rx_mbps = round(pcprx[i] * 32 / 1000, 1)
                connections.append({
                    'device_id': did,
                    'mac': mac,
                    'tx_mbps': tx_mbps,
                    'rx_mbps': rx_mbps
                })

            return {
                'connected': True,
                'my_device_id': mydid,
                'my_mac': mymac,
                'connections': connections,
                'connection_count': len(connections)
            }
        except (ValueError, IndexError) as e:
            logger.warning(f"G.hn device {ghn_name}: Error parsing data: {e}")
            return {'connected': False, 'error': 'parse_error'}

    def collect_node_stats(self, node: Dict[str, str]) -> Dict[str, Any]:
        """Collect all statistics for a single node"""
        node_name = node['name']
        node_ip = node['ip']
        node_type = node['type']

        logger.debug(f"Collecting stats from {node_name} ({node_ip})")

        stats = {
            'name': node_name,
            'ip': node_ip,
            'type': node_type,
            'timestamp': int(time.time())
        }

        # Collect mesh neighbor information
        mesh_data = self.collect_mesh_neighbors(node_ip)
        stats['mesh'] = mesh_data

        # Collect client counts
        clients = self.collect_client_counts(node_ip)
        stats['clients'] = clients

        # Collect system stats
        system = self.collect_system_stats(node_ip)
        stats['system'] = system

        # Collect gateway-specific stats
        if node_type == 'gateway':
            gateway = self.collect_gateway_stats(node_ip)
            stats['gateway'] = gateway

        return stats

    def collect_all_ghn_stats(self) -> List[Dict[str, Any]]:
        """Collect statistics from all G.hn devices"""
        ghn_stats = []

        ghn_devices = self.config.get('ghn_devices', [])
        if not ghn_devices:
            logger.debug("No G.hn devices configured")
            return ghn_stats

        for device in ghn_devices:
            try:
                stats = self.collect_ghn_stats(device)
                stats['name'] = device['name']
                stats['ip'] = device['ip']
                ghn_stats.append(stats)
                if stats.get('connected'):
                    logger.info(f"Collected G.hn stats from {device['name']}")
            except Exception as e:
                logger.error(f"Failed to collect G.hn stats from {device['name']}: {e}")

        return ghn_stats

    def collect_all_nodes(self) -> tuple[List[Dict[str, Any]], List[str], List[str]]:
        """Collect statistics from all nodes in parallel

        Returns:
            tuple: (all_stats, online_nodes, offline_nodes)
        """
        all_stats = []
        online_nodes = []
        offline_nodes = []

        with ThreadPoolExecutor(max_workers=len(self.config['nodes'])) as executor:
            future_to_node = {
                executor.submit(self.collect_node_stats, node): node
                for node in self.config['nodes']
            }

            for future in as_completed(future_to_node):
                node = future_to_node[future]
                try:
                    stats = future.result(timeout=10)
                    all_stats.append(stats)
                    online_nodes.append(node['name'])
                    logger.info(f"Collected stats from {node['name']}")
                except Exception as e:
                    offline_nodes.append(node['name'])
                    logger.error(f"Failed to collect stats from {node['name']}: {e}")

        return all_stats, online_nodes, offline_nodes

    def publish_node_availability(self, node_name: str, available: bool):
        """Publish availability status for a node"""
        prefix = self.config['mqtt']['discovery_prefix']
        node_id = node_name.replace('-', '_')
        availability_topic = f'{prefix}/sensor/mesh_node_{node_id}/availability'
        status = 'online' if available else 'offline'

        self.mqtt_client.publish(
            availability_topic,
            status,
            qos=1,
            retain=True
        )
        logger.debug(f"Published availability for {node_name}: {status}")

    def on_connect(self, client, userdata, flags, rc):
        """MQTT connection callback"""
        if rc == 0:
            logger.info("Connected to MQTT broker")
            self.connected = True
            # Publish availability
            client.publish(
                self.config['mqtt']['lwt_topic'],
                'online',
                qos=1,
                retain=True
            )
        else:
            logger.error(f"MQTT connection failed with code {rc}")
            self.connected = False

    def on_disconnect(self, client, userdata, rc):
        """MQTT disconnection callback"""
        logger.warning(f"Disconnected from MQTT broker (code {rc})")
        self.connected = False

    def setup_mqtt(self):
        """Setup MQTT connection with LWT"""
        mqtt_config = self.config['mqtt']

        self.mqtt_client = mqtt.Client()
        self.mqtt_client.on_connect = self.on_connect
        self.mqtt_client.on_disconnect = self.on_disconnect

        # Set Last Will and Testament
        self.mqtt_client.will_set(
            mqtt_config['lwt_topic'],
            'offline',
            qos=1,
            retain=True
        )

        # Set credentials if provided
        if mqtt_config.get('username') and mqtt_config.get('password'):
            self.mqtt_client.username_pw_set(
                mqtt_config['username'],
                mqtt_config['password']
            )

        # Connect to broker
        try:
            self.mqtt_client.connect(
                mqtt_config['broker'],
                mqtt_config.get('port', 1883),
                60
            )
            self.mqtt_client.loop_start()

            # Wait for connection
            timeout = 10
            start = time.time()
            while not self.connected and (time.time() - start) < timeout:
                time.sleep(0.1)

            if not self.connected:
                raise ConnectionError("MQTT connection timeout")

        except Exception as e:
            logger.error(f"Failed to connect to MQTT broker: {e}")
            raise

    def publish_discovery(self, node: Dict[str, Any]):
        """Publish Home Assistant MQTT Discovery configs for a node"""
        prefix = self.config['mqtt']['discovery_prefix']
        node_id = node['name'].replace('-', '_')

        # Per-node availability topic
        availability_topic = f'{prefix}/sensor/mesh_node_{node_id}/availability'

        # Base device info
        device = {
            'identifiers': [f'mesh_node_{node_id}'],
            'name': f'Mesh Node {node["name"]}',
            'model': 'OpenWRT Mesh Node',
            'manufacturer': 'Custom',
            'sw_version': 'OpenWRT 24.10.0'
        }

        # Define sensors
        sensors = []

        # Mesh neighbor count
        sensors.append({
            'name': 'Neighbor Count',
            'unique_id': f'mesh_node_{node_id}_neighbor_count',
            'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
            'value_template': '{{ value_json.mesh.count }}',
            'icon': 'mdi:wifi-strength-4',
            'device': device,
            'availability_topic': availability_topic,
            'payload_available': 'online',
            'payload_not_available': 'offline'
        })

        # Best signal strength (max = strongest/closest neighbor)
        sensors.append({
            'name': 'Best Signal',
            'unique_id': f'mesh_node_{node_id}_best_signal',
            'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
            'value_template': '{{ value_json.mesh.signal_max }}',
            'unit_of_measurement': 'dBm',
            'device_class': 'signal_strength',
            'icon': 'mdi:signal',
            'device': device,
            'availability_topic': availability_topic,
            'payload_available': 'online',
            'payload_not_available': 'offline'
        })

        # Client counts per SSID
        for ssid in ['finca', 'iot', 'guest', 'total']:
            sensors.append({
                'name': f'Clients {ssid.capitalize()}',
                'unique_id': f'mesh_node_{node_id}_clients_{ssid}',
                'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
                'value_template': f'{{{{ value_json.clients.{ssid} }}}}',
                'icon': 'mdi:devices',
                'device': device,
                'availability_topic': availability_topic,
                'payload_available': 'online',
                'payload_not_available': 'offline'
            })

        # Uptime
        sensors.append({
            'name': 'Uptime',
            'unique_id': f'mesh_node_{node_id}_uptime',
            'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
            'value_template': '{{ value_json.system.uptime }}',
            'unit_of_measurement': 's',
            'device_class': 'duration',
            'icon': 'mdi:clock-outline',
            'device': device,
            'availability_topic': availability_topic,
            'payload_available': 'online',
            'payload_not_available': 'offline'
        })

        # Load average
        sensors.append({
            'name': 'Load',
            'unique_id': f'mesh_node_{node_id}_load',
            'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
            'value_template': '{{ value_json.system.load_avg }}',
            'icon': 'mdi:chip',
            'device': device,
            'availability_topic': availability_topic,
            'payload_available': 'online',
            'payload_not_available': 'offline'
        })

        # Gateway-specific sensors
        if node.get('type') == 'gateway':
            sensors.extend([
                {
                    'name': 'WAN1 Status',
                    'unique_id': f'mesh_node_{node_id}_wan1_status',
                    'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
                    'value_template': '{{ value_json.gateway.wan1_status }}',
                    'icon': 'mdi:wan',
                    'device': device,
                    'availability_topic': availability_topic,
                    'payload_available': 'online',
                    'payload_not_available': 'offline'
                },
                {
                    'name': 'WAN2 Status',
                    'unique_id': f'mesh_node_{node_id}_wan2_status',
                    'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
                    'value_template': '{{ value_json.gateway.wan2_status }}',
                    'icon': 'mdi:wan',
                    'device': device,
                    'availability_topic': availability_topic,
                    'payload_available': 'online',
                    'payload_not_available': 'offline'
                },
                {
                    'name': 'Active WAN',
                    'unique_id': f'mesh_node_{node_id}_active_wan',
                    'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
                    'value_template': '{{ value_json.gateway.active_wan }}',
                    'icon': 'mdi:router-wireless',
                    'device': device,
                    'availability_topic': availability_topic,
                    'payload_available': 'online',
                    'payload_not_available': 'offline'
                },
                {
                    'name': 'Batman Mode',
                    'unique_id': f'mesh_node_{node_id}_batman_mode',
                    'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
                    'value_template': '{{ value_json.gateway.batman_mode }}',
                    'icon': 'mdi:router-network',
                    'device': device,
                    'availability_topic': availability_topic,
                    'payload_available': 'online',
                    'payload_not_available': 'offline'
                }
            ])

        # Publish discovery configs
        for sensor in sensors:
            config_topic = f'{prefix}/sensor/{sensor["unique_id"]}/config'
            self.mqtt_client.publish(
                config_topic,
                json.dumps(sensor),
                qos=1,
                retain=True
            )

        logger.info(f"Published discovery for {node['name']}")

    def publish_stats(self, stats: Dict[str, Any]):
        """Publish node statistics to MQTT"""
        prefix = self.config['mqtt']['discovery_prefix']
        node_id = stats['name'].replace('-', '_')

        state_topic = f'{prefix}/sensor/mesh_node_{node_id}/state'
        self.mqtt_client.publish(
            state_topic,
            json.dumps(stats),
            qos=0,
            retain=False
        )

    def publish_ghn_discovery(self, device: Dict[str, str]):
        """Publish Home Assistant MQTT Discovery configs for a G.hn device"""
        prefix = self.config['mqtt']['discovery_prefix']
        device_id = device['name'].replace('-', '_')

        # Per-device availability topic
        availability_topic = f'{prefix}/sensor/ghn_{device_id}/availability'

        # Base device info
        device_info = {
            'identifiers': [f'ghn_{device_id}'],
            'name': f'G.hn PLC {device["name"]}',
            'model': 'PG-9182S4',
            'manufacturer': 'MaxLinear',
            'sw_version': 'G.hn PLC Firmware'
        }

        sensors = []

        # Connection count
        sensors.append({
            'name': 'Connected Devices',
            'unique_id': f'ghn_{device_id}_connected_devices',
            'state_topic': f'{prefix}/sensor/ghn_{device_id}/state',
            'value_template': '{{ value_json.connection_count }}',
            'icon': 'mdi:ethernet',
            'device': device_info,
            'availability_topic': availability_topic,
            'payload_available': 'online',
            'payload_not_available': 'offline'
        })

        # Tx Rate sensor for each connection
        for i in range(5):  # Support up to 5 connections
            sensors.append({
                'name': f'Tx Rate {i+1}',
                'unique_id': f'ghn_{device_id}_tx_rate_{i}',
                'state_topic': f'{prefix}/sensor/ghn_{device_id}/state',
                'value_template': f'{{{{ value_json.connections[{i}].tx_mbps if value_json.connections|length > {i} else none }}}}',
                'unit_of_measurement': 'Mbps',
                'device_class': 'data_rate',
                'icon': 'mdi:upload',
                'device': device_info,
                'availability_topic': availability_topic,
                'payload_available': 'online',
                'payload_not_available': 'offline'
            })

        # Rx Rate sensor for each connection
        for i in range(5):
            sensors.append({
                'name': f'Rx Rate {i+1}',
                'unique_id': f'ghn_{device_id}_rx_rate_{i}',
                'state_topic': f'{prefix}/sensor/ghn_{device_id}/state',
                'value_template': f'{{{{ value_json.connections[{i}].rx_mbps if value_json.connections|length > {i} else none }}}}',
                'unit_of_measurement': 'Mbps',
                'device_class': 'data_rate',
                'icon': 'mdi:download',
                'device': device_info,
                'availability_topic': availability_topic,
                'payload_available': 'online',
                'payload_not_available': 'offline'
            })

        # Publish discovery configs
        for sensor in sensors:
            config_topic = f'{prefix}/sensor/{sensor["unique_id"]}/config'
            self.mqtt_client.publish(
                config_topic,
                json.dumps(sensor),
                qos=1,
                retain=True
            )

        logger.info(f"Published G.hn discovery for {device['name']}")

    def publish_ghn_stats(self, stats: Dict[str, Any]):
        """Publish G.hn device statistics to MQTT"""
        prefix = self.config['mqtt']['discovery_prefix']
        device_id = stats['name'].replace('-', '_')

        # Publish availability
        availability_topic = f'{prefix}/sensor/ghn_{device_id}/availability'
        self.mqtt_client.publish(
            availability_topic,
            'online',
            qos=1,
            retain=True
        )

        # Publish state
        state_topic = f'{prefix}/sensor/ghn_{device_id}/state'
        self.mqtt_client.publish(
            state_topic,
            json.dumps(stats),
            qos=0,
            retain=False
        )

    def run(self):
        """Main monitoring loop"""
        logger.info("Starting Mesh Network Monitor")

        # Setup MQTT
        self.setup_mqtt()

        # Publish discovery configs for all nodes
        logger.info("Publishing MQTT discovery configs...")
        for node in self.config['nodes']:
            # Create minimal node dict for discovery
            node_data = {
                'name': node['name'],
                'type': node['type']
            }
            self.publish_discovery(node_data)

        # Publish discovery configs for all G.hn devices
        for ghn_device in self.config.get('ghn_devices', []):
            self.publish_ghn_discovery(ghn_device)

        time.sleep(1)  # Give HA time to process discovery

        # Main polling loop
        poll_interval = self.config['settings']['poll_interval']
        logger.info(f"Starting poll loop (interval: {poll_interval}s)")

        try:
            while True:
                loop_start = time.time()

                # Collect stats from all nodes
                all_stats, online_nodes, offline_nodes = self.collect_all_nodes()

                # Collect G.hn stats
                all_ghn_stats = self.collect_all_ghn_stats()

                # Publish availability for all nodes
                for node_name in online_nodes:
                    self.publish_node_availability(node_name, True)
                for node_name in offline_nodes:
                    self.publish_node_availability(node_name, False)

                # Publish stats for online nodes
                for stats in all_stats:
                    self.publish_stats(stats)

                # Publish G.hn stats
                for ghn_stats in all_ghn_stats:
                    self.publish_ghn_stats(ghn_stats)

                # Calculate sleep time
                elapsed = time.time() - loop_start
                sleep_time = max(0, poll_interval - elapsed)

                logger.info(f"Poll completed in {elapsed:.1f}s ({len(online_nodes)} online, {len(offline_nodes)} offline), sleeping {sleep_time:.1f}s")
                time.sleep(sleep_time)

        except KeyboardInterrupt:
            logger.info("Received shutdown signal")
        except Exception as e:
            logger.error(f"Fatal error: {e}", exc_info=True)
        finally:
            # Publish offline status
            if self.mqtt_client and self.connected:
                self.mqtt_client.publish(
                    self.config['mqtt']['lwt_topic'],
                    'offline',
                    qos=1,
                    retain=True
                )
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()

            logger.info("Monitor stopped")

    def cleanup_old_entities(self):
        """Remove old entities with doubled names from MQTT discovery"""
        logger.info("Cleaning up old entity discovery configs...")

        self.setup_mqtt()
        prefix = self.config['mqtt']['discovery_prefix']

        # Old entity unique_id patterns (with doubled node names)
        nodes = ['gw_office', 'ap_ec54', 'ap_d74c', 'ap_repay_ruffled',
                 'ap_gate', 'ap_repay_surrender', 'ap_dc99']

        metrics = ['neighbor_count', 'best_signal', 'avg_signal',
                   'clients_total', 'clients_finca', 'clients_iot', 'clients_guest',
                   'uptime', 'load']

        gateway_metrics = ['wan1_status', 'wan2_status', 'active_wan', 'batman_mode']

        count = 0
        for node in nodes:
            for metric in metrics:
                # Old format: mesh_node_{node}_{node}_{metric}
                old_unique_id = f'mesh_node_{node}_{node}_{metric}'
                config_topic = f'{prefix}/sensor/{old_unique_id}/config'
                # Publish empty retained message to remove discovery
                self.mqtt_client.publish(config_topic, '', qos=1, retain=True)
                count += 1

            # Gateway-specific old entities
            if node == 'gw_office':
                for metric in gateway_metrics:
                    old_unique_id = f'mesh_node_{node}_{node}_{metric}'
                    config_topic = f'{prefix}/sensor/{old_unique_id}/config'
                    self.mqtt_client.publish(config_topic, '', qos=1, retain=True)
                    count += 1

        # Give MQTT time to process
        time.sleep(2)

        logger.info(f"Removed {count} old entity discovery configs")

        self.mqtt_client.loop_stop()
        self.mqtt_client.disconnect()


def main():
    """Entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='OpenWRT Mesh Network Monitor')
    parser.add_argument('--cleanup', action='store_true',
                        help='Remove old entities with doubled names and exit')
    args = parser.parse_args()

    # Get the absolute path to the script's directory
    script_dir = Path(__file__).parent.resolve()

    # Construct the absolute path to the config file
    config_path = script_dir / 'config.yaml'

    # Check for config file
    if not config_path.exists():
        logger.error(f"{config_path} not found. Copy config.yaml.example and edit it.")
        sys.exit(1)

    try:
        monitor = MeshMonitor(config_path)

        if args.cleanup:
            monitor.cleanup_old_entities()
            logger.info("Cleanup complete. You can now restart the monitor normally.")
        else:
            monitor.run()
    except Exception as e:
        logger.error(f"Failed to start monitor: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
