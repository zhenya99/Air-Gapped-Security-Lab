# Final Lab IP Addressing, VLANs, and Traffic Paths

This file documents the **current known-good addressing and Layer 2/Layer 3 relationships** for the air-gapped Security Onion lab.

---

## 1. ATTACKER Zone

| Item | Value |
|---|---|
| Security zone | `ATTACKER` |
| Subnet | `192.168.66.0/24` |
| Gateway | `192.168.66.1` |
| Juniper interface | `ge-0/0/5.0` |
| Kali Linux | `192.168.66.50/24` |
| Kali MAC | `22:12:4c:35:01:bb` |
| Layer 2 hardware | Netgear GS308 unmanaged switch |

### Physical path

```text
Kali 192.168.66.50
        │
        ▼
Netgear GS308
        │
        ▼
Juniper ge-0/0/5.0
192.168.66.1/24
ATTACKER zone
```

> **Important:** The Netgear attacker switch connects directly to the Juniper. Cisco `Gi1/0/2` is **not** part of the attacker path and is treated as an unused/blackhole port in the final switch configuration.

---

## 2. MGMT Network — VLAN 99

| Device | Interface / Role | Address |
|---|---|---|
| Juniper SRX | `ge-0/0/0.99` | `172.16.99.1/24` |
| Cisco Catalyst | `Vlan99` | `172.16.99.2/24` |
| Windows 11 analyst workstation | Management host | `172.16.99.10/24` |
| Proxmox VE | `vmbr0` | `172.16.99.20/24` |
| Security Onion 3.2.x | `ens18` / VM `net0` | `172.16.99.30/24` |

Known MAC addresses:

```text
Proxmox vmbr0/nic0:       fc:9d:05:05:87:6c
Security Onion net0:      bc:24:11:65:9f:86
Security Onion net1:      bc:24:11:ee:90:f1
```

### Cisco handling

```text
Gi1/0/1  -> Juniper trunk
             VLAN 99 tagged
             Native VLAN 999

Gi1/0/27 -> Proxmox nic0
             VLAN 99 native/untagged
             VLAN 10 tagged
```

The Cisco switch performs the Layer 2 transition between tagged VLAN 99 on the Juniper trunk and native/untagged VLAN 99 on the Proxmox uplink.

---

## 3. VICTIMS Zone — VLAN 10

| Item | Value |
|---|---|
| Security zone | `VICTIMS` |
| VLAN | `10` |
| Subnet | `172.16.10.0/24` |
| Gateway | `172.16.10.1` |
| Juniper interface | `ge-0/0/0.10` |
| Example antiX victim | `172.16.10.15/24` |

### Victim VM path

```text
antiX VM
172.16.10.15/24
      │
      ▼
VM net0 — Proxmox VLAN tag 10
      │
      ▼
vmbr0
      │
      ▼
nic0
      │
      ▼
Cisco Gi1/0/27
      │
      ▼
VLAN 10
      │
      ▼
Cisco Gi1/0/1
      │
      ▼
Juniper ge-0/0/0.10
172.16.10.1/24
```

---

## 4. Proxmox Management and Capture Networks

### Management path

```text
nic0
MTU 1500
  │
  ▼
vmbr0
172.16.99.20/24
MTU 1500
VLAN-aware
Allowed VLANs: 10,99
```

### Passive Security Onion capture path

```text
Cisco Gi1/0/28
SPAN Destination
      │
      ▼
Proxmox nic1
No IP
MTU 9000
      │
      ▼
vmbr1
No IPv4
MTU 9000
MAC learning disabled
      │
      ▼
VM 900 net1
No Proxmox VLAN tag
MTU 9000
      │
      ▼
Security Onion ens19
No IP
MTU 9000
      │
      ▼
bond0
MTU 9000
      │
      ├── Suricata
      └── Zeek
```

The monitoring interface is passive. Do **not** assign an IPv4 address, gateway, or Proxmox VLAN tag to Security Onion `net1` / `ens19`.

---

## 5. Cisco SPAN — Final Verified State

The final SPAN session mirrors the **Proxmox uplink**, not VLAN 10 directly:

```text
Source interface:
    GigabitEthernet1/0/27
Direction:
    BOTH

Destination interface:
    GigabitEthernet1/0/28

Encapsulation:
    Replicate

Ingress:
    Disabled
```

This design mirrors any traffic that crosses `Gi1/0/27`, including:

* Proxmox management traffic on VLAN 99.
* Tagged VLAN 10 victim VM traffic.
* Kali-to-Proxmox validation traffic after routing through the Juniper.

---

## 6. Juniper Routing and Security Boundaries

The Juniper directly owns all three routed networks:

```text
192.168.66.0/24 -> ge-0/0/5.0   ATTACKER
172.16.10.0/24  -> ge-0/0/0.10  VICTIMS
172.16.99.0/24  -> ge-0/0/0.99  MGMT
```

### Primary policies

```text
ATTACKER -> VICTIMS
    ATTACK-TRAFFIC
    permit

VICTIMS -> MGMT
    LOG-FORWARDING
    application junos-tcp-any
    permit

MGMT -> ATTACKER
    WIN-TO-KALI
    permit

ATTACKER -> MGMT
    ALLOW-KALI-PING-PROXMOX
    192.168.66.50 -> 172.16.99.20
    junos-ping only
    permit

ATTACKER -> MGMT
    BLOCK-KALI
    any -> any
    deny + log
```

`ALLOW-KALI-PING-PROXMOX` must be evaluated **before** `BLOCK-KALI`.

This keeps the management zone protected while allowing one deterministic ICMP flow for Security Onion validation.

---

## 7. IDS Validation Flow

The known-good local test is:

```text
Kali 192.168.66.50
        │
        │ ICMP
        ▼
Juniper SRX
ALLOW-KALI-PING-PROXMOX
        │
        ▼
Cisco Gi1/0/1
        │
        ▼
Cisco Gi1/0/27
        │
        ├──── SPAN copy ────► Gi1/0/28
        │                         │
        ▼                         ▼
Proxmox 172.16.99.20            nic1
                              MTU 9000
                                  │
                                vmbr1
                                  │
                              VM net1
                                  │
                                ens19
                                  │
                                bond0
                                  │
                              Suricata
                                  │
                              SID 1000001
                                  │
                                  ▼
                         Security Onion SOC
```

Custom rule:

```text
alert icmp 192.168.66.50 any -> 172.16.99.20 any (msg:"LAB TEST - Kali ICMP to Proxmox"; sid:1000001; rev:1;)
```

The Security Onion SOC confirmed this rule generated alerts successfully.
