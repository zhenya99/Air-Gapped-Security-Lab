# 🛡️ Engineering an Air-Gapped Stateful Security Lab
### *From Raw Attack Traffic to SIEM Detection*




Welcome to my air-gapped security research lab—a custom-engineered environment built on a single, uncompromising principle: **every security control must be observable, testable, and repeatable**.

This isn't just a network simulation. This architecture generates live attack traffic and forces it through genuine security boundaries, putting defensive controls, telemetry pipelines, and response tactics to the test under highly realistic conditions.

By unifying a **Juniper SRX300**, **Cisco Catalyst 2960-X**, **Proxmox VE**, **Kali Linux**, **antiX Linux**, **Security Onion 3.2.0**, **Windows 11**, **Elastic", **Splunk**, the lab operates as a cohesive platform for threat detection and proof-of-concept validation.

The ultimate goal is bigger than just proving individual tools work. It's about *achieving complete end-to-end visibility—understanding exactly how traffic flows, where sensors intercept it, the evidence it leaves behind, and how an analyst can use that telemetry to hunt down malicious activity*.


---

## 🎯 The Engineering Objective

> *"Don't just simulate the network. Force the traffic through the real security boundaries."*

In this lab, attack traffic is generated from the **Kali Linux** environment, routed through the **Juniper SRX300 stateful firewall**, transported across **Cisco 802.1Q VLANs**, and delivered into an isolated victim segment. 

From there, the traffic is mirrored through a dedicated **SPAN interface**, captured by **Security Onion**, and ultimately analyzed through **SIEM-driven threat hunting**.

The goal is to reproduce the complete security-monitoring lifecycle:

```text
  [ Attack Generation ]
           │
           ▼
[ Stateful Firewall Enforcement ]
           │
           ▼
[ 802.1Q Network Segmentation ]
           │
           ▼
    [ Victim Network ]
           │
           ▼
 [ SPAN Traffic Mirroring ]
           │
           ▼
   [ Security Onion ]
           │
           ├── Suricata
           ├── Zeek
           └── Packet Capture
           │
           ▼
[ SIEM Analysis / Threat Hunting ]
```

---

## ✨ Core Capabilities Demonstrated

*   🧱 **Stateful Enforcement:** `ATTACKER` → `VICTIMS` traffic is intentionally permitted and observed.
*   🛑 **Explicit Denial:** `ATTACKER` → `MGMT` initiation is strictly denied and logged at the perimeter.
*   🛤️ **Layer 2 Segmentation:** Cisco VLAN segmentation combined with SPAN telemetry.
*   🌉 **Hypervisor Bridging:** Proxmox VLAN-aware and capture-only network bridges.
*   👁️ **Sensor Visibility:** Dedicated out-of-band packet capture utilizing Security Onion.
*   💻 **Command Center:** Windows 11 dual-homed analyst operations.
*   🔎 **Threat Hunting:** DNS exfiltration hunting and analysis utilizing Splunk.
*   ✅ **End-to-End Validation:** Complete visibility from raw packet flow through network enforcement, packet capture, and SIEM detection.

---

## 🚦 Critical Traffic Separation

One of the most important engineering requirements in this architecture is the strict physical separation of the Proxmox management and monitoring paths. 

This design guarantees that **live management traffic and mirrored SPAN traffic remain completely isolated from one another**.

### 🛠️ Management and Live VM Traffic
This path handles the standard, day-to-day operations and live VLAN traffic.

```text
Cisco Gi1/0/27
       │
       ▼
  Proxmox nic0
       │
       ▼
     vmbr0
       │
       ├── Proxmox Management
       └── Live VM Network Traffic
```

### 🕵️ Security Onion SPAN / Capture Traffic
This path is dedicated entirely to feeding raw, mirrored packets to the sensor. It prevents the monitoring interface from becoming part of the production forwarding path, preserving a true **out-of-band monitoring architecture**.

```text
Cisco Gi1/0/28
       │
       ▼
  Proxmox nic1
       │
       ▼
     vmbr1
       │
       ▼
Security Onion Capture Interface
```

---

## 🔬 Detection Architecture

Because the monitoring path is intentionally separated from the management path, Security Onion can silently observe traffic without participating in the routed data path. 

Mirrored traffic follows this lifecycle:

```text
   Victim VLAN 10
         │
         ▼
Cisco Catalyst 2960-X
         │
         ▼
SPAN Destination — Gi1/0/28
         │
         ▼
    Proxmox nic1
         │
         ▼
       vmbr1
         │
         ▼
Security Onion Monitoring NIC
         │
         ▼
   Suricata / Zeek
         │
         ▼
  Security Analysis
```

---

## 💡 Design Philosophy

> *This project is a practical demonstration of how network engineering, infrastructure security, packet analysis, and SOC operations converge into one observable security system.*

I built this lab around three unbreakable principles:

1. ⚙️ **Every control should be configurable.**
2. 🧪 **Every control should be testable.**
3. 📊 **Every test should generate evidence.**