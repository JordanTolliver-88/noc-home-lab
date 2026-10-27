# Runbook: VLAN missing or blocked on a trunk

**Use when:** devices in one VLAN are unreachable while other VLANs (including switch management) still work, and the devices' access ports look healthy.

## 1. Confirm the pattern
- `ping` a device in the affected VLAN and one in another VLAN. Only one VLAN failing points at the trunk or the gateway, not one device.
- On Ubuntu: `ip neigh show dev vlan<ID>`. `FAILED` / `INCOMPLETE` means ARP isn't crossing the trunk.

## 2. Check the access side (rules it out quickly)

    show interfaces <access port> status
    show mac address-table interface <access port>

Connected, correct VLAN, and the device's MAC learned = the device and its port are fine. Move up the path.

## 3. Check the trunk (SW1 Gi0/1)

    show interfaces trunk

Read all four sections for the VLAN in question:

| Section | If the VLAN is missing |
|---|---|
| Vlans allowed on trunk | Removed from the allowed list. Fix in step 5 |
| Allowed and active in management domain | VLAN doesn't exist on the switch (`show vlan brief`) |
| Spanning tree forwarding state | Blocked or still converging. Wait a few seconds, then `show spanning-tree vlan <ID>` |

Also confirm the native VLAN is 999 and the status is `trunking`.

## 4. Check the gateway side (Ubuntu)

    ip -br addr | grep vlan
    ip -br link | grep enx

The VLAN interface must be UP with its 10.10.x.1 address, and the USB NIC must be present and UP.

## 5. Fix
On SW1:

    configure terminal
    interface gi0/1
     switchport trunk allowed vlan add <ID>
     end
    show interfaces trunk

**Never** use `switchport trunk allowed vlan <ID>` without `add` or `remove`. It replaces the whole list and can drop VLAN 10 (management) and your SSH session. If that happens, recover through the console cable.

## 6. Verify
- `show interfaces trunk` lists the VLAN in all four sections.
- `ping` the affected devices; `ip neigh` shows their MACs.
- Discord recoveries arrive.

## 7. Find what changed
- `sudo grep CONFIG_I /var/log/network/10.10.10.2.log | tail -5`
- `git log -p -3 -- configs/sw1-running.txt`

Related: [DRILL-03](../incidents/drill-03-trunk-pruned.md) · [port-down runbook](port-down.md)
