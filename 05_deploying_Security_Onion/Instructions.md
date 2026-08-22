# Deploying Security Onion v3.2.0

Deploying Security Onion 3.2.x requires precise interface alignment so that Cisco SPAN traffic crossing the Proxmox uplink reaches the Security Onion monitoring stack and is processed by Suricata and Zeek. 

This module breaks down the deployment process from bare-metal hypervisor preparation to the final SOC dashboard configuration.

---

## 🏗️ Architecture & Prerequisites

Before beginning the deployment, ensure your host environment has the capacity to support a standalone Security Onion instance.

**My Lab Hardware Setup:**
* **CPU:** Intel i7-12700K (12 physical cores / 20 logical threads).
* **Memory:** 46GB Total RAM.
* **Storage:** 240GB internal SSD (Host OS) & 1TB external SSD (VM Datastores).

### 💡 Useful Pointers for Proxmox Users
* **CPU Passthrough:** You must change the VM CPU type from Proxmox's default `kvm64` to `host`. This allows the Intrusion Detection System (Suricata) to utilize your processor's advanced instruction sets for faster packet inspection.
* **Memory Allocation:** Security Onion requires a strict minimum of 24GB for a standalone deployment. **Disable Memory Ballooning** in Proxmox to ensure the VM's RAM is not dynamically reallocated to other containers.
* **Network Bridging:** The capture interface must be attached to `vmbr1` with **no Proxmox VLAN tag** and the Proxmox firewall disabled. In the final working configuration, the complete capture path (`nic1` → `vmbr1` → VM `net1` → `ens19` → Security Onion `bond0`) uses **MTU 9000**.

---

## 📑 Deployment Guide

Follow these modules in order to provision, install, configure, and validate the sensor:

* **[Step 1: Proxmox Environment & Storage Preparation](Step-1.md)**
  * *Validate host resources, ISO integrity, storage, VLAN restrictions, bridge membership, capture MTU, and the Cisco SPAN feed.*
* **[Step 2: Virtual Machine Provisioning & Hardware Validation](Step-2.md)**
  * *Provision VM 900 with the verified CPU, memory, disk, management NIC, and MTU-9000 passive capture NIC.*
* **[Step 3: Security Onion OS Installation](Step-3.md)**
  * *Install Security Onion 3.2.x from the official ISO and transition the VM to disk boot.*
* **[Step 4: Standalone Air-Gapped Setup](Step-4.md)**
  * *Configure Standalone/Airgap mode, `ens18` management, and `ens19` passive monitoring.*
* **[Step 5: Sensor Bring-Up, SPAN Validation, and Suricata Detection](Step-5.md)**
  * *Validate `ens19` → `bond0`, Suricata AF_PACKET capture, the Juniper test exception, and the local SID `1000001` alert.*

> **Known-good lab baseline:** `vmbr0` is VLAN-aware for VLANs **10 and 99 only**; Cisco `Gi1/0/27` uses native VLAN 99 and is the verified SPAN source in both directions; Cisco `Gi1/0/28` is the SPAN destination; the Security Onion capture path uses **MTU 9000**.
