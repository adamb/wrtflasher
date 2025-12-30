#!/bin/bash
echo "=== AP TEMPERATURE MONITORING ==="
echo ""
printf "%-15s %10s %12s %12s %10s\n" "Node" "CPU" "2.4GHz" "5GHz Mesh" "Fan RPM"
echo "────────────────────────────────────────────────────────────────"

nodes="192.168.1.1:gw-office 192.168.1.101:ap-central 192.168.1.114:ap-jade 192.168.1.157:ap-casita 192.168.1.167:ap-toilet"

for node in $nodes; do
    ip=$(echo $node | cut -d: -f1)
    name=$(echo $node | cut -d: -f2)
    
    temps=$(ssh -o ConnectTimeout=2 root@$ip "
        cpu=\$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf \"%.1f\", \$1/1000}')
        radio0=\$(cat /sys/class/hwmon/hwmon3/temp1_input 2>/dev/null | awk '{printf \"%.0f\", \$1/1000}')
        radio1=\$(cat /sys/class/hwmon/hwmon4/temp1_input 2>/dev/null | awk '{printf \"%.0f\", \$1/1000}')
        fan=\$(cat /sys/class/hwmon/hwmon2/fan1_input 2>/dev/null)
        echo \"\$cpu|\$radio0|\$radio1|\$fan\"
    " 2>/dev/null)
    
    if [ -n "$temps" ]; then
        cpu=$(echo "$temps" | cut -d'|' -f1)
        radio0=$(echo "$temps" | cut -d'|' -f2)
        radio1=$(echo "$temps" | cut -d'|' -f3)
        fan=$(echo "$temps" | cut -d'|' -f4)
        
        # Check for high temps
        cpu_int=${cpu%.*}
        if [ -n "$cpu_int" ] && [ "$cpu_int" -gt 75 ] 2>/dev/null; then
            status="❌"
        elif [ -n "$cpu_int" ] && [ "$cpu_int" -gt 65 ] 2>/dev/null; then
            status="⚠️ "
        else
            status="✅"
        fi

        printf "%-15s %s %-6s %10s°C %10s°C %9s\n" "$name" "$status" "${cpu}°C" "$radio0" "$radio1" "$fan"
    else
        printf "%-15s %s\n" "$name" "⚠️  offline/error"
    fi
done

echo ""
echo "Temperature Guide:"
echo "  ✅ <65°C: Good"
echo "  ⚠️  65-75°C: Warm (monitor)"
echo "  ❌ >75°C: Hot (check ventilation)"
echo ""
echo "Note: GL-MT3000 has active cooling (fan) and typically runs cool"
