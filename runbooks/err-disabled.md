# Runbook: Port err-disabled

**Use when:** a port-down alert fires and `show interfaces <port> status` shows `err-disabled`.

## 1. Find the reason (SW1)

    show interfaces status err-disabled
    show logging | include ERR_DISABLE|PSECURE|BPDUGUARD

| Reason | Meaning | Before recovering |
|---|---|---|
| `psecure-violation` | Unknown MAC on a port-security port | Find and remove the unauthorized device |
| `bpduguard` | A switch (or loop) was plugged into an access port | Remove the switch / loop |
| `link-flap` | Link bouncing repeatedly | Check or replace the cable and NIC |

## 2. For port security, identify the device

    show port-security interface <port>

- **Last Source Address**: the MAC that caused the violation
- **Sticky MAC**: the device the port expects

Look up the unknown MAC's vendor (first 3 bytes) and find the physical device.

## 3. Remove the cause
Unplug the unauthorized device or reconnect the correct one. **Recovering the port first just causes another violation.**

## 4. Recover the port

    configure terminal
    interface <port>
     shutdown
     no shutdown
     end
    show interfaces <port> status

If the correct device has legitimately changed (new server), clear the old sticky MAC first:

    clear port-security sticky interface <port>

## 5. Verify
- Port `connected` in the correct VLAN; device answers ping; Discord recoveries arrive.
- `write memory` if the sticky MAC changed.

## 6. Record it
Treat port security violations as security events: note the unknown MAC, the time, and where the device was found.

Related: [DRILL-04](../incidents/drill-04-port-security.md) · [port-down runbook](port-down.md)
