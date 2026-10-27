# Runbook: DNS outage ("the internet is down")

**Use when:** users say nothing loads, or Uptime Kuma's `Pi-hole DNS` monitor goes down.

## 1. Separate names from connectivity (on any lab client, e.g. rpi4)

    ping -c 2 1.1.1.1
    ping -c 2 google.com

| Result | Meaning |
|---|---|
| IP fails | Not DNS. Network/routing problem: see port-down / trunk-vlan runbooks |
| IP works, name fails | DNS problem. Continue |

## 2. Which DNS server is the client using?

    cat /etc/resolv.conf

Lab clients should use 10.10.20.10 (Pi-hole), handed out by DHCP.

## 3. Upstream or local?

    dig @1.1.1.1 google.com +short
    dig @10.10.20.10 google.com +short

| Upstream | Pi-hole | Meaning |
|---|---|---|
| Works | Fails | Pi-hole is the problem. Step 4 |
| Fails | Fails | Internet/upstream problem. Check NAT on Ubuntu and the home router |
| Works | Works | Client-specific: wrong resolver, stale lease |

Error words: `connection refused` = service not running; `timed out` = nothing answering (host or network down).

## 4. Check Pi-hole (rpi4)

    systemctl status pihole-FTL --no-pager
    sudo ss -ulpn | grep ':53 '
    journalctl -u pihole-FTL -n 30 --no-pager

## 5. Fix

    sudo systemctl start pihole-FTL

If it won't start, read the journal output from step 4 before trying anything else.

## 6. Verify
- `dig @10.10.20.10 google.com +short` returns addresses.
- Uptime Kuma `Pi-hole DNS` and `Pi-hole admin` back up; Discord recovery arrives.

## Known gaps
- Uptime Kuma runs on rpi4 and resolves through Pi-hole, so its Discord alerts may not send while DNS is down.

Related: [DRILL-05](../incidents/drill-05-dns-outage.md)
