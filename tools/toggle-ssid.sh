#!/bin/bash

# Script to enable or disable SSIDs across all mesh nodes

if [ $# -ne 2 ]; then
    echo "=== Current SSID Status ==="
    echo ""

    # Get current SSID status from gateway
    ssh -o ConnectTimeout=2 root@192.168.1.1 "
        for iface in lan0 iot0 guest0 eero_main eero_guest; do
            ssid=\$(uci get wireless.\$iface.ssid 2>/dev/null)
            disabled=\$(uci get wireless.\$iface.disabled 2>/dev/null)

            if [ -n \"\$ssid\" ]; then
                if [ \"\$disabled\" = \"1\" ]; then
                    status=\"❌ Disabled\"
                else
                    status=\"✅ Enabled \"
                fi
                printf \"%-12s %-25s %s\n\" \"\$iface\" \"\$ssid\" \"\$status\"
            fi
        done
    " 2>/dev/null

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Usage: $0 <interface> <enable|disable>"
    echo ""
    echo "Examples:"
    echo "  $0 eero_guest disable    # Disable 'FincaDelMar Guest'"
    echo "  $0 eero_main disable     # Disable 'FincaDelMar'"
    echo "  $0 eero_guest enable     # Re-enable 'FincaDelMar Guest'"
    echo ""
    echo "Note: Changes apply to ALL mesh nodes (gateway + APs)"
    exit 1
fi

INTERFACE=$1
ACTION=$2

# Validate action
if [ "$ACTION" != "enable" ] && [ "$ACTION" != "disable" ]; then
    echo "Error: Action must be 'enable' or 'disable'"
    exit 1
fi

# Set the disabled value
if [ "$ACTION" = "disable" ]; then
    DISABLED_VALUE="1"
    ACTION_MSG="Disabling"
else
    DISABLED_VALUE="0"
    ACTION_MSG="Enabling"
fi

echo "=== $ACTION_MSG SSID on all nodes ==="
echo ""

# Get SSID name from one node to show what we're changing
SSID_NAME=$(ssh -o ConnectTimeout=2 root@192.168.1.1 "uci get wireless.$INTERFACE.ssid 2>/dev/null" 2>/dev/null)

if [ -z "$SSID_NAME" ]; then
    echo "Error: Interface '$INTERFACE' not found"
    echo "Run without arguments to see available interfaces"
    exit 1
fi

echo "Interface: $INTERFACE"
echo "SSID Name: $SSID_NAME"
echo "Action: $ACTION"
echo ""
read -p "Apply this change to all nodes? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Applying changes..."
echo ""

# Apply to all nodes
./mesh-exec.sh "
    uci set wireless.$INTERFACE.disabled='$DISABLED_VALUE' && \
    uci commit wireless && \
    echo '$ACTION_MSG $SSID_NAME'
" 2>/dev/null | grep -E "→|$ACTION_MSG|Success"

echo ""
echo "Reloading WiFi on all nodes..."
echo ""

# Reload WiFi
./mesh-exec.sh "wifi reload && echo 'WiFi reloaded'" 2>/dev/null | grep -E "→|reloaded|Success"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Done!"
echo ""
echo "The '$SSID_NAME' SSID has been ${ACTION}d on all nodes."
echo ""
echo "To verify, check active SSIDs with:"
echo "  ./mesh-exec.sh \"uci show wireless | grep -E 'ssid=|disabled='\""
