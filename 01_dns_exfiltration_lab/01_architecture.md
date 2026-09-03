# 01. Lab Architecture

## Purpose

This file summarizes the systems, VLANs, traffic paths, and monitoring components used in the DNS exfiltration lab.

---

## Systems and Roles

| System | Role |
|---|---|
| Windows 11 Home | Victim workstation / DNS test source |
| Ubuntu Server | BIND9 DNS server |
| Kali Linux | Controlled test system |
| Security Onion | Passive network monitoring |
| Splunk Enterprise | Centralized log search and detection |
| Proxmox VE | Virtual-machine host |
| Cisco switch | VLAN switching and SPAN mirroring |
| Juniper SRX | Routing and firewall enforcement |

---

## Networks

| VLAN | Network | Gateway | Main Systems |
|---:|---|---|---|
| 10 | `172.16.10.0/24` | `172.16.10.1` | Windows victim |
| 66 | `192.168.66.0/24` | `192.168.66.1` | Kali, BIND9 DNS |
| 99 | `172.16.99.0/24` | `172.16.99.1` | Proxmox, Security Onion, Splunk, admin PC |

---

## Important IP Addresses

| System | IP |
|---|---|
| Windows victim | `172.16.10.50` |
| BIND9 DNS server | `192.168.66.53` |
| Proxmox | `172.16.99.20` |
| Security Onion | `172.16.99.30` |
| Admin workstation | `172.16.99.10` |

---

## Main Network Path

```text
Windows 11
172.16.10.50
VLAN 10
      |
      v
Juniper SRX
      |
      v
VLAN 66
      |
      v
BIND9 DNS Server
192.168.66.53
```

The SRX routes traffic between the VLANs and enforces security policies.

---

## Cisco and Proxmox Connections

| Connection | Purpose |
|---|---|
| SRX → Cisco `Gi1/0/1` | VLAN routing path |
| Proxmox `nic0` → Cisco `Gi1/0/27` | Normal VM and management traffic |
| Proxmox `nic1` → Cisco `Gi1/0/28` | SPAN traffic for Security Onion |

---

## Proxmox Bridges

| Bridge | Purpose |
|---|---|
| `vmbr0` | VM and management traffic |
| `vmbr1` | Passive SPAN traffic |

`vmbr1` has no IPv4 address, gateway, or DHCP configuration.

---

## DNS Traffic

Windows sends DNS queries from:

```text
172.16.10.50
```

to:

```text
192.168.66.53
```

using the test zone:

```text
exfil.test
```

Validated names include:

```text
normal.exfil.test
confirmation001.exfil.test
testdata001.exfil.test
sysmon22test.exfil.test
```

Packet capture confirmed both DNS requests and responses.

---

## Security Onion Monitoring

The Cisco switch mirrors traffic through:

```text
Cisco Gi1/0/28
      |
      v
Proxmox nic1
      |
      v
vmbr1
      |
      v
Security Onion
```

Security Onion and Zeek successfully observed and parsed the DNS traffic.

---

## Windows Telemetry

Sysmon is installed on:

```text
172.16.10.50
```

Validated events:

| Event ID | Description |
|---:|---|
| `1` | Process Creation |
| `3` | Network Connection |
| `22` | DNS Query |

The events were also confirmed in Windows Event Viewer.

---

## Remote Administration

The admin workstation uses:

```text
172.16.99.10
```

PowerShell Remoting over WinRM is used to manage the Windows victim.

```text
172.16.99.10
      |
      | TCP/5985
      v
Juniper SRX
      |
      v
172.16.10.50
```

Remote access has been successfully validated.

---

## Detection Data

| Platform | Data |
|---|---|
| BIND9 | DNS queries |
| Sysmon | Process, network, and DNS activity |
| Security Onion | Mirrored network traffic |
| Splunk | Centralized log correlation |

---

## Conclusion

The core lab architecture is operational.

Validated paths include:

```text
Windows -> Juniper -> BIND9
Windows -> Sysmon
Cisco SPAN -> Security Onion
Admin PC -> WinRM -> Windows
```

The next phase is Splunk deployment and centralized log collection.