# Engineering an Air-Gapped Stateful Security Lab: From Attack Traffic to Detection

I built an isolated security research lab designed to make every security control **observable, testable, and repeatable**.

The environment combines a physical **Juniper SRX300**, **Cisco Catalyst 2960-X**, **Proxmox VE**, **Kali Linux**, **antiX Linux**, **Security Onion 3.2.0**, **Windows 11**, and **Splunk** into a controlled threat-analysis platform.

---

## The Engineering Objective

> **Don't just simulate the network. Force the traffic through the real security boundaries.**

Attack traffic is generated from the **Kali Linux** environment, routed through the **Juniper SRX300 stateful firewall**, transported across **Cisco 802.1Q VLANs**, delivered into an isolated victim segment, mirrored through a dedicated **SPAN interface**, captured by **Security Onion**, and analyzed through **SIEM-driven threat hunting**.

The goal is to reproduce the complete security-monitoring lifecycle:

```text
Attack Generation
       │
       ▼
Stateful Firewall Enforcement
       │
       ▼
802.1Q Network Segmentation
       │
       ▼
Victim Network
       │
       ▼
SPAN Traffic Mirroring
       │
       ▼
Security Onion
       │
       ├── Suricata
       ├── Zeek
       └── Packet Capture
       │
       ▼
SIEM Analysis / Threat Hunting
```

---

## Core Capabilities Demonstrated

- **Stateful Enforcement:** `ATTACKER` → `VICTIMS` traffic is permitted and observed.
- **Explicit Denial:** `ATTACKER` → `MGMT` initiation is explicitly denied and logged.
- **Layer 2 Segmentation:** Cisco VLAN segmentation and SPAN telemetry.
- **Hypervisor Bridging:** Proxmox VLAN-aware and capture-only bridges.
- **Sensor Visibility:** Dedicated out-of-band packet capture using Security Onion.
- **Command Center:** Windows 11 dual-homed analyst operations.
- **Threat Hunting:** DNS exfiltration hunting utilizing Splunk.
- **End-to-End Validation:** Validation from raw packet flow through network enforcement, packet capture, and SIEM detection.

---

## Critical Traffic Separation

One of the most important engineering requirements in this architecture is the strict physical separation of the Proxmox management and monitoring paths.

This ensures that **live management traffic and mirrored SPAN traffic remain isolated from one another**.

### Management and Live VM Traffic

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

- **Cisco Interface:** `Gi1/0/27`
- **Proxmox Physical NIC:** `nic0`
- **Proxmox Bridge:** `vmbr0`
- **Purpose:** Management and live VLAN traffic

### Security Onion SPAN / Capture Traffic

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

- **Cisco Interface:** `Gi1/0/28`
- **Proxmox Physical NIC:** `nic1`
- **Proxmox Bridge:** `vmbr1`
- **Purpose:** Dedicated Security Onion SPAN/capture feed

This separation prevents the monitoring interface from becoming part of the production forwarding path and preserves the intended **out-of-band monitoring architecture**.

---

## Detection Architecture

The monitoring path is intentionally separate from the management path.

Mirrored traffic follows:

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

This design allows Security Onion to observe traffic without participating in the routed data path.

---

## Design Philosophy

> *This project is a practical demonstration of how network engineering, infrastructure security, packet analysis, and SOC operations converge into one observable security system.*

The lab is built around three principles:

**Every control should be configurable.**

**Every control should be testable.**

**Every test should generate evidence.**