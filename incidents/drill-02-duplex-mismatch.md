## Summary
**Drill:** DRILL-02, speed/duplex mismatch · **Severity:** SEV-3 · **Layer:** 1 · **Date:** 2026-10-26

**MTTD:** no automated detection. No alert fired; found by measuring against the performance baseline · **MTTR** (break → fix): 20:04:54 → 20:40:13

SW1 Fa0/1 (rpi4) was hard-set to `speed 100` / `duplex full` while rpi4 stayed on auto-negotiation. With no negotiation from the switch, rpi4 detected the speed but fell back to **half duplex**, as Ethernet requires. The link stayed up, so nothing alerted, but throughput dropped about 24% and CRC errors climbed.

## Timeline (local time)
| Time | Event |
|---|---|
| 20:04:54 | Fault introduced: `speed 100` / `duplex full` on Fa0/1 (switch log: `%SYS-5-CONFIG_I`) |
| — | No alerts in Discord from LibreNMS or Uptime Kuma |
| ~20:30 | Degradation confirmed with iperf3 against the baseline; mismatch found with `show interfaces` and `ethtool` |
| 20:40:13 | Fix applied: `no speed` / `no duplex` (switch log: `%SYS-5-CONFIG_I`) |
| ~20:45 | Verified: 94.1 Mbps, `a-full` / `a-100`, Pi back to full duplex |

Evidence: [switch log](drill-02-evidence.txt) · [iperf3 during fault](drill-02-during.txt) · [iperf3 after fix](drill-02-after.txt)

## 1. Identify the problem
Users would have complained about slow speeds to and from the Pi. Nothing was down, so no alert fired. The only way to confirm it was to measure throughput and compare it to the baseline.

## 2. Theory of probable cause
A Layer 1 problem on rpi4's link (cable, port, or speed/duplex settings), since the device was reachable but slow.

## 3. Test the theory
| Check | Baseline | During fault |
|---|---|---|
| SW1 `show interfaces fa0/1 status` | `a-full` / `a-100` | `full` / `100` (hard-set, no `a-`) |
| rpi4 `ethtool eth0` duplex | Full | **Half** |
| SW1 input errors / CRC | 0 / 0 | **1,630 / 1,623** |
| iperf3 rpi4 → Ubuntu | 94.1 Mbps, 0 retr | **71.8 Mbps, 1,617 retr** |
| iperf3 Ubuntu → rpi4 | 94.1 Mbps, 151 retr | **78.1 Mbps** |

Duplex mismatch signature: CRC and input errors on the full-duplex side (SW1), because the half-duplex side (rpi4) aborts its frames when the switch transmits at the same time. The Pi → Ubuntu direction suffered most because the Pi was the side aborting.

## 4. Plan of action
Return Fa0/1 to auto-negotiation so both sides agree on 100/full.

## 5. Implement the fix
On SW1: `no speed`, `no duplex` on Fa0/1, then `clear counters fa0/1`.

## 6. Verify full functionality and add prevention
- SW1 shows `a-full` / `a-100`; rpi4 `ethtool` shows Full.
- iperf3 rpi4 → Ubuntu: **94.1 Mbps**, matching the baseline.
- CRC counter stayed at 0 after a full-speed test.

Prevention:
- Leave both ends on auto-negotiation, or hard-set **both** ends the same. Never hard-set only one.
- Tune monitoring: the interface-errors rule fires at ≥100 errors/sec averaged over a 5-minute poll, far above this fault's rate. A rule for any sustained CRC errors on access ports would have caught it.
- Keep the performance baseline current. Without it there was nothing to compare "slow" against.

## 7. Document findings and lessons learned
- Not all issues will be alerted. Sometimes they will only be discovered when a user has a problem.
- A degraded link is different from a down link. Up/down monitoring can't see "slow."
- `a-` in `show interfaces status` means negotiated. Its absence on one side of a link is worth checking.

Runbook: [runbooks/slow-link.md](../runbooks/slow-link.md)
