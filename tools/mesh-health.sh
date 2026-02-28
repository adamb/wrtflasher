#!/bin/bash
set -u

echo "=== MESH NETWORK HEALTH REPORT ==="
echo ""
echo "Generated: $(date)"
echo ""

# Build MAC to hostname mapping
MAC_MAP_FILE=$(mktemp)
trap "rm -f $MAC_MAP_FILE" EXIT

NODES=(
  "192.168.1.1:gw-office"
  "192.168.1.101:ap-central"
  "192.168.1.114:ap-jade"
  "192.168.1.125:ap-repay-ruffled"
  "192.168.1.157:ap-casita"
  "192.168.1.159:ap-replay-surrender"
  "192.168.1.117:ap-prov"
  "192.168.1.175:ap-news"
  "192.168.1.197:ap-cust"
)

# Collect MACs from all nodes
echo "Collecting node MAC addresses..."
for node in "${NODES[@]}"; do
  ip="${node%%:*}"
  name="${node##*:}"

  # Get wireless mesh MAC (phy1)
  mac=$(ssh -o ConnectTimeout=2 -o BatchMode=yes root@"$ip" \
    "cat /sys/class/ieee80211/phy1/macaddress 2>/dev/null | tr -d '\n'" 2>/dev/null || true)
  if [ -n "${mac:-}" ]; then
    echo "$mac|$name" >> "$MAC_MAP_FILE"
  fi

  # Get wired interface MAC (eth1) if available - used for wired backhaul
  eth1_mac=$(ssh -o ConnectTimeout=2 -o BatchMode=yes root@"$ip" \
    "cat /sys/class/net/eth1/address 2>/dev/null | tr -d '\n'" 2>/dev/null || true)
  if [ -n "${eth1_mac:-}" ] && [ "$eth1_mac" != "$mac" ]; then
    echo "$eth1_mac|$name" >> "$MAC_MAP_FILE"
  fi
done

# Get batctl originator output to find all nodes in mesh (including unreachable ones)
echo "Querying mesh topology..."
BATCTL_OUTPUT=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@192.168.1.1 \
  "batctl meshif bat0 o 2>/dev/null" 2>/dev/null || true)

# Extract MACs from batctl output and add generic names for unknown ones
# Use process substitution to avoid subshell issues
while read -r mac; do
  [ -z "${mac:-}" ] && continue
  if ! grep -q "^${mac}|" "$MAC_MAP_FILE" 2>/dev/null; then
    # Generate generic name from last 4 hex chars of MAC
    last_octet="${mac##*:}"
    generic_name="ap-${last_octet}"
    echo "$mac|$generic_name" >> "$MAC_MAP_FILE"
  fi
done < <(echo "$BATCTL_OUTPUT" | awk '/^\*/ {print $1}' | sort -u)

mac_to_name() {
  local mac="${1:-}"
  local name
  name=$(grep "^${mac}|" "$MAC_MAP_FILE" 2>/dev/null | head -1 | cut -d'|' -f2 || true)
  if [ -n "${name:-}" ]; then
    echo "$name"
  else
    echo "$mac"
  fi
}

export -f mac_to_name
export MAC_MAP_FILE

# Configurable threshold
GOOD_DBM=-75

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. NEIGHBOR COUNT (Redundancy Check)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Quality threshold: signal avg >= ${GOOD_DBM} dBm (less negative is better)"
echo ""

check_node() {
  local ip=$1
  local name=$2

  local out
  out=$(ssh -o ConnectTimeout=2 -o BatchMode=yes root@"$ip" "
    iw dev phy1-mesh0 station dump 2>/dev/null | awk -v TH=${GOOD_DBM} '
      /^Station/    { total++; mac=\$2 }
      /signal avg:/ { s=\$3; if (s ~ /^-?[0-9]+$/ && s >= TH) good++ }
      END { print (good+0) \" \" (total+0) }
    '
  " 2>/dev/null | tr -d '\r' || true)

  local good total
  good=$(echo "${out:-}" | awk '{print $1}')
  total=$(echo "${out:-}" | awk '{print $2}')

  if [ -z "${good:-}" ] || [ -z "${total:-}" ]; then
    printf "%-20s %-15s %s\n" "$name" "($ip)" "❌ SSH down"
    return
  fi

  local status
  if [ "$good" -ge 3 ]; then
    status="✅ GOOD"
  elif [ "$good" -eq 2 ]; then
    status="⚠️  OK"
  else
    status="❌ WEAK"
  fi

  printf "%-20s %-15s %2d/%-2d good peers  %s\n" "$name" "($ip)" "$good" "$total" "$status"
}

for node in "${NODES[@]}"; do
  ip="${node%%:*}"
  name="${node##*:}"
  check_node "$ip" "$name"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. MESH BACKHAUL SIGNAL STRENGTH (5GHz) — from station dump"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "%-20s → %-24s %10s  %s\n" "From Node" "To Neighbor" "Signal" "Quality"
echo "──────────────────────────────────────────────────────────────────────────────────"

check_signals() {
  local from_ip=$1
  local from_name=$2

  local station_dump
  station_dump=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@"$from_ip" "
    iw dev phy1-mesh0 station dump 2>/dev/null | awk '
      /^Station/    { mac=\$2 }
      /signal avg:/ { print mac \"|\" \$3 }
    '
  " 2>/dev/null || true)

  echo "$station_dump" | while IFS='|' read -r mac signal; do
    [ -z "${mac:-}" ] && continue
    [[ ! "${signal:-}" =~ ^-?[0-9]+$ ]] && continue

    local quality
    if [ "$signal" -ge -60 ]; then
      quality="✅ Excellent"
    elif [ "$signal" -ge -70 ]; then
      quality="✅ Good"
    elif [ "$signal" -ge -80 ]; then
      quality="⚠️  Poor"
    else
      quality="❌ Very Poor"
    fi

    local neighbor_name
    neighbor_name=$(mac_to_name "$mac")
    printf "%-20s → %-24s %8s dBm  %s\n" "$from_name" "$neighbor_name" "$signal" "$quality"
  done
}

for node in "${NODES[@]}"; do
  ip="${node%%:*}"
  name="${node##*:}"
  check_signals "$ip" "$name"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. BATMAN-ADV TOPOLOGY (Best Routes)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "TQ scores: 255 = perfect, 200+ = good, <150 = poor"
echo ""

# Bat topology with MAC to name mapping
# Create sed script to replace all MACs at once
sed_script=""
while IFS='|' read -r mac name; do
  [ -z "${mac:-}" ] && continue
  sed_script="${sed_script}s|${mac}|${name}|g;"
done < "$MAC_MAP_FILE"

# Bat topology sorted by TQ score (descending - highest TQ first)
# Note: batctl output has " *" (space before asterisk) so we grep for " \*"
if [ -n "${BATCTL_OUTPUT:-}" ]; then
  echo "$BATCTL_OUTPUT" | awk '/ \*/' | sed "$sed_script" | sort -t'(' -k2 -rn
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. HEALTH SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

weak=0
for node in "${NODES[@]}"; do
  ip="${node%%:*}"

  good=$(ssh -o ConnectTimeout=2 -o BatchMode=yes root@"$ip" "
    iw dev phy1-mesh0 station dump 2>/dev/null | awk -v TH=${GOOD_DBM} '
      /signal avg:/ { s=\$3; if (s ~ /^-?[0-9]+$/ && s >= TH) good++ }
      END { print good+0 }
    '
  " 2>/dev/null | tr -d ' ' || true)

  if [ -n "${good:-}" ] && [ "$good" -eq 1 ]; then
    weak=$((weak + 1))
  fi
done

if [ "$weak" -eq 0 ]; then
  echo "✅ All nodes have 2+ quality mesh peers (good redundancy)"
else
  echo "⚠️  $weak node(s) have only 1 quality mesh peer (single point of failure)"
fi

echo ""
