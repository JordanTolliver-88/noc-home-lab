# NOC Home Lab

A segmented, monitored network built on a Cisco Catalyst 2960 and Ubuntu, run like a NOC shift: VLANs, monitoring, alerting, and documented incident drills. Built alongside CompTIA Network+ (N10-009) study.

## Status
- [x] Phase 1: Baseline and harden the switch
- [ ] Phase 2: Segment the network
- [ ] Phase 3: Core services
- [ ] Phase 4: Monitoring
- [ ] Phase 5: Incident drills

## Hardware
- Cisco WS-C2960-48TT-L, IOS 12.2(55)SE12 (LAN Base k9)
- Ubuntu desktop (router, NAT, DHCP, monitoring)
- Raspberry Pi 4 (DNS, NTP, uptime checks)

## Phase 1
- Baseline config: [configs/sw1-baseline.txt](configs/sw1-baseline.txt)
- Hardening checklist: [docs/hardening-checklist.md](docs/hardening-checklist.md)
