## Summary
**Drill:** DRILL-06, port down (cable pulled) · **Severity:** SEV-2 · **Layer:** 1 · **Date:** 2026-10-27

**MTTD** (cable pulled → first alert): 15:56:06 → 15:56:52 · **MTTR** (cable pulled → link restored): 15:56:06 → 16:05:48

rpi4's cable was unplugged from SW1 Fa0/1. Worked entirely from [runbooks/port-down.md](../runbooks/port-down.md) to test whether the runbook holds up on its own.

## Timeline (local time)
| Time | Event |
|---|---|
| 15:56:06 | Fault introduced: cable unplugged (switch log: `%LINK-3-UPDOWN ... FastEthernet0/1, changed state to down`) |
| 15:56:52 | First alert in Discord: LibreNMS `SW1 Port status up/down` (FastEthernet0/1) |
| 16:00:24 | LibreNMS `rpi4 Devices up/down` and `rpi4 Device Down (SNMP unreachable)` |
| — | Root cause found with `show interfaces fa0/1 status`: `notconnect` |
| 16:05:48 | Cable reconnected, link up (switch log) |
| 16:05:53 | Uptime Kuma recoveries for SW1 and Pi-hole DNS ("went offline 3:56 PM") |

Evidence: [switch log](drill-06-evidence.txt)

## 1. Identify the problem
Alerts received: SW1 port status up/down for FastEthernet0/1 at 15:56:52, then rpi4 device down and SNMP unreachable at 16:00:24. The port alert arrived first and pointed straight at Fa0/1.

## 2. Theory of probable cause
Fa0/1 down without a config change: a cable, NIC, or power problem on rpi4's link.

## 3. Test the theory
Following the port-down runbook:
- `ping 10.10.20.10` from Ubuntu failed.
- Runbook table: rpi4 is on Fa0/1, VLAN 20.
- `show interfaces fa0/1 status`: **notconnect**. No link at all, which points to the cable or the device, not a configuration change (`disabled`) or a switch protection feature (`err-disabled`).
- Switch syslog: link down on Fa0/1 with no `CONFIG_I` before it, confirming no one changed the config.

## 4. Plan of action
Check the physical cable and rpi4's power.

## 5. Implement the fix
Reconnected rpi4's Ethernet cable to Fa0/1.

## 6. Verify full functionality and add prevention
- Fa0/1 link up; LibreNMS and Uptime Kuma recovered.
- Runbook validation: port-down.md was followed start to finish without changes needed.

Prevention:
- Label critical cables and ports (rpi4 on Fa0/1, trunk on Gi0/1) so they aren't moved by mistake.

## 7. Document findings and lessons learned
- Status `notconnect` is what told me the problem. Across the drills, the three statuses each pointed to a different cause: `disabled` = a person shut it (DRILL-01), `err-disabled` = the switch shut it (DRILL-04), `notconnect` = no physical link (DRILL-06).
- Port alerts arrive before device alerts and say *where* to look.
- Uptime Kuma on rpi4 reported Pi-hole DNS down even though Pi-hole kept running: without a link, rpi4 lost its own address. Monitors inside an outage report symptoms, not causes.
- The runbook worked when followed cold, with no changes needed.

Runbook: [runbooks/port-down.md](../runbooks/port-down.md)
