# 02 â€” Network Changes

## What Is This File For?

This file records every network change made specifically for the DNS lab.

---

## Proxmox Change â€” September 2, 2026

### Why Was It Needed?

The Windows victim needs VLAN 10. Proxmox `vmbr0` therefore needs VLAN awareness.

### Change Made

The following lines were added to the `vmbr0` section of `/etc/network/interfaces`:

```text
bridge-vlan-aware yes
bridge-vids 10 99
```

### How It Was Tested

- `ifreload -a -n` completed without an error.
- `ifreload -a` completed successfully.
- Proxmox remained available at `172.16.99.20`.
- The gateway `172.16.99.1` replied with 0% packet loss.
- `bridge vlan show` confirmed VLANs 10 and 99 on `nic0`.

### Backup

The previous configuration was saved as:

```text
/root/interfaces.before-dns-lab-2026-09-02
```

---

## Cisco Validation

| Item | Verified setting |
|---|---|
| Gi1/0/27 | Proxmox trunk |
| Native VLAN | 99 |
| Gi1/0/28 | Security Onion SPAN destination |
| SPAN source | Gi1/0/27, both directions |
| SPAN encapsulation | Replicate |

---

## Next Network Change

VLAN 66 must be added to `vmbr0` before the Ubuntu DNS-server VM is connected.

Record the exact command and test result here after completing that change.