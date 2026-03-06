#!/bin/bash
# Security diagnostic script for deb
# Run this to collect system information for security analysis

OUTPUT_DIR="/tmp/security_audit_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "Starting security audit... Output will be saved to $OUTPUT_DIR"

# System info
uname -a > "$OUTPUT_DIR/uname.txt"
uptime >> "$OUTPUT_DIR/uname.txt"
cat /etc/os-release > "$OUTPUT_DIR/os-release.txt"

# Processes
echo "=== Processes ===" > "$OUTPUT_DIR/processes.txt"
ps aux --forest >> "$OUTPUT_DIR/processes.txt"
ps aux | grep -E 'python|perl|ruby|node|php|lua|miner|xmrig' >> "$OUTPUT_DIR/processes.txt"

# Cron jobs
echo "=== Cron ===" > "$OUTPUT_DIR/cron.txt"
crontab -l 2>/dev/null >> "$OUTPUT_DIR/cron.txt"
cat /etc/crontab 2>/dev/null >> "$OUTPUT_DIR/cron.txt"
ls -la /etc/cron.* 2>/dev/null >> "$OUTPUT_DIR/cron.txt"

# Systemd timers
echo "=== Systemd Timers ===" > "$OUTPUT_DIR/systemd_timers.txt"
systemctl list-timers --all 2>/dev/null >> "$OUTPUT_DIR/systemd_timers.txt"

# Services
echo "=== Running Services ===" > "$OUTPUT_DIR/services.txt"
systemctl --type=service --state=running 2>/dev/null >> "$OUTPUT_DIR/services.txt"

# Network
echo "=== Network Connections ===" > "$OUTPUT_DIR/network.txt"
ss -tulpn 2>/dev/null >> "$OUTPUT_DIR/network.txt"
netstat -tulpn 2>/dev/null >> "$OUTPUT_DIR/network.txt"

# Open ports (not localhost)
echo "=== External Ports ===" > "$OUTPUT_DIR/external_ports.txt"
ss -tlnp 2>/dev/null | grep -v '127.0.0.1' >> "$OUTPUT_DIR/external_ports.txt"

# SSH keys
echo "=== SSH Keys ===" > "$OUTPUT_DIR/ssh_keys.txt"
cat ~/.ssh/authorized_keys 2>/dev/null >> "$OUTPUT_DIR/ssh_keys.txt"
cat /root/.ssh/authorized_keys 2>/dev/null >> "$OUTPUT_DIR/ssh_keys.txt"
ls -la /home/*/.ssh/ 2>/dev/null >> "$OUTPUT_DIR/ssh_keys.txt"

# Recent logins
echo "=== Recent Logins ===" > "$OUTPUT_DIR/logins.txt"
last 2>/dev/null >> "$OUTPUT_DIR/logins.txt"

# Temp files
echo "=== Temp Files ===" > "$OUTPUT_DIR/temp_files.txt"
ls -la /tmp/ >> "$OUTPUT_DIR/temp_files.txt"
ls -la /var/tmp/ >> "$OUTPUT_DIR/temp_files.txt"

# Disk usage
echo "=== Disk Usage ===" > "$OUTPUT_DIR/disk.txt"
df -h >> "$OUTPUT_DIR/disk.txt"

# Smokeping config
echo "=== Smokeping Config ===" > "$OUTPUT_DIR/smokeping.txt"
cat /etc/config/smokeping 2>/dev/null >> "$OUTPUT_DIR/smokeping.txt"

# What's listening on port 80
echo "=== Port 80 ===" > "$OUTPUT_DIR/port80.txt"
ss -tlnp | grep ':80' >> "$OUTPUT_DIR/port80.txt"
lsof -i :80 2>/dev/null >> "$OUTPUT_DIR/port80.txt"

# Tar up the results
cd /tmp
tar -czf security_audit.tar.gz $(basename $OUTPUT_DIR)
echo "Audit complete!"
echo "Output saved to: /tmp/security_audit.tar.gz"
echo "To analyze: tar -xzf /tmp/security_audit.tar.gz && ls -la $(basename $OUTPUT_DIR)"
