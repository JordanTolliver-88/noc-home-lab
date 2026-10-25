# LibreNMS

- Runs in Docker on Ubuntu from the official librenms/docker compose example (`~/librenms-docker/examples/compose`)
- Web UI on port 8000; syslog-ng and snmptrapd containers not started (rsyslog on Ubuntu owns UDP 514)
- Docker installed with `"ip-forward-no-drop": true` in `/etc/docker/daemon.json` so it doesn't set the FORWARD policy to DROP and break lab routing
- Devices polled over SNMPv3 authPriv (SHA / AES-128) as user `librenms`: SW1 (10.10.10.2), rpi4 (10.10.20.10)
- Container traffic is NATed to Ubuntu's VLAN address, so it passes SW1's SNMP ACL (permit 10.10.10.1)

## Alerting
- Transport: Discord webhook (URL kept out of the repo)
- Operation `Discord - notify`: one notification per alert (steps 1-1); recovery alerts on
- Rules: Devices up/down, Device Down (SNMP unreachable), Port status up/down, Interface errors > 100, ICMP latency abnormally high
- Test (2026-10-24): unplugged rpi4 from SW1 Fa0/1. Discord received "SW1 Port status up/down: FastEthernet0/1" at 22:26:37 and "rpi4 Device Down" at 22:26:42, then recoveries after reconnecting
- Known noise: one outage triggers both device-down rules. To tune in Phase 5
