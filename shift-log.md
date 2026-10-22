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

## Minor issues
- Several commands were typed at the wrong prompt (IOS commands at the Ubuntu prompt and the reverse). Habit: check the prompt (`SW1#` vs `jordan@...$` vs `jordan@rpi4`) before running anything.
- Commands pasted together with `ssh` were swallowed while the session connected (the Pi-hole installer and chrony install didn't run). Habit: run session-opening commands alone, then paste the next step.
