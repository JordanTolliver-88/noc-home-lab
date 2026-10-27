## Summary
**Drill:** DRILL-05, DNS outage · **Severity:** SEV-2 · **Layer:** 7 · **Date:** 2026-10-27

**MTTD** (break → detected): ~1 min (15:37:58 → 15:38:55, Uptime Kuma) · **MTTR** (break → restored): ~6 min (15:37:58 → 15:43:37)

Pi-hole (`pihole-FTL`) on rpi4 was stopped. Every lab client uses it for DNS, so pings to IP addresses still worked but every name lookup failed: the classic "the internet is down" ticket.

## Timeline (local time)
| Time | Event |
|---|---|
| 15:37:58 | Fault introduced: `pihole-FTL` stopped on rpi4 (journal: `Stopped pihole-FTL.service`) |
| 15:38:55 | Uptime Kuma `Pi-hole DNS` down: `queryA ECONNREFUSED google.com` |
| ~15:41 | Root cause found: upstream DNS worked, local resolver not running |
| 15:43:37 | Fix applied: `pihole-FTL` started (journal: `Started pihole-FTL.service`) |
| 15:43:55 | Uptime Kuma `Pi-hole DNS` up; `ping google.com` and `dig @10.10.20.10` working |

Evidence: [pihole-FTL journal](drill-05-evidence.txt)

## 1. Identify the problem
Users would report "the internet is down." LibreNMS stayed quiet, since rpi4 was still up and answering SNMP. Uptime Kuma recorded the failure at 15:38:55, but its alert did not reach Discord. Uptime Kuma runs on rpi4, which uses Pi-hole for DNS; with Pi-hole down it could not look up discord.com to send the alert.

## 2. Theory of probable cause
Either the internet connection, the lab network, the upstream DNS servers, or the local DNS server (Pi-hole).

## 3. Test the theory
Bottom-up on rpi4 (itself a Pi-hole client):
- `ping 1.1.1.1`: works. The network and internet path are fine.
- `ping google.com`: fails. Only names are broken.
- `cat /etc/resolv.conf`: clients ask 10.10.20.10 (Pi-hole).
- `dig @1.1.1.1 google.com`: works. Upstream DNS is fine.
- `dig google.com` (via Pi-hole): fails.
- `systemctl status pihole-FTL`: inactive (dead); nothing listening on port 53.

## 4. Plan of action
Start Pi-hole, then confirm lookups work from a client.

## 5. Implement the fix
`sudo systemctl start pihole-FTL` on rpi4.

## 6. Verify full functionality and add prevention
- `ping google.com` from rpi4 resolved and answered.
- `dig @10.10.20.10 google.com +short` returned addresses.
- Uptime Kuma `Pi-hole DNS` back up at 15:43:55.

Prevention:
- Hand out a **second DNS server** through DHCP so clients can still resolve names if Pi-hole fails (trade-off: those lookups bypass ad blocking).
- Give rpi4 itself a fallback resolver, so Uptime Kuma can still reach Discord when Pi-hole is down.
- systemd can restart `pihole-FTL` automatically if it crashes (`Restart=on-failure`); a manual stop like this one would still need a person.

## 7. Document findings and lessons learned
- Work bottom-up and rule things out: it was not the internet, the network, or the upstream resolver. Ruling those out pointed straight at the local DNS service and made it faster to find and fix.
- DNS is a dependency of the alerting itself. The monitor detected the outage within a minute but couldn't report it, because sending to Discord needs a DNS lookup through the server that was down.
- `ECONNREFUSED` means the host is up but the service isn't running. `ETIMEOUT` means nothing answered at all. The error word points to the layer.

Runbook: [runbooks/dns-outage.md](../runbooks/dns-outage.md)
