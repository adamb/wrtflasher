#!/bin/bash
# Mesh benchmark - measures latency and throughput to all nodes
# Run with: ./mesh-benchmark.sh [label]

LABEL="${1:-test}"
GW="192.168.1.1"
OUTFILE="benchmark-${LABEL}-$(date +%Y%m%d-%H%M%S).txt"

NAMES="ap-prov ap-news ap-central ap-jade ap-cust ap-ruffled ap-surrender"
MACS="94:83:c4:7f:bb:ec 94:83:c4:7f:a1:44 94:83:c4:72:ec:54 94:83:c4:72:d7:4c 94:83:c4:7f:bd:44 94:83:c4:7f:c5:cc 94:83:c4:7f:c5:ec"
IPLIST="192.168.1.117 192.168.1.175 192.168.1.101 192.168.1.114 192.168.1.197 192.168.1.125 192.168.1.159"

echo "=== Mesh Benchmark: $LABEL ===" | tee "$OUTFILE"
echo "Date: $(date)" | tee -a "$OUTFILE"
echo "" | tee -a "$OUTFILE"

echo "--- Routing Table ---" | tee -a "$OUTFILE"
ssh -o ConnectTimeout=5 root@$GW "batctl meshif bat0 originators | grep '^\s\*'" 2>/dev/null | tee -a "$OUTFILE"
echo "" | tee -a "$OUTFILE"

echo "--- Wired Neighbors ---" | tee -a "$OUTFILE"
ssh -o ConnectTimeout=5 root@$GW "batctl meshif bat0 n | grep eth0.99" 2>/dev/null | tee -a "$OUTFILE"
echo "" | tee -a "$OUTFILE"

i=1
for name in $NAMES; do
  mac=$(echo $MACS | cut -d' ' -f$i)
  ip=$(echo $IPLIST | cut -d' ' -f$i)
  i=$((i + 1))

  echo "--- $name ($ip) ---" | tee -a "$OUTFILE"

  echo -n "  Latency: " | tee -a "$OUTFILE"
  latency=$(ssh -o ConnectTimeout=5 root@$GW "ping -c 10 $ip 2>&1 | tail -1" 2>/dev/null)
  echo "$latency" | tee -a "$OUTFILE"

  echo -n "  Throughput: " | tee -a "$OUTFILE"
  tp=$(ssh -o ConnectTimeout=5 root@$GW "batctl meshif bat0 tp $mac 2>&1 | tail -1" 2>/dev/null)
  echo "$tp" | tee -a "$OUTFILE"

  echo "" | tee -a "$OUTFILE"
done

echo "=== Done ===" | tee -a "$OUTFILE"
echo "Results saved to $OUTFILE"
