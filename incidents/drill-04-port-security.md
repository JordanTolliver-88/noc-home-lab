## Summary
**Drill:** DRILL-04, port security violation · **Severity:** SEV-2 · **Layer:** Security (L2) · **Date:** 2026-10-26

**MTTD** (violation → first alert): 24 sec (21:55:24 → 21:55:48) · **MTTR** (violation → port restored): ~7 min (21:55:24 → 22:02:11) (includes a planned 3-minute wait for the intruder MAC to be removed)

Port security (sticky MAC, maximum 1, violation shutdown) was enabled on SW1 Fa0/1, learning rpi4's MAC `98fe.5463.e885`. To simulate an unauthorized device, rpi4 temporarily changed its MAC to `02:00:00:00:00:01`. SW1 saw the unknown MAC, logged a violation, and put Fa0/1 in err-disabled, cutting rpi4 off until the port was manually recovered.

## Timeline (local time)
| Time | Event |
|---|---|
| before 21:55 | Port security enabled on Fa0/1; sticky MAC learned for rpi4 |
| 21:55:24 | Violation: unknown MAC `0200.0000.0001` on Fa0/1, port err-disabled (switch log: `%PORT_SECURITY-2-PSECURE_VIOLATION` / `%PM-4-ERR_DISABLE`) |
| 21:55:48 | First alert in Discord: LibreNMS `SW1 Port status up/down` (FastEthernet0/1) |
| 21:56:22 | LibreNMS `rpi4 Devices up/down` and `rpi4 Device Down (SNMP unreachable)` |
| ~21:58 | rpi4 restores its real MAC (3-minute timer) |
| 22:02:11 | Fa0/1 recovered with `shutdown` / `no shutdown`, link up |
| 22:02:20 | Uptime Kuma recoveries arrive, reporting services "offline since 21:56" |

Evidence: [switch log](drill-04-evidence.txt)

## 1. Identify the problem
Alerts received: port down, device down, and SNMP unreachable for rpi4. Unlike DRILL-01, the port-down alert fired, and it arrived first, pointing straight at SW1 Fa0/1.

## 2. Theory of probable cause
Fa0/1 went down without anyone shutting it, so either the link failed or the switch disabled the port itself (port security or BPDU Guard).

## 3. Test the theory
On SW1:
- `show interfaces fa0/1 status`: **err-disabled**. The switch shut the port, not a person (`disabled`) or a cable (`notconnect`).
- `show interfaces status err-disabled`: reason **psecure-violation**.
- `show port-security interface fa0/1`: Last Source Address **0200.0000.0001**, Security Violation Count **1**.
- Switch syslog on Ubuntu: `PSECURE_VIOLATION` and `ERR_DISABLE` messages with timestamps.

## 4. Plan of action
Remove the unauthorized device first (here, rpi4 restoring its real MAC). Then recover the port. Re-enabling a port while the intruder is still connected just triggers another violation.

## 5. Implement the fix
After rpi4's real MAC was back: `shutdown` / `no shutdown` on Fa0/1.

## 6. Verify full functionality and add prevention
- `show interfaces fa0/1 status`: connected, VLAN 20.
- `ping 10.10.20.10` answered; LibreNMS and Uptime Kuma recovered in Discord.
- Port security kept enabled and saved with `write memory` as permanent hardening for the server port.

Prevention / follow-ups:
- Keep port security on server and critical access ports.
- Optional: `errdisable recovery cause psecure-violation` to auto-recover after a timeout. Trade-off: if the intruder is still connected, the port keeps flapping, so manual recovery is safer for security events.
- Add a LibreNMS alert on `PSECURE_VIOLATION` syslog messages, so security events are flagged as security, not just as port down.

## 7. Document findings and lessons learned
- The port-down alert only fires when the port is supposed to be up, not when it is administratively down. In DRILL-01 a person shut the port and it stayed quiet; here the switch err-disabled it and it fired first.
- `show interfaces` is a good command to show a port's status. `disabled`, `notconnect`, and `err-disabled` each point to a different cause: a person, a cable, or the switch itself.
- Remove the cause before re-enabling an err-disabled port.

Runbook: [runbooks/err-disabled.md](../runbooks/err-disabled.md)
