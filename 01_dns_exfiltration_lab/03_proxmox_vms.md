# 03 â€” Proxmox Virtual Machines

## What Is This File For?

This file records the virtual machines used by the DNS lab.

| VMID | Name | Purpose | Memory | Disk | Status |
|---:|---|---|---:|---:|---|
| 900 | `SecOnion` | Network monitoring | 24 GB | 250 GB | Existing |
| 901 | `DNS-SRV-01` | Ubuntu BIND9 DNS server | 2 GB | 32 GB | Planned |
| 902 | `SPLUNK-SRV-01` | Splunk Enterprise | 8 GB | 100 GB | Planned |
| 903 | `WIN11-VICTIM-01` | Windows victim | 6 GB | To be selected | Planned |

All new VM disks should use `ext-ssd`.

For each VM, record:

1. The creation settings.
2. The network bridge and VLAN.
3. The operating-system installation.
4. The final IP address.
5. The validation result.