#!/bin/bash
set -e  # Exit on error

# Source the user's config
source config.sh

echo "=== Generating OpenWRT mesh configurations ==="
echo ""

# Clean up old generated configs
rm -rf files-gateway files-ap
mkdir -p files-gateway files-ap

echo "→ Generating gateway configuration..."
# TODO: Generate gateway UCI files

echo "→ Generating AP configuration..."
# TODO: Generate AP UCI files

echo ""
echo "✓ Configuration generation complete!"