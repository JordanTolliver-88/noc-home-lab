# Performance baseline (2026-10-24)

Path: Ubuntu USB NIC → SW1 Gi0/1 (1 Gbps) → SW1 Fa0/1 (100 Mbps) → rpi4. Bottleneck: Fa0/1.

| Test | Result | Healthy range |
|---|---|---|
| TCP Ubuntu → rpi4 | 94.1 Mbps, 151 retransmits | 93–95 Mbps (some retr expected, see note) |
| TCP rpi4 → Ubuntu | 94.1 Mbps, 0 retransmits | 93–95 Mbps, ~0 retr |
| UDP 90 Mbps | 0% loss, 0.014 ms jitter | 0% loss, < 1 ms jitter |
| Ping rpi4 (LibreNMS / Uptime Kuma) | ~1.6 ms | < 5 ms |

Note: Upload retransmits come from the 1 Gbps → 100 Mbps step-down at SW1 (Gi0/1 in, Fa0/1 out). The switch buffer overflows briefly and TCP backs off; ~0.06% of packets, with full line rate. The download direction has no step-down and shows 0 retransmits. Retransmits in the thousands, or download below ~93 Mbps, would point to a cable, duplex, or port problem.

Raw output: iperf3-tcp-upload.txt, iperf3-tcp-download.txt, iperf3-udp-90m.txt

Not yet tested: true inter-VLAN throughput (VLAN 30 client ↔ rpi4) — needs the test laptop on Fa0/2.
