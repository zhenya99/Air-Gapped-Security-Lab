# Security Onion v3.2.0 Deployment Guide

## 1. VM Provisioning in Proxmox

Before booting the Security Onion ISO, configure the virtual hardware to match the required network segmentation and storage layout.

### Verify Proxmox Host Resources

From the Proxmox shell, verify the available CPU, memory, and storage:

```
ssh root@lab

lscpu
pvesh get /nodes/localhost/status
free -h
df -h
lsblk
```

These commands provide information about:

* CPU architecture and available processors
* Proxmox node status and resource allocation
* Available system memory
* Mounted filesystems and available disk space
* Block devices and attached storage

### Security Onion VM Blueprint

| Resource           | Configuration         |
| ------------------ | --------------------- |
| **CPU**            | 8–12 cores            |
| **CPU Type**       | `host`                |
| **Memory**         | 24–28 GB              |
| **Ballooning**     | Disabled              |
| **Storage**        | 250–500 GB            |
| **Management NIC** | `vmbr0` / VLAN `99`   |
| **Capture NIC**    | `vmbr1` / No VLAN tag |

### Management Interface

```
Bridge:    vmbr0
VLAN Tag:  99
Firewall:  Enabled
Purpose:   Security Onion management and SOC access
```

### Capture Interface

```
Bridge:    vmbr1
VLAN Tag:  <Leave Blank>
Firewall:  Disabled
Purpose:   Mirrored network traffic capture
```

> **Important:** The capture interface should remain dedicated to monitoring traffic. Do not assign a management IP address to this interface.

### Host Hardware

The lab Proxmox host provides:

* **CPU:** Intel Core i7-12700K
* **Memory:** 46 GB RAM
* **Internal Storage:** 240 GB SSD
* **External Storage:** 1 TB SSD

Because Security Onion is resource-intensive, allocate resources carefully so sufficient CPU, RAM, and storage remain available for the Proxmox host and other laboratory VMs.
