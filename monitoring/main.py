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

        # Check WAN interfaces status
        wan1_output = self.ssh_command(node_ip, "ip link show eth1 2>/dev/null | grep -q 'state UP' && echo 'up' || echo 'down'")
        stats['wan1_status'] = wan1_output if wan1_output else 'unknown'

        wan2_output = self.ssh_command(node_ip, "ip link show usb0 2>/dev/null | grep -q 'state UP' && echo 'up' || echo 'down'")
        stats['wan2_status'] = wan2_output if wan2_output else 'down'

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

    def collect_all_nodes(self) -> List[Dict[str, Any]]:
        """Collect statistics from all nodes in parallel"""
        all_stats = []

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
                    logger.info(f"Collected stats from {node['name']}")
                except Exception as e:
                    logger.error(f"Failed to collect stats from {node['name']}: {e}")

        return all_stats

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
            'device': device
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
            'device': device
        })

        # Client counts per SSID
        for ssid in ['finca', 'iot', 'guest', 'total']:
            sensors.append({
                'name': f'Clients {ssid.capitalize()}',
                'unique_id': f'mesh_node_{node_id}_clients_{ssid}',
                'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
                'value_template': f'{{{{ value_json.clients.{ssid} }}}}',
                'icon': 'mdi:devices',
                'device': device
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
            'device': device
        })

        # Load average
        sensors.append({
            'name': 'Load',
            'unique_id': f'mesh_node_{node_id}_load',
            'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
            'value_template': '{{ value_json.system.load_avg }}',
            'icon': 'mdi:chip',
            'device': device
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
                    'device': device
                },
                {
                    'name': 'WAN2 Status',
                    'unique_id': f'mesh_node_{node_id}_wan2_status',
                    'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
                    'value_template': '{{ value_json.gateway.wan2_status }}',
                    'icon': 'mdi:wan',
                    'device': device
                },
                {
                    'name': 'Active WAN',
                    'unique_id': f'mesh_node_{node_id}_active_wan',
                    'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
                    'value_template': '{{ value_json.gateway.active_wan }}',
                    'icon': 'mdi:router-wireless',
                    'device': device
                },
                {
                    'name': 'Batman Mode',
                    'unique_id': f'mesh_node_{node_id}_batman_mode',
                    'state_topic': f'{prefix}/sensor/mesh_node_{node_id}/state',
                    'value_template': '{{ value_json.gateway.batman_mode }}',
                    'icon': 'mdi:router-network',
                    'device': device
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

        time.sleep(1)  # Give HA time to process discovery

        # Main polling loop
        poll_interval = self.config['settings']['poll_interval']
        logger.info(f"Starting poll loop (interval: {poll_interval}s)")

        try:
            while True:
                loop_start = time.time()

                # Collect stats from all nodes
                all_stats = self.collect_all_nodes()

                # Publish stats
                for stats in all_stats:
                    self.publish_stats(stats)

                # Calculate sleep time
                elapsed = time.time() - loop_start
                sleep_time = max(0, poll_interval - elapsed)

                logger.info(f"Poll completed in {elapsed:.1f}s, sleeping {sleep_time:.1f}s")
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


def main():
    """Entry point"""
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
        monitor.run()
    except Exception as e:
        logger.error(f"Failed to start monitor: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
