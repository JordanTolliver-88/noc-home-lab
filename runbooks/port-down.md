# Runbook: Device unreachable on a switch access port

**Use when:** a device alert fires (LibreNMS "Devices up/down") for something plugged into SW1, or users report a server or client unreachable.

## 1. Confirm it's unreachable
- From Ubuntu: `ping -c 3 <device IP>`
- `Destination Host Unreachable` from the gateway (10.10.x.1) means ARP got no reply, so suspect Layer 1/2.

## 2. Find the port
| Device | Port | VLAN |
|---|---|---|
| rpi4 | Fa0/1 | 20 |
| Test laptop | Fa0/2 | 30 |
| Ubuntu trunk | Gi0/1 | trunk (10,20,30; native 999) |

## 3. Check the port on SW1 (`ssh sw1`)
`show interfaces <port> status`

| Status | Meaning | Next step |
|---|---|---|
| `connected` + wrong VLAN | Misconfiguration | Step 5 |
| `disabled` | Someone shut it down | Step 4, then Step 5 |
| `notconnect` | No link: cable, NIC, or device powered off | Check the cable and device power |
| `err-disabled` | Switch shut it (BPDU Guard, port security) | Follow [err-disabled.md](err-disabled.md) |

Then:
- `show mac address-table interface <port>`: is the device's MAC learned, and in which VLAN?
  - Caution: with sticky port security, the MAC shows as `STATIC` even if the device is off. Check `show interfaces <port> | include packets input` twice and confirm the count rises, or check `ip neigh` on Ubuntu.
- `show vlan brief`: is the port listed under the correct VLAN?


**If the port is connected, in the correct VLAN, and the device's MAC is learned, the access side is fine. Check the trunk next: [trunk-vlan.md](trunk-vlan.md).**

## 4. Find what changed
- `sudo grep CONFIG_I /var/log/network/10.10.10.2.log | tail -5` (who changed config, when, from where)
- `sudo grep "<port>" /var/log/network/10.10.10.2.log | tail -5` (when the port went down or up)
- `git log -p -3 -- configs/sw1-running.txt` (the exact config lines that changed, from nightly backups)

## 5. Fix
Run on SW1:

    configure terminal
    interface <port>
     switchport access vlan <correct VLAN>
     no shutdown
     end
    show running-config interface <port>

Read the interface config back before leaving. `shutdown` and `no shutdown` are one word apart.

## 6. Verify
- `show interfaces <port> status` shows `connected` in the correct VLAN.
- `ping` the device answers.
- For DHCP devices: `sudo journalctl -u dnsmasq --since "10 min ago" | grep DHCPACK` shows the expected address.
- LibreNMS and Uptime Kuma recover; the Discord recoveries arrive.

## 7. Close out
- `write memory` only if the running config is now the intended config.
- Write up the ticket and a shift-log line.

## Known gaps
- The port-down alert ignores admin-shut ports. A mistaken `shutdown` only shows as a device-down alert.
- Uptime Kuma runs on rpi4. If rpi4 is cut off, its alerts arrive late.

Related: [DRILL-01](../incidents/drill-01-wrong-vlan.md)
