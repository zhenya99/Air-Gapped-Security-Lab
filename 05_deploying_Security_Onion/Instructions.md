# Deploying Security Onion v3.2.0

Deploying Security Onion 3.2.x requires precise interface alignment to ensure that mirrored VLAN 10 traffic successfully reaches the Suricata and Zeek sensors. 

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
* **Network Bridging:** The capture interface must be attached to a bridge that does not have a VLAN tag assigned, and the Proxmox firewall must be **unchecked** for that specific interface to allow promiscuous traffic sniffing.

---

## 📑 Deployment Guide

Follow these modules in order to provision, install, and configure the sensor:

* **[Step 1: Proxmox Environment & Storage Preparation](Step%201.md)**
  * *Uploading the ISO, verifying host capacity, and configuring LVM-Thin storage pools.*
* **[Step 2: Virtual Machine Provisioning & OS Install](Step%202.md)**
  * *Configuring the virtual hardware blueprint and installing the base Oracle/CentOS operating system.*
* **[Step 3: The so-setup Wizard & Elastic Stack](Step%203.md)**
  * *Binding the management/capture interfaces and deploying the Kibana SOC dashboard.*

