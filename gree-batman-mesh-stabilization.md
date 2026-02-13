# Stabilizing Gree AC Units on OpenWrt + batman-adv Mesh

This plan stabilizes **Gree+ AC units (legacy 2.4GHz IoT)** inside a
**batman-adv mesh** running in high-attenuation concrete construction.

------------------------------------------------------------------------

## Infrastructure Overview

-   **Mesh Protocol:** batman-adv (BATMAN_IV)
-   **Environment:** Multi-hop mesh inside reinforced concrete
-   **Target Devices:** Gree+ AC (legacy 2.4GHz Wi-Fi modules, typically
    ESP8266-class)

------------------------------------------------------------------------

# I. Network Architecture Rationale

## 1. Physical Layer --- The "Two-Lane" Strategy

Concrete = heavy attenuation + multipath reflection.

### Radio 0 --- 2.4GHz

-   Optimized for stability + penetration
-   Dedicated to IoT + long-range clients
-   Must support legacy protocols

### Radio 1 --- 5GHz

-   Optimized for performance
-   Handles:
    -   Dedicated mesh backhaul
    -   Phones/laptops/high-speed clients

------------------------------------------------------------------------

## 2. Protocol Layer --- The Compatibility Barrier

Legacy IoT chips: - Often fail on Wi-Fi 6 (HE) - Crash or refuse
association with PMF (802.11w)

### Fix

Downgrade IoT SSID to: - Wi-Fi 4 (HT20) - WPA2-PSK - PMF disabled

This ensures clean hardware-level association.

------------------------------------------------------------------------

## 3. DHCP / Mesh Latency Conflict

Mesh jitter + overhead → IoT misses DHCP renewal window → device drops.

### Fix

-   Use Static IP
-   Set Infinite DHCP lease

Eliminates renewal handshake and prevents periodic dropouts.

------------------------------------------------------------------------

# II. Recommended Settings

## Radio 0 (2.4GHz) --- IoT & Range

  -----------------------------------------------------------------------------
  Setting                     Recommended Value                Why
  --------------------------- -------------------------------- ----------------
  HT Mode                     HT20                             Best
                                                               compatibility,
                                                               more resilient
                                                               than 40MHz or HE

  Encryption                  psk2 (WPA2-PSK)                  Required for IoT
                                                               compatibility

  PMF (802.11w)               0 (Disabled)                     Mandatory. Gree
                                                               modules fail if
                                                               enabled

  DTIM Interval               1                                Prevents AC
                                                               sleep mode
                                                               timing out mesh

  Legacy Rates                Enabled                          Allows lowest,
                                                               most robust
                                                               bitrates
  -----------------------------------------------------------------------------

------------------------------------------------------------------------

## Radio 1 (5GHz) --- Mesh & High-Speed Clients

  ------------------------------------------------------------------------
  Setting                 Recommended Value                   Why
  ----------------------- ----------------------------------- ------------
  HT Mode                 HE80 (Wi-Fi 6)                      High-speed
                                                              backhaul

  SSID                    Finca                               Move modern
                                                              clients here

  Encryption              sae-mixed                           WPA3 for
                                                              modern
                                                              devices +
                                                              WPA2
                                                              fallback
  ------------------------------------------------------------------------

------------------------------------------------------------------------

## Batman-adv Optimizations

  Parameter       Setting   Why
  --------------- --------- ---------------------------------------
  Hop Penalty     60        Stabilizes routing in concrete
  Fragmentation   1         Helps packets survive wall corruption
  DAT             1         Mesh-wide ARP cache for slow IoT
  GW Mode         client    Ensures APs maintain path to gateway

------------------------------------------------------------------------

# III. Operational Gotchas

## The "Zombie" State

If a Gree unit loses IP or SSID association, it may lock up internally.

### Fix

-   10-minute breaker power cycle
-   Must fully discharge internal capacitors

------------------------------------------------------------------------

## Path Flapping

Run:

    batctl o

If TQ \< 160: - Relocate node physically (doorway \> interior wall)

Low TQ = soft drops in Gree+ app.

------------------------------------------------------------------------

## SSID Pinning

If multiple nodes are visible: - Use MAC filtering - Pin AC to AP in its
room - Prevent unnecessary roaming

------------------------------------------------------------------------

# Next Deployment Step

1.  Verify PMF (802.11w) disabled on IoT SSID across all nodes.
2.  Perform simultaneous 10-minute breaker reset on all problematic AC
    units.
