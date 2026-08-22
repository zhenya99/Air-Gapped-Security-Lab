# Proxmox Network Backbone & Security Onion VM Bindings: A Complete Guide [cite: 4]

Building a reliable Layer 2 transport architecture in Proxmox is the foundation of any good virtualized SOC lab [cite: 4]. This guide walks through my finalized network backbone, separating management traffic from passive packet capture to ensure Suricata and Zeek get perfectly clean mirrored data [cite: 4]. 

Here is exactly how I configured the physical interfaces, virtual bridges, and VM hardware bindings to make it all work seamlessly [cite: 4].

## The Core Concept: Splitting the Interfaces
To keep things clean, I split the physical interfaces into two entirely separate roles [cite: 4]:
* **`nic0` → `vmbr0` → Cisco Gi1/0/27:** This path handles Proxmox management traffic (VLAN 99) and all VLAN-tagged VM traffic, like the VLAN 10 victim network [cite: 4]. `vmbr0` is set up as a VLAN-aware Linux bridge [cite: 4].
* **`nic1` → `vmbr1` → Cisco Gi1/0/28:** This is the dedicated, passive monitoring path strictly for Cisco SPAN traffic heading to the Security Onion sensor [cite: 4]. To ensure Security Onion's `ens19` can attach cleanly to Suricata's `bond0` monitor interface, this entire capture path runs at **MTU 9000** end-to-end [cite: 4]. MAC learning is completely disabled here using `bridge-ageing 0` [cite: 4]. 

> **Important:** `vmbr1` exists exclusively for passive Layer 2 transport. It has absolutely no IP address, default gateway, or VLAN tags [cite: 4]. 

---

## 1. Configuring `/etc/network/interfaces`
Let's get into the hypervisor configuration [cite: 4]. Open up the network config [cite: 4]:

```bash
nano /etc/network/interfaces
```

Here is the complete configuration to set up the management bridge and the MTU 9000 capture bridge (with hardware offloading disabled to preserve mirrored packets) [cite: 4]:

```text
auto lo
iface lo inet loopback

# ============================================================
# PHYSICAL INTERFACE 0 - Management & VMs (Cisco Gi1/0/27)
# ============================================================
iface nic0 inet manual

# ============================================================
# PHYSICAL INTERFACE 1 - SPAN Capture (Cisco Gi1/0/28)
# ============================================================
iface nic1 inet manual
        mtu 9000
        # Disable hardware offloading to preserve mirrored traffic
        post-up for i in rx tx sg tso ufo gso gro lro rxvlan txvlan; do ethtool -K $IFACE $i off 2>/dev/null || true; done
        post-up ip link set $IFACE up

# ============================================================
# BRIDGE 0 - MANAGEMENT + LIVE VM TRAFFIC
# Native/Untagged VLAN: 99
# Tagged VM VLAN:       10
# ============================================================
auto vmbr0
iface vmbr0 inet static
        address 172.16.99.20/24
        gateway 172.16.99.1
        bridge-ports nic0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 10 99

# ============================================================
# BRIDGE 1 - SECURITY ONION SPAN CAPTURE
# No IPv4 address
# No gateway
# No Proxmox VLAN tag
# MAC learning disabled
# MTU 9000 end-to-end on capture path
# ============================================================
auto vmbr1
iface vmbr1 inet manual
        bridge-ports nic1
        bridge-stp off
        bridge-fd 0
        bridge-ageing 0
        mtu 9000
        post-up for i in rx tx sg tso ufo gso gro lro; do ethtool -K $IFACE $i off 2>/dev/null || true; done

source /etc/network/interfaces.d/*
```

### Network Path Summary Diagram [cite: 4]
```text
                    CISCO CATALYST 2960-X
                           │
             ┌─────────────┴─────────────┐
             │                           │
         Gi1/0/27                    Gi1/0/28
      Management / VM                    │
         VLAN Traffic                SPAN Output
             │                           │
           nic0                        nic1
             │                           │
             ▼                           ▼
           vmbr0                       vmbr1
       VLAN-Aware Bridge          Capture-Only Bridge
        VLANs 10,99                   MTU 9000
             │                           │
       ┌─────┴──────┐                    │
       │            │                    │
  Proxmox Host   VM net0          Security Onion net1
  172.16.99.20    │                    ens19
                  │                     │
           ┌──────┴───────┐             │
           │              │             │
      Security Onion    antiX           │
          ens18          VLAN 10         │
      172.16.99.30   172.16.10.15       │
                                         │
                                  Passive Packet Capture
                                         │
                                       bond0
                                         │
                               Suricata / Zeek / Strelka
```

---

## 2. Hardware Mapping & Storage Profile

### Management Access [cite: 4]
The management plane lives on VLAN 99 (`172.16.99.0/24`), with the Proxmox host sitting at `172.16.99.20` (Gateway: `172.16.99.1`) [cite: 4]. You can hit it via [cite: 4]:
* **Web:** `https://172.16.99.20:8006` [cite: 4]
* **SSH:** `ssh root@172.16.99.20` [cite: 4]

### Physical Interface Mapping [cite: 4]
Getting the physical cabling right is critical [cite: 4]. If you reverse these, you'll accidentally dump your management traffic into a SPAN destination port [cite: 4].

| Interface | MAC Address         | Cisco Port | Purpose                               |
| --------- | ------------------- | ---------- | ------------------------------------- |
| `nic0`    | `fc:9d:05:05:87:6c` | `Gi1/0/27` | Management + VLAN-aware VM traffic    |
| `nic1`    | `6c:6e:07:50:e9:18` | `Gi1/0/28` | Dedicated Security Onion SPAN capture, MTU 9000 |

**Cable 1 (Management/VM Traffic):** [cite: 4]
```text
Proxmox nic0
     │
     └──────────── Cisco Gi1/0/27
                   Management + VM Traffic
                   Native VLAN 99
                   Tagged VLAN 10
```

**Cable 2 (SPAN Destination - Do not reverse!):** [cite: 4]
```text
Proxmox nic1
     │
     └──────────── Cisco Gi1/0/28
                   SPAN Destination
                   Passive Capture Only
```

### The Security Onion Storage Upgrade [cite: 4]
To isolate high-volume packet capture, Elasticsearch indexing, and log I/O from the main Proxmox OS drive, I added a **1 TB high-speed external SSD** formatted as `ext4` [cite: 4]. It’s registered in Proxmox as a Directory storage target named `SecOnion-Storage` [cite: 4]. 

---

## 3. Virtual Machine Hardware Bindings

### Victim Systems (antiX Linux) [cite: 4]
These represent the targets living in the **VICTIMS security zone** [cite: 4].
* **Storage:** They sit on the standard `local-lvm` pool since they don't generate massive disk I/O [cite: 4].
* **Network:** Bound to `net0` on `vmbr0` with VLAN Tag `10` [cite: 4]. The Proxmox firewall is strictly **Disabled** on this NIC to ensure the hypervisor doesn't accidentally block incoming lab attack traffic [cite: 4]. Security controls should only be enforced by the Juniper SRX300 (`172.16.10.1`), Security Onion, or the guest OS itself [cite: 4].

```text
antiX VM
172.16.10.15/24
      │
    net0
      │
 VLAN Tag 10
      │
    vmbr0
      │
    nic0
      │
Cisco Gi1/0/27
      │
    VLAN 10
      │
Juniper SRX300
172.16.10.1
```

---

## 4. Security Onion 3.2.0 Sensor Configuration
The sensor is deployed with a dual-interface setup to completely separate management from passive packet acquisition [cite: 4]. The VM itself lives entirely on the `SecOnion-Storage` SSD to handle Suricata, Zeek, Strelka, and Elasticsearch workloads [cite: 4].

### Management NIC (`net0`) [cite: 4]
```text
Device:     net0
Bridge:     vmbr0
VLAN Tag:   Blank
Firewall:   Disabled
Guest NIC:  ens18
IP Address: 172.16.99.30/24
Gateway:    172.16.99.1
```
Because Cisco Gi1/0/27 uses VLAN 99 as its native (untagged) VLAN, the VLAN tag on this VM interface is intentionally left blank [cite: 4]. 

```text
Security Onion ens18
        │
      net0
        │
   No VLAN Tag
        │
      vmbr0
        │
       nic0
        │
 Cisco Gi1/0/27
        │
 Native VLAN 99
        │
172.16.99.0/24
```

### Capture NIC (`net1`) [cite: 4]
This interface exists exclusively to receive SPAN traffic and must never participate in the network it observes [cite: 4].
```text
Device:     net1
Bridge:     vmbr1
VLAN Tag:   Blank
Firewall:   Disabled
MTU:        9000
Guest NIC:  ens19
IP Address: NONE
Gateway:    NONE
```

Here is the complete telemetry path [cite: 4]:
```text
              Traffic crossing Gi1/0/27
                       │
                       ▼
                 Cisco Catalyst
                       │
          SPAN Source: Gi1/0/27
              Direction: BOTH
                       │
                       ▼
                   Gi1/0/28
                SPAN Destination
          Encapsulation: Replicate
                       │
                       ▼
                     nic1
                   MTU 9000
                       │
                       ▼
                     vmbr1
                   MTU 9000
            MAC Learning Disabled
                       │
                       ▼
               Security Onion net1
                   MTU 9000
                       │
                       ▼
                     ens19
                       │
                       ▼
                     bond0
                       │
              ┌────────┴────────┐
              │                 │
           Suricata            Zeek
              │                 │
        IDS Detection     Network Metadata
```

---

## 5. Final Architecture Matrices

**VM Network Matrix** [cite: 4]
| System         | VM NIC | Proxmox Bridge | VLAN Tag  | MTU  | Guest IP          | Purpose               |
| -------------- | ------ | -------------- | --------- | ---- | ----------------- | --------------------- |
| Proxmox VE     | Host   | `vmbr0`        | Native 99 | 1500 | `172.16.99.20/24` | Hypervisor management |
| antiX Linux    | `net0` | `vmbr0`        | `10`      | 1500 | `172.16.10.15/24` | Victim system         |
| Security Onion | `net0` | `vmbr0`        | **Blank** | 1500 | `172.16.99.30/24` | Management            |
| Security Onion | `net1` | `vmbr1`        | **Blank** | 9000 | **None**          | Passive SPAN capture  |

**Physical Port Matrix** [cite: 4]
| Cisco Port | Connected Device       | Function                       |
| ---------- | ---------------------- | ------------------------------ |
| `Gi1/0/1`  | Juniper SRX300         | 802.1Q trunk                   |
| `Gi1/0/27` | Proxmox `nic0`         | Management + VM VLAN traffic   |
| `Gi1/0/28` | Proxmox `nic1`         | **Dedicated SPAN destination** |
| `Gi1/0/47` | Windows 11 workstation | VLAN 99 management access      |

**Cisco SPAN Configuration:** [cite: 4]
```text
Session 1
Source:
    GigabitEthernet1/0/27
    Direction: BOTH
Destination:
    GigabitEthernet1/0/28
Encapsulation:
    Replicate
Ingress:
    Disabled
```

Because `Gi1/0/27` is the SPAN source, validating the capture path requires generating traffic that actually crosses that uplink [cite: 4]. I use Kali ICMP pings to `172.16.99.20` for this exact purpose [cite: 4].

---

## 6. Post-Configuration Verification Checks

Time to prove it works [cite: 4]. Run these on the Proxmox host to verify the bridges and VLAN handling:

```bash
ip -br addr
bridge link
bridge -compressvlans vlan show
```
The physical uplink `nic0` should clearly restrict egress to the necessary VLANs [cite: 4]:
```text
nic0
    1 PVID Egress Untagged
    10
    99
```

Check the routing table to ensure default traffic routes via the management network (`vmbr0`) [cite: 4]:
```bash
ip route
```
Expected: `default via 172.16.99.1 dev vmbr0` [cite: 4]

Confirm the passive capture bridge (`vmbr1`) has no IP address [cite: 4]:
```bash
ip addr show vmbr1
```

Verify that MTU 9000 is correctly applied across the entire SPAN path [cite: 4]:
```bash
ip link show nic1 | head -1
ip link show vmbr1 | head -1
qm config 900 | grep net1
```
Expected output [cite: 4]:
```text
nic1   ... mtu 9000
vmbr1  ... mtu 9000
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

**Testing the Telemetry Flow:** [cite: 4]
Verify traffic hop-by-hop from the physical NIC up to the Suricata bond [cite: 4]:
```bash
tcpdump -ni nic1 -c 20
tcpdump -ni vmbr1 -c 20
sudo tcpdump -ni ens19 -c 20
sudo tcpdump -ni bond0 -c 20
```

If packets appear across `nic1`, `vmbr1`, `ens19`, and `bond0`, your Layer 2 monitoring backbone is golden [cite: 4].

---

## 7. Known-Good Fixes & Troubleshooting History

### Fix 1: Juniper Firewall Blocking Kali to Proxmox [cite: 4]
Initially, my Kali box (`192.168.66.50`) couldn't reach Proxmox (`172.16.99.20`) [cite: 4]. Routing was perfectly fine, but the Juniper SRX was hitting a `BLOCK-KALI` deny policy for anything moving from the ATTACKER to MGMT zones [cite: 4]. 

To fix this securely without breaking segmentation, I added a narrow ICMP exception *before* the deny rule [cite: 4]:

```text
set security zones security-zone ATTACKER address-book address KALI-HOST 192.168.66.50/32
set security zones security-zone MGMT address-book address PROXMOX-HOST 172.16.99.20/32

set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX match source-address KALI-HOST
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX match destination-address PROXMOX-HOST
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX match application junos-ping
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX then permit
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX then log session-init
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX then log session-close

insert security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX before policy BLOCK-KALI
```
```text
show | compare
commit check
commit
```
After committing, `ping -c 4 172.16.99.20` succeeded [cite: 4].

### Fix 2: The Silent Sensor MTU Mismatch [cite: 4]
Even with SPAN traffic visible on `ens19`, Suricata logged exactly `0` capture and decoder packets [cite: 4]. 

Checking Suricata's config proved it was listening on `bond0` [cite: 4]:
```bash
sudo docker exec so-suricata sh -c "grep -A20 '^af-packet:' /etc/suricata/suricata.yaml"
```
The issue? `bond0` was MTU 9000, but `ens19` was stuck at MTU 1500, meaning it couldn't join the bond (`bond0-slave-ens19` showed no device) [cite: 4].

Applying the MTU 9000 standard across `nic1`, `vmbr1`, `net1`, and `ens19` fixed the issue [cite: 4]. The monitor profile was rebuilt with [cite: 4]:
```bash
sudo so-monitor-add ens19
```
Verification commands [cite: 4]:
```bash
nmcli -f NAME,TYPE,DEVICE connection show | grep -E 'bond0|ens19'
ip link show master bond0
ip -br link show bond0
```

### Validating the Fix [cite: 4]
Once resolved, Suricata finally started crunching packets [cite: 4]:
```bash
sudo grep -E 'capture.kernel_packets|decoder.pkts|detect.alert' /opt/so/log/suricata/stats.log | tail -15
```
*(Counters jumped from 0 to over 1,000)* [cite: 4]

I deployed a test rule to confirm [cite: 4]:
```text
alert icmp 192.168.66.50 any -> 172.16.99.20 any (msg:"LAB TEST - Kali ICMP to Proxmox"; sid:1000001; rev:1;)
```
Verified it was active in the container [cite: 4]:
```bash
sudo docker exec so-suricata grep -Rni 'sid:1000001' /etc/suricata/rules 2>/dev/null
```
And sure enough, Security Onion SOC lit up with my custom `LAB TEST` alert alongside the built-in `GPL ICMP PING *NIX` rule [cite: 4].

### Final Status Checklist [cite: 4]
```text
Kali routing                 PASS
Juniper routing              PASS
Juniper ATTACKER -> MGMT     PASS with narrow ICMP exception
Cisco trunking               PASS
Cisco SPAN                   PASS
Proxmox vmbr0                PASS
Proxmox vmbr1                PASS
Capture MTU 9000             PASS
Security Onion ens19         PASS
Security Onion bond0         PASS
Suricata AF_PACKET capture   PASS
Suricata packet decoding     PASS
Custom SID 1000001           PASS
Security Onion SOC alert     PASS
```
![Proxmox Disk Usage](/images/Proxmox/backbone.png) [cite: 4]
