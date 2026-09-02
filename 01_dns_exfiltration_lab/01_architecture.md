# 01. Lab Architecture

## What Is Architecture?

Architecture is a simple map of the systems, networks, and connections used by the lab.

---

## Systems and Roles

| System | Role |
|---|---|
| Windows 11 | Victim computer |
| Ubuntu Server | Dedicated BIND9 DNS server |
| Kali Linux | Controlled testing computer |
| Security Onion | Network monitoring platform |
| Splunk Enterprise | Log searching and detection platform |
| Proxmox | Virtual-machine host |
| Cisco switch | Network connection and traffic copying |
| Juniper SRX | Routing and firewall control |

---

## Networks

| VLAN | Network | Gateway | Main systems |
|---:|---|---|---|
| 10 | `172.16.10.0/24` | `172.16.10.1` | Windows 11 |
| 66 | `192.168.66.0/24` | `192.168.66.1` | Kali and Ubuntu DNS server |
| 99 | `172.16.99.0/24` | `172.16.99.1` | Proxmox, Security Onion, and Splunk |

---

## Important Connections

| Connection | Purpose |
|---|---|
| Juniper SRX to Cisco Gi1/0/1 | Routes traffic between VLANs |
| Proxmox `nic0` to Cisco Gi1/0/27 | Carries normal VM and management traffic |
| Proxmox `nic1` to Cisco Gi1/0/28 | Receives copied SPAN traffic |

---

## Proxmox Bridges

| Bridge | Purpose |
|---|---|
| `vmbr0` | Carries VLANs 10, 66, and 99 |
| `vmbr1` | Delivers copied traffic to Security Onion |

`vmbr1` is for passive monitoring. It must not have an IPv4 address, gateway, or DHCP configuration.

---

## DNS Traffic

| Step | Traffic movement |
|---:|---|
| 1 | Windows sends a DNS request from `172.16.10.50`. |
| 2 | The Juniper SRX routes it from VLAN 10 to VLAN 66. |
| 3 | The Ubuntu DNS server receives it at `192.168.66.53`. |
| 4 | The response returns to Windows through the same routed path. |

---

## Detection Data

| Platform | Data it examines |
|---|---|
| Security Onion | Copied DNS network traffic |
| Splunk | BIND9 logs, Sysmon events, and Windows DNS events |

The two platforms provide different views of the same lab activity.