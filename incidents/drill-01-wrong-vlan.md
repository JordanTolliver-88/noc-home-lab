## Summary
**Drill:** DRILL-01, server port in wrong VLAN · **Severity:** SEV-2 · **Layer:** 2 · **Date:** 2026-10-26
**MTTD** (break → first alert): ~3 min (19:01:47 → 19:04:51) · **MTTR** (break → service restored): ~22 min (19:01:47 → 19:24:04)

The planned fault was moving rpi4's port (SW1 Fa0/1) from VLAN 20 to VLAN 30. During the change, `no shutdown` was left off, so the port ended up in the wrong VLAN **and** administratively down. That made it a two-fault incident.

## Timeline (local time)
| Time | Event |
|---|---|
| 19:01:47 | Fault introduced: Fa0/1 moved to VLAN 30 and left shut down (switch log: `%LINK-5-CHANGED ... administratively down`) |
| 19:04:51 | First alert in Discord: LibreNMS `rpi4 Devices up/down` and `rpi4 Device Down (SNMP unreachable)` |
| before 19:20 | Root cause found: `show interfaces fa0/1 status` showed `disabled`, VLAN 30 |
| 19:20:09 | First fix attempt: VLAN corrected to 20, but `shutdown` typed instead of `no shutdown`. Ping still failed |
| 19:24:04 | Port re-enabled with `no shutdown` (switch log: `%LINK-3-UPDOWN ... up`) |
| 19:23:54–19:24:22 | Uptime Kuma delivers recoveries (and its first word of the outage) |
| 19:24:04 | rpi4 back on 10.10.20.10 (DHCP log: `DHCPACK(vlan20) 10.10.20.10 ... rpi4`) |

Raw log evidence: [drill-01-evidence.txt](drill-01-evidence.txt)

## 1. Identify the problem
- rpi4 (10.10.20.10) unreachable. That takes down lab DNS (Pi-hole), NTP, and Uptime Kuma.
- Alerts received: LibreNMS `rpi4 Devices up/down` and `rpi4 Device Down (SNMP unreachable)`, both at 19:04:51.
- Port-down alert for Fa0/1: did not arrive. The rule skips ports that are administratively shut down.
- `ping 10.10.20.10` from Ubuntu returned `Destination Host Unreachable` from 10.10.20.1. The gateway's ARP for the Pi got no reply, which pointed at Layer 1/2 rather than routing.

## 2. Theory of probable cause
The Pi was down, its cable was disconnected, or its switch port was misconfigured.

## 3. Test the theory
On SW1:
- `show interfaces fa0/1 status`: **disabled**, VLAN **30**. `disabled` means administratively shut down, not a cable fault (`notconnect`), so a person made this change.
- `show mac address-table interface fa0/1`: empty. A shut port learns no MACs.
- `show vlan brief`: Fa0/1 listed under VLAN 30 USERS instead of VLAN 20 SERVERS.
- Switch syslog on Ubuntu (`/var/log/network/10.10.10.2.log`) records the config change and the port going down, with timestamps (see evidence file).

## 4. Plan of action
Return Fa0/1 to VLAN 20 and enable it, then confirm the Pi gets its reserved address.

## 5. Implement the fix
1. First attempt: `switchport access vlan 20`, then `shutdown` by mistake. Verification (ping) still failed.
2. Second attempt: `no shutdown`. Port came up in VLAN 20.

## 6. Verify full functionality and add prevention
Verified: Pi got its reserved address 10.10.20.10 via DHCP at 19:24:04; ping to 10.10.20.10 answered; Uptime Kuma recoveries arrived 19:23:54–19:24:22 for Pi-hole DNS (lookups working again), Pi-hole admin, SW1 SSH, and LibreNMS.

Prevention:
- Read each interface change back with `show running-config interface fa0/1` before leaving config mode.
- Treat every fix as unconfirmed until verified. The first fix only worked because I re-tested it.
- Monitoring gap: the "Port status up/down" rule ignores ports that are administratively shut down, so a mistaken `shutdown` only shows up as a downstream device-down alert. Possible improvements: alert on switch config-change syslog messages (`%SYS-5-CONFIG_I`), or alert when critical ports like Fa0/1 and Gi0/1 go admin-down.

## 7. Document findings and lessons learned
- `disabled` vs `notconnect` in `show interfaces status` tells you whether a person or a cable caused a port outage.
- `shutdown` and `no shutdown` are one word apart. Verifying after the fix caught my own mistake.
- Syslog plus config backups answer "what changed and when" quickly.
- Uptime Kuma detected the outage within a minute ("went offline 7:01 PM"), faster than LibreNMS, but it runs on the Pi, which was cut off. Its alerts couldn't reach Discord until the Pi came back, so they arrived as recoveries 22 minutes late. A monitor inside the failure can detect it but can't report it. Placement matters as much as speed.

Runbook: [runbooks/port-down.md](../runbooks/port-down.md)
