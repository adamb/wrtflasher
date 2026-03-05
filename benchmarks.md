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
