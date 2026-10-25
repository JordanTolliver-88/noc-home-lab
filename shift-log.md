# Shift Log

Incidents and notable events from building and running the lab. Times are local (EDT) and approximate.
Severity: **SEV-1** whole lab down · **SEV-2** a service or segment down · **SEV-3** degraded or single device.

---

## INC-001 · Trunk cabled to an access port
**Date:** 2026-10-21, ~20:26–20:33 · **Severity:** SEV-2 · **Layer:** 1/2

**Symptom:** After building the Ubuntu VLAN interfaces, `ping 10.10.10.2` (switch MGMT SVI) returned `Destination Host Unreachable` from 10.10.10.1. SSH to the switch failed with `No route to host`.

**Investigation:**
- Ubuntu side looked correct: `vlan10/20/30` up with the right addresses, IP forwarding on.
- "Unreachable" from the local gateway meant ARP for 10.10.10.2 got no reply, so the problem was on the switch side.
- `show interfaces trunk`: empty, so no trunk was up.
- `show ip interface brief`: `Vlan10 up/down` and `FastEthernet0/1 up/up`, even though nothing was supposed to be plugged into Fa0/1 yet.

**Root cause:** The cable from Ubuntu's USB NIC was in Fa0/1 (an access port in VLAN 20) instead of Gi0/1 (the trunk). The access port dropped Ubuntu's 802.1Q-tagged frames.

**Fix:** Moved the cable to Gi0/1.

**Verification:** Gi0/1 trunking with VLANs 10,20,30,999 forwarding; Vlan10 up/up; 3 of 4 pings answered (first lost to ARP).

**Prevention:** Label the trunk port; check `show interfaces status` right after recabling.

**Lesson:** A link light only proves the cable works, not that it’s in the right port. When a VLAN interface shows up/down, I now check which physical port is actually carrying that VLAN before I touch any config.

---

## INC-002 · Raspberry Pi first-boot settings not applied
**Date:** 2026-10-22, ~13:41–14:50 · **Severity:** SEV-3 · **Layer:** 7 (provisioning)

**Symptom:** The Pi got a DHCP lease but announced hostname `raspberrypi` instead of `rpi4`, and SSH returned `Connection refused`. No second DHCP request appeared after 10+ minutes, so no first-boot reboot happened.

**Investigation:**
- "Connection refused" (not timeout) meant the host was reachable but nothing listened on port 22, so SSH was never enabled.
- The default hostname meant none of the Imager customization had applied.
- Ubuntu's packaged Raspberry Pi Imager was v1.8.5. The snap version (1.9.6) couldn't load the device list.

**Root cause:** The older Imager wrote customization in a form the current Raspberry Pi OS release didn't apply on first boot.

**Fix:** Reflashed with the current Raspberry Pi Imager (2.x AppImage from raspberrypi.com). Its log confirmed the customization was written and verified.

**Verification:** DHCPACK for 10.10.20.10 with hostname `rpi4`.

**Prevention:** Use the current Imager from the vendor, not the distro package, for new OS releases.

**Lesson:** Connection refused” instead of a timeout told me the Pi was on the network but SSH wasn’t running, which pointed at provisioning, not networking. When a new OS ignores my settings, I check whether the tool that wrote them is current.


---

## INC-003 · Whole lab unreachable: USB NIC disconnected
**Date:** 2026-10-22, ~14:51–15:02 · **Severity:** SEV-1 · **Layer:** 1

**Symptom:** The Pi never appeared in the DHCP log, `ssh sw1` hung with no prompt, and `ping 10.10.10.2` showed 100% loss. Every lab device was unreachable at once.

**Investigation:**
- Several unrelated devices failing together pointed to a shared path: Ubuntu's trunk.
- `ip -br link | grep enx`: no output, so the USB NIC was gone.
- `ip -br addr | grep vlan`: no output, so all three VLAN interfaces were gone with it.

**Root cause:** The USB Ethernet adapter was unplugged from the ThinkCentre while the SD card reader was being connected.

**Fix:** Reconnected the adapter. NetworkManager brought `enx6c6e0755838c` and the three VLAN interfaces back automatically.

**Verification:** Interface UP, VLAN addresses back, switch answering ping, Pi received its DHCP lease.

**Prevention:** Give the trunk adapter a dedicated, labeled USB port. When everything fails at once, check the shared Layer 1 path first.

**Lesson:** When everything fails at the same time, I look for what those things share instead of troubleshooting each one. Here every lab device depended on one USB adapter, and ip -br link found the problem in seconds. Starting at Layer 1 would have saved me ten minutes.


---

## INC-004 · SSH key rejected on the Pi
**Date:** 2026-10-22, ~15:05–15:34 · **Severity:** SEV-3 · **Layer:** 7

**Symptom:** `ssh jordan@10.10.20.10` returned `Permission denied (publickey)`.

**Investigation:**
- `ssh -v` showed both local keys (ed25519 and RSA) were offered and both rejected, so the client side was fine.
- Password login is disabled, so the fix had to happen on the SD card.
- Mounted the card's root partition on Ubuntu (`/dev/sdc2` → `/mnt/rootfs`). Username `jordan` and folder permissions were correct.
- `authorized_keys` was 95 bytes and read `...Z26wCNQjordan@noc-lab`: no space between the key and its comment.

**Root cause:** The public key was corrupted when copy-pasted into Imager. The missing space made the key unparseable.

**Fix:** Overwrote `authorized_keys` directly from `~/.ssh/id_ed25519.pub` with `tee`, then set owner `1000:1000` and mode `600`.

**Verification:** `ssh rpi4` logged in with the key, no password.

**Prevention:** Copy keys from the `.pub` file with commands, not by hand. Check file length and format when a key is rejected.

**Lesson:** ssh -v showed both keys being offered, which proved the client was fine and the problem was on the server. One missing character can break a key, so I copy credentials from files with commands, never by hand.

---

## INC-005 · Switch config archive failing over TFTP
**Date:** 2026-10-22, ~17:09–17:18 · **Severity:** SEV-3 · **Layer:** 7

**Symptom:** `show archive` showed `Error - Bad file number`. A manual `copy running-config tftp://10.10.10.1/sw1-test` failed with `Permission denied`.

**Investigation:**
- The switch reached the server (it got a refusal, not a timeout), so the network path was fine.
- Server config, `--create`, and folder ownership (`tftp:tftp`) all checked out.
- Local test from Ubuntu with `tftp ... put` returned `Error code 2: File must have global write permissions`.
- `/srv/tftp` held 0-byte files: the server created each file, then refused to write to it.

**Root cause:** tftpd-hpa's default (non-permissive) mode only writes to world-writable files. `--umask 022` created files that weren't, so every upload was refused after creation.

**Fix:** Added `--permissive` to `TFTP_OPTIONS`, cleared the 0-byte files, and added an empty-file check to `scripts/sw1-backup.sh` so a failed upload can never overwrite the saved config.

**Verification:** Local test file uploaded at 5 bytes. Switch archive uploads succeeded, and the backup script produced a diff for a test description change.

**Prevention:** Test a service locally before pointing devices at it. Treat 0-byte output as a failure.

**Lesson:** I should test a server on its own before blaming the client. A local tftp put gave me the real error message the switch never showed. A 0-byte file is a failure, so any script that uses these files needs a check for it.

---

## INC-006 · Pi not answering SNMPv3
**Date:** 2026-10-22, ~17:56–18:41 · **Severity:** SEV-3 · **Layer:** 4/7

**Symptom:** `snmpget` to the switch (10.10.10.2) worked, but the same query to the Pi (10.10.20.10) returned `Timeout`.

**Investigation:**
- The first round of snmpd setup had been run at the Ubuntu prompt instead of the Pi. Removed snmpd from Ubuntu and redid it on the Pi.
- `systemctl status snmpd`: running. `ss -ulpn | grep 161`: listening on `127.0.0.1:161` and `[::1]:161` only.
- `sudo grep` on `/etc/snmp/snmpd.conf` showed the untouched Debian default: `agentaddress 127.0.0.1,[::1]` plus v2c `public` communities.
- After fixing the listener, the error changed to `Unknown user name`: the agent answered, but no `librenms` user was loaded. The user file held an old entry with unknown passwords, a line with placeholder text, and a `createUser` command that failed on a missing quote.
- After recreating the user, the error changed to `Authentication failure`: the user existed, but the auth password didn't match what the client sent.

**Root cause:** Two problems stacked. snmpd's default config listens on localhost only, and the SNMPv3 user was created with the wrong or mistyped credentials.

**Fix:** Replaced `snmpd.conf` with a minimal config (`agentaddress udp:161`, `rouser librenms priv`, no v1/v2c communities). Stopped snmpd, deleted every `librenms` entry from `/var/lib/snmp/snmpd.conf`, and recreated the user with the exact passwords already verified against the switch.

**Verification:** `ss` showed `0.0.0.0:161`. `snmpget` over authPriv returned `STRING: "rpi4"`. The `createUser` line was consumed and replaced by a hashed `usmUser` entry.

**Prevention:** Confirm the listening address with `ss` after configuring any service. Verify credentials against a known-working device before copying them to a new one.

**Lesson:** Each new error told me I'd fixed one layer and reached the next. `Timeout` meant nothing was listening, `Unknown user name` meant the agent was reachable but the account was missing, and `Authentication failure` meant the account existed but the password was wrong. Reading the error closely each time told me exactly where to look next.

---

## INC-007 · Monitoring showed every device down
**Date:** 2026-10-24, ~21:25–22:14 · **Severity:** SEV-3 (monitoring only, no real outage) · **Layer:** 7

**Symptom:** LibreNMS's device-down alert rules were firing for both SW1 and rpi4, and a manual poll ended with `All devices were down, unable to poll`. Availability showed 0%.

**Investigation:**
- `ping` from Ubuntu to 10.10.10.2 and 10.10.20.10: both answered, 0% loss. The network was healthy.
- Poll output showed `Hostname: SW1` and `Hostname: rpi4` with a blank `IP:` field.
- From inside the LibreNMS container: `ping 10.10.10.2` answered, `ping SW1` failed with `Try again`. The name couldn't be resolved.

**Root cause:** The friendly names had been entered into each device's Hostname field instead of Display Name. LibreNMS connects by hostname, and nothing in the lab resolves `SW1` or `rpi4`, so every poll failed and both devices were marked down.

**Fix:** Set each Hostname back to its IP (10.10.10.2, 10.10.20.10) and put `SW1` / `rpi4` in Display Name.

**Verification:** A forced poll showed the IPs, ran the full module set, and the device-down rules returned to OK.

**Prevention:** In monitoring tools, keep the connection field (hostname/IP) separate from the label. Adding local DNS records in Pi-hole would also make names resolvable.

**Lesson:** When monitoring says everything is down but the network tests fine, I should suspect the monitoring system itself first. Testing from inside the container showed it could reach the IP but not the name, which pointed straight at a config change I'd made, not a network problem.

---

## Minor issues
- Several commands were typed at the wrong prompt (IOS commands at the Ubuntu prompt and the reverse). Habit: check the prompt (`SW1#` vs `jordan@...$` vs `jordan@rpi4`) before running anything.
- Commands pasted together with `ssh` were swallowed while the session connected (the Pi-hole installer and chrony install didn't run). Habit: run session-opening commands alone, then paste the next step.
- Placeholder values from instructions were typed literally a few times (`AUTHPASS`, `YourAuthPass1`, the Git email). Habit: before pressing Enter, scan the command for words in CAPS or `Your...` and replace them.
