# Mesh Benchmarks

## Test Setup

All tests run from gateway (192.168.1.1) using `batctl meshif bat0 tp` for throughput and `ping -c 10` / `ping -c 5` for latency. Each throughput test runs for ~10 seconds.

**Nodes:**
| AP | IP | Location |
|----|-----|----------|
| ap-prov | 192.168.1.117 | Bedroom |
| ap-news | 192.168.1.175 | Tesla room |
| ap-central | 192.168.1.101 | Living room |
| ap-jade | 192.168.1.114 | Gate |
| ap-cust | 192.168.1.197 | Jade bedroom |
| ap-ruffled | 192.168.1.125 | Porche |
| ap-surrender | 192.168.1.159 | Carport |

## 2026-03-04: G.hn Adapter Count Comparison

### Context

Testing whether 3 G.hn powerline adapters sharing the same circuit degrades performance vs 2 adapters. G.hn is half-duplex on powerline so all adapters share bandwidth.

- **3-G.hn**: ghn-gw (office), ghn-prov (bedroom), ghn-news (Tesla room)
- **2-G.hn**: ghn-gw (office), ghn-prov (bedroom) — ghn-news physically unplugged

Hop penalties: gw=15, prov/news=60, all others=30.

### G.hn Phy Rates

| Config | ghn-prov Phy Tx/Rx | ghn-news Phy Tx/Rx |
|--------|-------------------|-------------------|
| 3-G.hn | 12/2 Mbps | 68/60 Mbps |
| 2-G.hn | 28/89 Mbps | unplugged |

### Throughput (Mbps)

| AP | Route (3-G.hn) | 3-G.hn | Route (2-G.hn) | 2-G.hn (run 1) | 2-G.hn (run 2) |
|----|---------------|--------|---------------|----------------|----------------|
| ap-prov | G.hn wired | 3.0 | G.hn wired | 6.8 | 0.9 |
| ap-news | G.hn wired | 4.8 | WiFi direct | **23.6** | **26.1** |
| ap-central | WiFi direct | 3.6 | WiFi direct | **54.4** | **39.7** |
| ap-jade | WiFi direct | 7.0 | WiFi direct | 1.2 | **29.5** |
| ap-cust | WiFi direct | 23.9 | WiFi direct | 3.7 | 3.8 |
| ap-ruffled | G.hn via prov | 22.9 | G.hn via prov | 8.3 | 7.2 |
| ap-surrender | WiFi direct | 32.4 | WiFi direct | 22.7 | 20.6 |

### Latency from Gateway (avg ms)

| AP | 3-G.hn | 2-G.hn (run 1) | 2-G.hn (run 2) |
|----|--------|----------------|----------------|
| ap-prov | 4.5 | 4.5 | 4.6 |
| ap-news | 14.6 | 5.1 | 11.8 |
| ap-central | 27.4 | 4.4 | 30.4 |
| ap-jade | 11.5 | 30.0* | 3.4 |
| ap-cust | 6.6 | 34.2* | 3.8 |
| ap-ruffled | 18.0 | 33.3* | 4.5 |
| ap-surrender | 8.2 | 6.6 | 3.2 |

*Run 1 latency was affected by batman reconvergence after removing ghn-news.

### Observations

1. **Three G.hn adapters severely degraded the powerline network.** ghn-prov dropped from 28/89 Mbps phy (2 adapters) to 12/2 Mbps (3 adapters). The third adapter consumed most of the shared bandwidth.

2. **WiFi-only nodes were also affected.** ap-central went from 3.6 Mbps (3-G.hn) to 39-54 Mbps (2-G.hn). The degraded G.hn link was somehow dragging down the whole mesh — likely because batman was routing some traffic through the slow G.hn paths, causing congestion.

3. **ap-news performs better on WiFi than G.hn.** With its own G.hn adapter it got 4.8 Mbps; on WiFi direct it gets 23-26 Mbps. The G.hn adapter was counterproductive for this node.

4. **ap-prov throughput is inconsistent.** Ranged from 0.9 to 6.8 Mbps across 2-G.hn runs. The G.hn link to prov may have poor powerline signal quality (different circuit or noise source).

5. **Batman reconvergence takes 1-2 minutes** after topology changes. First run after removing ghn-news showed high latency spikes (270+ ms) that resolved by the second run.

### Conclusion

Two G.hn adapters (gw + prov) is better than three. The third adapter at ap-news should remain unplugged. ap-news gets better throughput over WiFi, and removing the third adapter improves ghn-prov's phy rates from 12/2 to 28/89 Mbps.

---

## 2026-03-04: G.hn Link Performance Update

### Context

After running the 2-G.hn comparison, the mesh has been stable for ~10 minutes. The G.hn link between gw-office and ap-prov showed improved phy rates (26/48 Mbps from UI), prompting another benchmark to verify stable performance.

**Current G.hn Configuration:**
- ghn-gw (office): GPL 2000S4 at switch port 8
- ghn-prov (bedroom): GPL 2000S4 at ap-prov eth1.99
- ghn-news unplugged (ap-news uses WiFi backhaul)

**Hop Penalties:** gw=15, prov=news=60, all others=30

### G.hn Phy Rates

| Adapter | Phy Tx | Phy Rx | Location |
|---------|--------|--------|----------|
| ghn-gw | 26 Mbps | 48 Mbps | Office (switch) |
| ghn-prov | 28 Mbps | 89 Mbps | Bedroom (previously reported) |

### Throughput (Mbps)

| AP | Route | Current (23:01) | 2-G.hn (run 1) | 2-G.hn (run 2) | Trend |
|----|-------|-----------------|----------------|----------------|-------|
| ap-prov | G.hn wired | **12.5** | 6.8 | 0.9 | ✅ Stable |
| ap-news | WiFi direct | **27.0** | **23.6** | **26.1** | ✅ Stable |
| ap-central | WiFi direct | **73.9** | 54.4 | 39.7 | ✅ Improved |
| ap-jade | WiFi direct | **24.0** | 1.2 | 29.5 | ⚠️ Variable |
| ap-cust | WiFi direct | **12.9** | 3.7 | 3.8 | ⚠️ Dropped |
| ap-ruffled | G.hn via prov | **20.2** | 8.3 | 7.2 | ✅ Stable |
| ap-surrender | WiFi direct | **10.2** | 22.7 | 20.6 | ⚠️ Dropped |

### Latency from Gateway (avg ms)

| AP | Current (23:01) | 2-G.hn (run 1) | 2-G.hn (run 2) | Trend |
|----|-----------------|----------------|----------------|-------|
| ap-prov | **3.7** | 4.5 | 4.6 | ✅ Improved |
| ap-news | **8.0** | 5.1 | 11.8 | ⚠️ Variable |
| ap-central | **4.5** | 4.4 | 30.4 | ✅ Stable |
| ap-jade | **11.5** | 30.0* | 3.4 | ⚠️ Variable |
| ap-cust | **4.2** | 34.2* | 3.8 | ⚠️ Dropped |
| ap-ruffled | **19.4** | 33.3* | 4.5 | ⚠️ Increased |
| ap-surrender | **29.9** | 6.6 | 3.2 | ⚠️ Increased |

*Run 1 latency was affected by batman reconvergence after removing ghn-news.

### Observations

1. **G.hn link stability improved.** ap-prov now shows consistent 12.5 Mbps throughput and 3.7ms latency - a significant improvement from the 0.9-6.8 Mbps range in earlier 2-G.hn tests.

2. **ap-news is now faster via WiFi than G.hn.** With phy rates at 26/48 Mbps, the G.hn link should theoretically support ~20+ Mbps, but WiFi direct is delivering 27 Mbps consistently. The G.hn adapter is counterproductive for ap-news.

3. **ap-cust and ap-surrender performance dropped.** Both nodes are now routing through ap-prov's G.hn link (eth0.99) but showing lower throughput. ap-surrender's latency also increased significantly (avg 29.9ms vs 3-7ms before), suggesting degraded WiFi path from ap-prov to ap-surrender.

4. **Mesh is adapting to topology.** The routing table shows ap-ruffled (c5:cc) and ap-surrender (c5:ec) both using eth0.99 (ap-prov's G.hn link) as their next hop. This is suboptimal for ap-surrender which had direct WiFi to gateway.

5. **WiFi backhaul remains inconsistent.** Nodes without G.hn adapters (ap-central, ap-jade, ap-cust, ap-surrender) show variable performance based on signal quality and current mesh routes.

### Recommendations

1. **Monitor ap-surrender and ap-ruffled.** These nodes show degraded performance when routing through ap-prov's G.hn link. Check their 5GHz signal strength to ap-prov.

2. **Consider G.hn adapter for ap-news.** The phy rates (68/60 Mbps) suggest the G.hn link to ap-news is healthy when running solo. The unplugged state may be forcing suboptimal mesh routing.

3. **Check for electrical noise.** The variation in ap-prov's G.hn phy rates (12/2 → 28/89 → 26/48) suggests changing powerline conditions. Ensure G.hn adapters are on the same circuit without noise sources (UPS, surge protectors).

---

## 2026-03-04: Mesh Topology Analysis

### Context

Investigating why ap-surrender and ap-ruffled are routing through ap-prov's G.hn link instead of direct WiFi paths, despite having WiFi connections to the gateway.

### 5GHz Mesh Signal Strength (dBm)

#### From Gateway (192.168.1.1)

| Node | MAC | Signal Avg | Quality |
|------|-----|------------|---------|
| ap-cust | 94:83:c4:7f:bd:44 | -85 dBm | ❌ Poor |
| ap-central | 94:83:c4:72:ec:54 | -66 dBm | ✅ Good |
| ap-news | 94:83:c4:7f:a1:44 | -76 dBm | ⚠️ Moderate |
| ap-jade | 94:83:c4:72:d7:4c | -71 dBm | ⚠️ Moderate |
| ap-surrender | 94:83:c4:7f:c5:ec | -91 dBm | ❌ Very Poor |
| ap-prov | 94:83:c4:7f:bb:ec | -93 dBm | ❌ Very Poor |

#### From ap-prov (Bedroom)

| Node | MAC | Signal Avg | Quality |
|------|-----|------------|---------|
| Gateway | 20:05:b7:01:5e:a9 | -96 dBm | ❌ Very Poor |
| ap-central | 94:83:c4:72:ec:54 | -73 dBm | ⚠️ Moderate |
| ap-ruffled | 94:83:c4:7f:c5:cc | -72 dBm | ⚠️ Moderate |
| ap-surrender | 94:83:c4:7f:c5:ec | -74 dBm | ⚠️ Moderate |
| ap-jade | 94:83:c4:72:d7:4c | -95 dBm | ❌ Very Poor |
| ap-news | 94:83:c4:7f:a1:44 | -96 dBm | ❌ Very Poor |

#### From ap-central (Living Room)

| Node | MAC | Signal Avg | Quality |
|------|-----|------------|---------|
| ap-prov | 94:83:c4:7f:bb:ec | -74 dBm | ⚠️ Moderate |
| Gateway | 20:05:b7:01:5e:a9 | -74 dBm | ⚠️ Moderate |
| ap-ruffled | 94:83:c4:7f:c5:cc | -90 dBm | ❌ Very Poor |
| ap-news | 94:83:c4:7f:a1:44 | -88 dBm | ❌ Very Poor |
| ap-surrender | 94:83:c4:7f:c5:ec | **-61 dBm** | ✅ Excellent |
| ap-jade | 94:83:c4:72:d7:4c | -80 dBm | ⚠️ Moderate |
| ap-cust | 94:83:c4:7f:bd:44 | -65 dBm | ✅ Good |

### Analysis

**Why ap-surrender routes through G.hn:**

ap-surrender has a direct WiFi connection to ap-central with excellent signal (-61 dBm, 258 Mbps RX bitrate), but its connection to the **gateway** is very poor (-91 dBm). The mesh routing algorithm chooses the path with the best combined TQ scores:

| Path | Gateway → Next Hop | Next Hop → Dest | Combined TQ |
|------|-------------------|-----------------|-------------|
| Direct WiFi | -91 dBm (poor) | - | Not used |
| Via ap-prov (G.hn) | 255 TQ (eth0.99) | -74 dBm (moderate) | Better |

**Key findings:**

1. **ap-prov has poor bidirectional signal to gateway** (-93 dBm from gw, -96 dBm from ap-prov). The 255 TQ on eth0.99 is because the wired G.hn link is excellent, not WiFi.

2. **ap-surrender and ap-ruffled have poor signal to gateway** but reasonable signal to ap-prov, making the G.hn path more reliable.

3. **Mesh is correctly optimizing** - It's using the best available path even if it means taking an extra hop. The G.hn link (255 TQ) is more reliable than the direct WiFi to gateway for these nodes.

4. **WiFi backhaul is inconsistent** - Nodes on WiFi only (ap-central, ap-jade, ap-cust) show variable performance based on their signal quality to neighbors.

### Recommendations

1. **The current routing is optimal** given the signal conditions. Moving ap-surrender or ap-ruffled physically closer to the gateway would improve direct WiFi performance.

2. **Consider relocating ap-prov** - Its poor signal to the gateway (-93 dBm) may be due to distance or obstacles. Better signal would allow it to contribute more to the mesh.

3. **Check for physical obstructions** between ap-prov and gateway - The -93 dBm signal suggests significant interference or distance.

---

## 2026-03-04: G.hn Link Green - Performance After Link Stabilization

### Context

The G.hn adapter light on ghn-prov turned green (powerline link established). Re-ran benchmark to check if performance improved after the link stabilized.

### G.hn Phy Rates (from UI)

| Adapter | Phy Tx | Phy Rx | Status |
|---------|--------|--------|--------|
| ghn-gw | 26 Mbps | 48 Mbps | Green |
| ghn-prov | ~20-25 Mbps | ~45-50 Mbps | Green |

### Throughput (Mbps)

| AP | Route | Green Light | Previous (23:01) | 2-G.hn (run 1) | Trend |
|----|-------|-------------|------------------|----------------|-------|
| ap-prov | G.hn wired | **7.2** | 12.5 | 6.8 | ⚠️ Dropped |
| ap-news | WiFi direct | **58.7** | 27.0 | **23.6** | ✅ Improved |
| ap-central | WiFi direct | **70.2** | 73.9 | 54.4 | Stable |
| ap-jade | WiFi direct | **18.9** | 24.0 | 1.2 | ⚠️ Dropped |
| ap-cust | WiFi direct | **21.8** | 12.9 | 3.7 | ✅ Improved |
| ap-ruffled | G.hn via prov | **4.2** | 20.2 | 8.3 | ❌ Dropped |
| ap-surrender | G.hn via prov | **5.2** | 10.2 | 22.7 | ❌ Dropped |

### Latency from Gateway (avg ms)

| AP | Green Light | Previous (23:01) | 2-G.hn (run 1) | Trend |
|----|-------------|------------------|----------------|-------|
| ap-prov | **3.9** | 3.7 | 4.5 | Stable |
| ap-news | **13.8** | 8.0 | 5.1 | ⚠️ Increased |
| ap-central | **28.3** | 4.5 | 4.4 | ⚠️ Increased |
| ap-jade | **2.7** | 11.5 | 30.0* | ✅ Improved |
| ap-cust | **28.4** | 4.2 | 34.2* | ⚠️ Increased |
| ap-ruffled | **6.6** | 19.4 | 33.3* | ⚠️ Increased |
| ap-surrender | **1470** | 29.9 | 6.6 | ❌ Degraded |

*Run 1 latency was affected by batman reconvergence after removing ghn-news.

### Observations

1. **G.hn link going green did NOT improve performance as expected.** ap-prov throughput dropped from 12.5 to 7.2 Mbps despite the link stabilizing.

2. **ap-surrender is extremely slow (5.2 Mbps, 1470ms avg latency).** This node is routing through ap-prov's G.hn link but the path is highly degraded. The batman TQ score to ap-prov is 180 (down from 201 earlier), suggesting signal issues.

3. **ap-news performance improved significantly (58.7 Mbps).** WiFi direct is now outperforming the G.hn link for this node.

4. **ap-ruffled throughput dropped 79%.** The G.hn path through ap-prov is no longer reliable - ap-ruffled may need to re-benchmark after ap-prov's G.hn issues are resolved.

5. **ap-jade improved significantly (18.9 Mbps, 2.7ms latency).** Best performance since the 2-G.hn tests. May have found a better WiFi path.

### Potential Issues

1. **G.hn powerline interference** - The adapters may be on a circuit with variable electrical load (refrigerator, HVAC, etc.) causing intermittent performance.

2. **Multiple G.hn adapters sharing bandwidth** - Even with ghn-news unplugged, there are still 2 adapters sharing the powerline medium (half-duplex).

3. **ap-prov signal degradation** - The TQ to ap-prov dropped from 255 to 180 for ap-surrender, suggesting the G.hn link quality is inconsistent.

### Recommendations

1. **Check the electrical circuit** for ap-prov's G.hn adapter - is it plugged into a power strip with other devices?

2. **Try a different outlet** for ghn-prov if possible - powerline performance can vary significantly between outlets.

3. **Consider unplugging ghn-gw temporarily** to test if WiFi-only routing is more stable.

4. **Monitor the G.hn phy rates over time** - the UI shows 26/48 but actual throughput may be lower due to powerline noise.
