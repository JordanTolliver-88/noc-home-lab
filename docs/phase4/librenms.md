# LibreNMS

- Runs in Docker on Ubuntu from the official librenms/docker compose example (`~/librenms-docker/examples/compose`)
- Web UI on port 8000; syslog-ng and snmptrapd containers not started (rsyslog on Ubuntu owns UDP 514)
- Docker installed with `"ip-forward-no-drop": true` in `/etc/docker/daemon.json` so it doesn't set the FORWARD policy to DROP and break lab routing
- Devices polled over SNMPv3 authPriv (SHA / AES-128) as user `librenms`: SW1 (10.10.10.2), rpi4 (10.10.20.10)
- Container traffic is NATed to Ubuntu's VLAN address, so it passes SW1's SNMP ACL (permit 10.10.10.1)
