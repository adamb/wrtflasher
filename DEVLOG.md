# Development Log
## 2025-12-02 - Configuration System Complete

### Completed
- Created single-source-of-truth config system
- Built `config.sh` with all mesh settings:
  - Mesh ID and encryption
  - Three SSIDs (LAN, IoT, Guest) with 802.11r roaming
  - DHCP settings for gateway
  - Home Assistant IP for firewall exception
- Created `generate-configs.sh` that generates UCI configs:
  - Network config (batman-adv, bridges)
  - Wireless config (mesh + SSIDs)
  - DHCP config (gateway only)
  - Firewall config (network isolation + HA exception)
- Created `build.sh` wrapper script
- Successfully built both firmwares with custom configs:
  - Gateway firmware includes DHCP and firewall
  - AP firmware configured as mesh client
- Added LuCI web interface to builds

### Next Steps
1. Flash and test gateway firmware on OpenWRT One
2. Flash and test AP firmware on GL-MT3000
3. Verify mesh connectivity
4. Test network isolation and HA access to IoT
5. Create README with usage instructions


## 2025-11-18 - Initial Setup

### Completed
- Created git repo structure for OpenWRT mesh firmware builder
- Set up Docker environment with Ubuntu 22.04
- Downloaded OpenWRT ImageBuilder 24.10.0 for mediatek/filogic platform
- Successfully built test firmware with batman-adv packages:
  - `kmod-batman-adv` - kernel module
  - `batctl-default` - control utility
- Built firmware for two device types:
  - OpenWRT One (gateway) - profile: `openwrt_one`
  - GL-MT3000 BerylAX (AP nodes) - profile: `glinet_gl-mt3000`
- Flashed test firmware to BerylAX successfully

### In Progress
- Creating configuration system with single source of truth
- Created skeleton `generate-configs.sh` script
- Need to create `config.sh` with mesh settings

### Issues Found
- Initial builds missing LuCI web interface
- Need to add more packages to builds

### Next Steps
1. Create `config.sh` with mesh configuration (SSIDs, passwords, etc.)
2. Complete `generate-configs.sh` to generate UCI config files
3. Create `build.sh` wrapper script
4. Add LuCI and additional packages to firmware builds
5. Test complete workflow

