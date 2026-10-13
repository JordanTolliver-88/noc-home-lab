# SW1 Hardening Checklist (Phase 1)

| Control | Command(s) | Why |
|---|---|---|
| SSH v2 only | `ip ssh version 2`, `transport input ssh` | Encrypted management; Telnet sends credentials in clear text |
| HTTP/HTTPS server off | `no ip http server`, `no ip http secure-server` | Removes an unneeded management surface |
| Local auth, hashed secrets | `username admin privilege 15 secret`, `enable secret` | No shared plain-text passwords |
| Password obfuscation | `service password-encryption` | Hides any type 0 passwords in the config |
| Session timeouts | `exec-timeout 15 0` on con and vty | Idle sessions don't stay open |
| Unused ports shut | `shutdown` on Fa0/1-48, Gi0/2 | No live ports for unauthorized devices |
| Black-hole VLAN | `switchport access vlan 999` | Unused ports sit in a VLAN with no gateway |
| DTP disabled | `switchport mode access`, `switchport nonegotiate` | Prevents trunk negotiation / VLAN hopping |
| VLAN 1 SVI shut | `interface vlan 1` / `shutdown` | Management moves to VLAN 10 |
| Smart Install off | `no vstack` | Mitigates CVE-2018-0171 (TCP 4786) |
| Login banner | `banner motd` | Legal notice for unauthorized access |
| No DNS lookups on typos | `no ip domain-lookup` | Operational: no CLI hangs |
