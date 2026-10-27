## Summary
**Drill:** DRILL-03, VLAN pruned from trunk · **Severity:** SEV-2 · **Layer:** 2 · **Date:** 2026-10-26

**MTTD** (break → first alert): ~1 min (21:18:32 → 21:19:28) · **MTTR** (break → fix): ~7 min (21:18:32 → 21:25:44)

VLAN 20 was removed from the allowed list on SW1 Gi0/1, the 802.1Q trunk to the Ubuntu router. rpi4's own port stayed healthy, but VLAN 20 traffic could no longer reach its gateway, so rpi4 (and lab DNS, NTP, and Uptime Kuma) went dark. The switch itself (VLAN 10) stayed reachable.

## Timeline (local time)
| Time | Event |
|---|---|
| 21:18:32 | Fault introduced: `switchport trunk allowed vlan remove 20` on Gi0/1 (switch log: `%SYS-5-CONFIG_I`) |
| 21:19:28 | Alerts in Discord: LibreNMS `rpi4 Devices up/down` and `rpi4 Device Down (SNMP unreachable)` |
| before 21:25:44 | Root cause found: `show interfaces trunk` showed VLAN 20 missing from the allowed list |
| 21:25:44 | Fix applied: `switchport trunk allowed vlan add 20` (switch log: `%SYS-5-CONFIG_I`) |
| 21:26:14 | LibreNMS recoveries for rpi4 in Discord |
| 21:26 | Verified: ping to 10.10.20.10 answered, ARP resolved, VLAN 20 forwarding on the trunk |

Evidence: [switch log](drill-03-evidence.txt)

## 1. Identify the problem
Alerts received: rpi4 device down and SNMP unreachable for rpi4. The switch was still reachable, so the outage was limited to rpi4's VLAN.

## 2. Theory of probable cause
rpi4 was down, its port or cable had failed, or something on the path between rpi4 and its gateway (10.10.20.1 on Ubuntu) was broken.

## 3. Test the theory
- `ping 10.10.20.10` from Ubuntu: `Destination Host Unreachable` from 10.10.20.1.
- `ip neigh show dev vlan20` on Ubuntu: `10.10.20.10 FAILED`. Ubuntu's ARP requests for the Pi got no reply.
- SW1 `show interfaces fa0/1 status`: connected, VLAN 20. The Pi's port looked healthy.
- SW1 `show mac address-table interface fa0/1`: the Pi's MAC learned in VLAN 20. The Pi was up and sending.
- SW1 `show interfaces trunk`: Gi0/1 allowed VLANs **10,30,999**. VLAN 20 missing.
- Switch syslog: `%SYS-5-CONFIG_I` at 21:18:32 showed when the trunk was changed and from where.

## 4. Plan of action
Add VLAN 20 back to the trunk's allowed list without disturbing the other VLANs (use `add`, not a bare `allowed vlan` list).

## 5. Implement the fix
On SW1: `interface gi0/1` → `switchport trunk allowed vlan add 20`.

## 6. Verify full functionality and add prevention
- `show interfaces trunk`: allowed and forwarding VLANs 10,20,30,999. Immediately after the fix, VLAN 20 was allowed but not yet in the spanning-tree forwarding list; it appeared seconds later.
- `ping 10.10.20.10` answered (~1.5 ms); `ip neigh` showed the Pi's MAC `98:fe:54:63:e8:85`.

Prevention:
- Always use `add` / `remove` when editing trunk allowed lists. A bare `switchport trunk allowed vlan <list>` replaces the whole list and can cut management access.
- Read `show interfaces trunk` back after any trunk change.
- Add a trunk check to the device-unreachable runbook: when an access port looks healthy, the problem may be further up the path.

## 7. Document findings and lessons learned
- When a device seems down or unreachable, first verify with a ping, then follow the whole path from the device to its gateway (access port, trunk, gateway), not just the device's own port. Here the Pi's port looked perfect; the problem was VLAN 20 missing from the trunk.
- A MAC address learned on the access port proves the device is alive and sending. If its gateway still can't reach it, the break is between the switch and the gateway.
- ARP (`ip neigh`) on the gateway is a quick Layer 2 test: `FAILED` means the gateway's requests aren't reaching the device.
- Uptime Kuma, running on rpi4, reported SW1, SW1 SSH, and LibreNMS as offline from 21:18–21:19. They never went down; rpi4 was the isolated one. A monitor inside the outage sees everything else as down, so its alerts can point at the wrong devices.

Runbook: [runbooks/trunk-vlan.md](../runbooks/trunk-vlan.md)
