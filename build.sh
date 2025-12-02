#!/bin/bash
set -e

echo "=== OpenWRT Mesh Firmware Builder ==="
echo ""

# Generate configs
./generate-config.sh

# Build Docker image if needed
echo ""
echo "→ Building Docker image..."
docker build -t openwrt-builder:24.10.0 .

# Create output directory
mkdir -p firmware

# Build gateway firmware
echo ""
echo "→ Building gateway firmware (OpenWRT One)..."
docker run --rm -v $(pwd)/files-gateway:/files -v $(pwd)/firmware:/output openwrt-builder:24.10.0 \
  bash -c "cd /builder/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64 && \
  make image PROFILE='openwrt_one' PACKAGES='kmod-batman-adv batctl-default luci luci-ssl' FILES=/files && \
  cp bin/targets/mediatek/filogic/*sysupgrade* /output/"

# Build AP firmware
echo ""
echo "→ Building AP firmware (GL-MT3000)..."
docker run --rm -v $(pwd)/files-ap:/files -v $(pwd)/firmware:/output openwrt-builder:24.10.0 \
  bash -c "cd /builder/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64 && \
  make image PROFILE='glinet_gl-mt3000' PACKAGES='kmod-batman-adv batctl-default luci luci-ssl' FILES=/files && \
  cp bin/targets/mediatek/filogic/*sysupgrade* /output/"

echo ""
echo "✓ Build complete! Firmware files are in ./firmware/"
