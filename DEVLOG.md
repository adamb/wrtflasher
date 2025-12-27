# Development Log

## 2025-12-27 - Gateway Working

### Completed
- Fixed WiFi radio detection - needed `path` option, solved with uci-defaults script
- Fixed batman-adv mesh attachment - created `/etc/init.d/batman-attach` to run at boot
- Fixed WiFi not broadcasting - needed country code and explicit channels (US, ch6/ch36)
- Gateway fully working:
  - All three SSIDs broadcasting (Finca, IOT, Guest)
  - Batman mesh active (`batctl if` shows phy1-mesh0)
  - All VLANs bridged correctly
  - DHCP working
  - Internet working via WAN

### Manual Configuration Done (not in firmware)
- Installed `luci-proto-batman-adv` (need to add to build.sh)
- Configured wan2 on eth2 for T-Mobile USB ethernet adapter:
### Packages to Add to build.sh
- `luci-proto-batman-adv`
- `kmod-usb-net-rndis` (for USB modems)
- `kmod-usb-net-cdc-ether` (for USB ethernet)
- `mwan3` and `luci-app-mwan3` (for dual-WAN failover)

### Port Mapping Discovered
- **eth0**: LAN (2.5G port) - goes to switch
- **eth1**: WAN (1G port) - Starlink
- **eth2**: USB ethernet adapter - T-Mobile

### Still TODO
- Flash and test GL-MT3000 AP
- Configure Zyxel switch VLANs
- Set up mwan3 failover
- Test mesh connectivity between gateway and AP

### To Recreate This Setup
1. Clone repo
2. Create `.env` with passwords
3. Run `./build.sh`
4. Flash `firmware/openwrt-...-openwrt_one-...-sysupgrade.itb` to gateway
5. Flash `firmware/openwrt-...-glinet_gl-mt3000-...-sysupgrade.bin` to APs
6. Manual: Configure wan2 if using dual-WAN (see commands above)
7. Manual: Configure mwan3 for failover


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

