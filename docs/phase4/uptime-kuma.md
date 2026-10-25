# Uptime Kuma

- Runs in Docker on rpi4 (`louislam/uptime-kuma:2`), web UI on port 3001, data in the `uptime-kuma` volume
- Alerts to the same Discord channel as LibreNMS (webhook kept out of the repo)
- Monitors (60s interval): Pi-hole DNS (A record lookup via 10.10.20.10), Pi-hole admin (HTTP), SW1 (ping), SW1 SSH (TCP 22), LibreNMS web (HTTP 10.10.20.1:8000)
- Runs on a different host than LibreNMS, so it can alert if LibreNMS itself goes down
- Test (2026-10-24): stopped pihole-FTL; Uptime Kuma alerted on DNS while LibreNMS still showed rpi4 uap (service failure vs. device failure)
