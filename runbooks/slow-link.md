# Runbook: Device reachable but slow

**Use when:** users report slowness to or from a device that is up and pinging, and no device-down alert has fired.

## 1. Measure, don't guess
Compare against the baseline in `docs/phase4/baseline.md` (rpi4 ↔ Ubuntu: ~94 Mbps).

    # on the target (rpi4)
    iperf3 -s
    # on Ubuntu, both directions
    iperf3 -c <target IP> -t 20 -R
    iperf3 -c <target IP> -t 20

Throughput well under baseline, or retransmits in the hundreds or thousands, confirms a real problem.

## 2. Check the switch port (SW1)

    show interfaces <port> status
    show interfaces <port> | include duplex|errors|CRC|collision|runts

| Finding | Likely cause |
|---|---|
| Duplex/speed without `a-` (e.g. `full`, `100`) | Hard-set on the switch. Check the other end |
| CRC / input errors climbing on the switch | Duplex mismatch (if the far end is half) or a bad cable |
| Late collisions | This side is half duplex in a mismatch |
| Speed 10 or half duplex on both sides | Auto-negotiation problem or a damaged cable |

## 3. Check the device end

    ethtool eth0 | grep -E "Speed|Duplex|Auto-negotiation"

Half duplex here while the switch shows full = **duplex mismatch**.

## 4. Fix
- Mismatch: put both ends on auto (`no speed`, `no duplex` on SW1), or hard-set both ends identically.
- Errors with matching settings: replace the cable, then try a different port.

## 5. Verify
- `clear counters <port>`, rerun iperf3, confirm baseline throughput and 0 CRC.
- Note before/after numbers in the ticket.

## Known gaps
- The interface-errors alert (≥100/sec) does not catch a moderate mismatch. Slowness may only surface through user reports.

Related: [DRILL-02](../incidents/drill-02-duplex-mismatch.md)
