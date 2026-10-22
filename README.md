# NOC Home Lab

A segmented, monitored network built on a Cisco Catalyst 2960 and Ubuntu, run like a NOC shift: VLANs, routing, core services, monitoring, alerting, and documented incident drills. Built alongside CompTIA Network+ (N10-009) study.

## Topology
![Lab topology](diagrams/topology.drawio.png)

## Status
- [x] Phase 1: Baseline and harden the switch
- [x] Phase 2: Segment the network (VLANs, trunk, Linux routing, NAT, DHCP)
- [x] Phase 3: Core services (DNS, NTP, syslog, config backups)
- [ ] Phase 4: Monitoring and alerting
- [ ] Phase 5: Incident drills
- [ ] Phase 6: Final write-up and walkthrough video

## Hardware
| Device | Role |
|---|---|
| Cisco WS-C2960-48TT-L, IOS 12.2(55)SE12 (LAN Base k9) | Access switch, 802.1Q trunk to the router |
| Ubuntu 26.04 desktop (Lenovo ThinkCentre) | Router-on-a-stick, NAT, DHCP, syslog, TFTP |
| Raspberry Pi 4, Raspberry Pi OS Lite (64-bit) | DNS (Pi-hole), NTP (chrony) |
| USB 3.0 gigabit Ethernet adapter | Ubuntu's trunk port to the switch |

## Network design
The Ubuntu desktop's onboard NIC (`enp1s0`) connects to the home network (`10.0.0.0/24`) for internet access. A USB NIC carries an 802.1Q trunk to the switch's Gi0/1, and Ubuntu routes between the lab VLANs and NATs them out to the internet.

| VLAN | Name | Subnet | Gateway | Purpose |
|---|---|---|---|---|
| 10 | MGMT | 10.10.10.0/24 | 10.10.10.1 | Switch management (SVI 10.10.10.2) |
| 20 | SERVERS | 10.10.20.0/24 | 10.10.20.1 | Raspberry Pi (reserved 10.10.20.10) |
| 30 | USERS | 10.10.30.0/24 | 10.10.30.1 | Test clients (DHCP 10.10.30.100-200) |
| 999 | BLACKHOLE | none | none | Unused ports and trunk native VLAN |

## Services
| Service | Software | Host | Address | Port / Protocol |
|---|---|---|---|---|
| Inter-VLAN routing + NAT | Linux kernel + nftables | Ubuntu | 10.10.x.1 | n/a |
| DHCP | dnsmasq | Ubuntu | VLANs 20, 30 | UDP 67 |
| DNS + ad blocking | Pi-hole | rpi4 | 10.10.20.10 | UDP/TCP 53 |
| Pi-hole admin | Pi-hole web | rpi4 | 10.10.20.10 | TCP 80/443 |
| NTP | chrony | rpi4 | 10.10.20.10 | UDP 123 |
| Syslog collector | rsyslog | Ubuntu | 10.10.10.1 | UDP 514 |
| Config archive | tftpd-hpa | Ubuntu | 10.10.10.1 | UDP 69 |
| Management | SSH v2 | SW1, rpi4 | 10.10.10.2, 10.10.20.10 | TCP 22 |

## Phase 1: Baseline and harden the switch
- Factory reset, console access, SSH v2 only, Telnet and HTTP disabled, local auth with hashed secrets
- Unused ports shut and parked in VLAN 999, DTP disabled, Smart Install (`vstack`) disabled
- Baseline config: [configs/sw1-baseline.txt](configs/sw1-baseline.txt)
- Hardening checklist: [docs/hardening-checklist.md](docs/hardening-checklist.md)

## Phase 2: Segment the network
- VLANs 10/20/30/999, access ports with PortFast and BPDU Guard, Rapid PVST+
- Gi0/1 trunk to Ubuntu with native VLAN 999 (mitigates double-tagging)
- Ubuntu VLAN subinterfaces (netplan), IP forwarding, NAT and a forward-filter rule (nftables), DHCP (dnsmasq)
- Configs: [netplan](configs/ubuntu/60-lab.yaml), [nftables](configs/ubuntu/nftables.conf), [dnsmasq](configs/ubuntu/dnsmasq-lab.conf), [switch running config](configs/sw1-running.txt)
- Proof: [show vlan brief](docs/phase2/show-vlan-brief.txt), [show interfaces trunk](docs/phase2/show-interfaces-trunk.txt)

## Phase 3: Core services
- Pi-hole as lab DNS, handed out through DHCP, answering all lab VLANs
- chrony on the Pi as the lab time source; SW1 synced over NTP with local-time log timestamps
- SW1 logs sent to rsyslog on Ubuntu, one file per device, with log rotation
- Config backups: SW1 pushes its config over TFTP on every save and daily; [a script](scripts/sw1-backup.sh) redacts secrets, filters noise lines, and commits only real changes. Runs nightly from cron.
- Configs: [chrony](configs/rpi4/chrony-lab.conf), [rsyslog](configs/ubuntu/10-lab-network.conf), [logrotate](configs/ubuntu/logrotate-lab-network)
- Proof: [show ntp associations](docs/phase3/show-ntp-associations.txt), [sample switch syslog](docs/phase3/sample-switch-syslog.txt), and the switch config history in this repo's commits

## Incident log
See [shift-log.md](shift-log.md) for incidents worked during the build.

## Skills demonstrated
Cisco IOS switching (VLANs, 802.1Q trunking, STP, port security hardening) · Linux networking (netplan, nftables, IP forwarding, NAT) · DHCP, DNS, NTP, syslog, TFTP · SSH key management · Bash scripting and cron · Git-based configuration management · Structured troubleshooting
