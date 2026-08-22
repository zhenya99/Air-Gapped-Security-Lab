# Proxmox Network Backbone and Security Onion VM Bindings

This configuration defines the finalized Layer 2 transport architecture for the Proxmox VE hypervisor.

The two physical interfaces have completely separate responsibilities:

* **`nic0` → `vmbr0` → Cisco Gi1/0/27**
  Carries Proxmox management traffic on VLAN 99 and VLAN-tagged virtual-machine traffic such as the VLAN 10 victim network.

* **`nic1` → `vmbr1` → Cisco Gi1/0/28**
  Provides a dedicated passive monitoring path for Cisco SPAN traffic destined for the Security Onion sensor. The capture path uses **MTU 9000 end-to-end** so that Security Onion `ens19` can attach cleanly to the `bond0` monitoring interface used by Suricata.

`vmbr0` is configured as a **VLAN-aware Linux bridge**, allowing the hypervisor to transport multiple Layer 2 VLANs over the same physical uplink.

`vmbr1` is intentionally configured with **MAC address learning disabled** using `bridge-ageing 0`. The capture path also uses **MTU 9000** and disables hardware offloading on both `nic1` and `vmbr1`. This preserves mirrored traffic and allows Security Onion `ens19` to participate in the `bond0` monitoring path used by Suricata.

> **Important:** `vmbr1` must not have an IP address, default gateway, or VLAN tag. It exists exclusively as a passive Layer 2 transport path for mirrored traffic.

---

## 1. Configure `/etc/network/interfaces`

Open the Proxmox network configuration:

```bash
nano /etc/network/interfaces
```

Replace or verify the configuration as follows:

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

### Network Path Summary

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

## 2. Physical Hardware and Storage Profile

### Proxmox Administrative Access

The Proxmox VE management plane resides on:

```text
VLAN:       99
Subnet:     172.16.99.0/24
Proxmox IP: 172.16.99.20
Gateway:    172.16.99.1
```

The hypervisor can be administered through either the Proxmox Web GUI or SSH.

### Web Management

```text
https://172.16.99.20:8006
```

### SSH Management

```bash
ssh root@172.16.99.20
```

---

### Physical Interface Mapping

| Interface | MAC Address         | Cisco Port | Purpose                               |
| --------- | ------------------- | ---------- | ------------------------------------- |
| `nic0`    | `fc:9d:05:05:87:6c` | `Gi1/0/27` | Management + VLAN-aware VM traffic    |
| `nic1`    | `6c:6e:07:50:e9:18` | `Gi1/0/28` | Dedicated Security Onion SPAN capture, MTU 9000 |

The physical cabling must remain consistent with this mapping.

### Cable 1

```text
Proxmox nic0
     │
     └──────────── Cisco Gi1/0/27
                   Management + VM Traffic
                   Native VLAN 99
                   Tagged VLAN 10
```

### Cable 2

```text
Proxmox nic1
     │
     └──────────── Cisco Gi1/0/28
                   SPAN Destination
                   Passive Capture Only
```

> **Do not reverse these cables.**
> Cisco Gi1/0/28 is a SPAN destination and should not be used for normal Proxmox management or virtual-machine connectivity.

---

### External Security Onion Storage

Security Onion is stored on a dedicated **1 TB high-speed external SSD** to isolate its high-volume packet capture, telemetry, Elasticsearch, and log I/O from the primary Proxmox system disk.

The SSD is:

* Formatted as `ext4`
* Configured through the Proxmox storage interface as a **Directory** storage target
* Mounted and registered as:

```text
SecOnion-Storage
```

This storage is reserved primarily for the Security Onion VM.

---

## 3. Virtual Machine Hardware Bindings

### Victim Systems — antiX Linux VMs

The antiX Linux systems represent hosts located inside the **VICTIMS security zone**.

#### Storage

```text
Storage: local-lvm
```

The victim systems remain on the primary Proxmox storage pool because they do not require the sustained storage I/O expected from Security Onion.

#### Network Configuration

```text
Network Device: net0
Bridge:         vmbr0
VLAN Tag:       10
Firewall:       Disabled
```

The resulting path is:

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

The VLAN 10 tag places the target directly inside:

```text
VICTIMS Network
172.16.10.0/24
```

with the Juniper SRX300 providing the default gateway:

```text
172.16.10.1
```

#### Proxmox Firewall

The Proxmox firewall is intentionally disabled on the victim VM network interface:

```text
Firewall: Unchecked
```

This prevents the hypervisor firewall from unintentionally filtering laboratory attack traffic before it reaches the victim operating system.

Security controls for attacker-to-victim communication should instead be enforced and observed at the intended laboratory control points:

```text
Juniper SRX300
Security Onion
Guest operating system
```

---

## 4. Security Onion 3.2.0 Sensor Node

Security Onion is deployed as a dual-interface monitoring system.

The VM has completely separate interfaces for:

1. **Management**
2. **Passive packet acquisition**

This separation is fundamental to the architecture.

### Security Onion Storage

```text
Storage: SecOnion-Storage
```

The Security Onion VM is installed entirely on the dedicated external SSD.

This provides additional I/O capacity for:

* Elasticsearch data
* Suricata telemetry
* Zeek telemetry
* Full packet capture
* Strelka analysis
* Alert data
* Case data
* Log retention

---

### Security Onion Management NIC — `net0`

```text
Device:     net0
Bridge:     vmbr0
VLAN Tag:   Blank
Firewall:   Disabled
Guest NIC:  ens18
IP Address: 172.16.99.30/24
Gateway:    172.16.99.1
```

#### Why the VLAN Tag Is Blank

Cisco Gi1/0/27 uses **VLAN 99 as its native VLAN** for management traffic.

Therefore, Security Onion management traffic is transmitted untagged from the VM:

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

The Security Onion management address is:

```text
172.16.99.30/24
```

with:

```text
Gateway: 172.16.99.1
```

> **Important:** Do not configure `tag=99` on the Security Onion management NIC when Cisco Gi1/0/27 is using VLAN 99 as the native/untagged VLAN.

---

### Security Onion Capture NIC — `net1`

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

This interface exists solely to receive Cisco SPAN traffic.

The complete telemetry path is:

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

The capture interface must remain:

```text
No IP address
No default gateway
No Proxmox VLAN tag
No Proxmox firewall
MTU 9000 on the capture path
Attached to Security Onion `bond0` for monitoring
```

This prevents the monitoring interface from becoming an active participant in the network it is observing.

---

## 5. Final VM Network Matrix

| System         | VM NIC | Proxmox Bridge | VLAN Tag  | MTU  | Guest IP          | Purpose               |
| -------------- | ------ | -------------- | --------- | ---- | ----------------- | --------------------- |
| Proxmox VE     | Host   | `vmbr0`        | Native 99 | 1500 | `172.16.99.20/24` | Hypervisor management |
| antiX Linux    | `net0` | `vmbr0`        | `10`      | 1500 | `172.16.10.15/24` | Victim system         |
| Security Onion | `net0` | `vmbr0`        | **Blank** | 1500 | `172.16.99.30/24` | Management            |
| Security Onion | `net1` | `vmbr1`        | **Blank** | 9000 | **None**          | Passive SPAN capture  |

---

## 6. Final Physical Port Matrix

| Cisco Port | Connected Device       | Function                       |
| ---------- | ---------------------- | ------------------------------ |
| `Gi1/0/1`  | Juniper SRX300         | 802.1Q trunk                   |
| `Gi1/0/27` | Proxmox `nic0`         | Management + VM VLAN traffic   |
| `Gi1/0/28` | Proxmox `nic1`         | **Dedicated SPAN destination** |
| `Gi1/0/47` | Windows 11 workstation | VLAN 99 management access      |

The verified Cisco SPAN relationship is:

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

Because the SPAN source is `Gi1/0/27`, a useful validation test must generate traffic that actually crosses the Proxmox uplink. In this lab, Kali ICMP to `172.16.99.20` is used for that purpose.

The Proxmox management/live-traffic connection remains:

```text
GigabitEthernet1/0/27
        │
       nic0
        │
      vmbr0
```

while packet telemetry follows the physically isolated path:

```text
Traffic crossing Cisco Gi1/0/27
   │
Cisco SPAN Session 1 (BOTH)
   │
Gi1/0/28
   │
nic1 (MTU 9000)
   │
vmbr1 (MTU 9000)
   │
Security Onion net1 (MTU 9000)
   │
ens19
   │
bond0
   │
Suricata + Zeek
```

---

## 7. Post-Configuration Verification

After applying the configuration, verify the bridges:

```bash
ip -br addr
```

Verify bridge membership:

```bash
bridge link
```

Verify VLAN handling using compressed VLAN ranges:

```bash
bridge -compressvlans vlan show
```

The physical management uplink should be restricted to the VLANs required by this lab:

```text
nic0
    1 PVID Egress Untagged
    10
    99
```

`tap900i0` may still display a dynamically generated broad range such as `2-4094`; the important enforcement point is the physical uplink `nic0`, which remains restricted to VLANs 10 and 99.

Verify the Proxmox routing table:

```bash
ip route
```

The only default route should use the management network:

```text
default via 172.16.99.1 dev vmbr0
```

Verify that `vmbr1` has no Layer 3 address:

```bash
ip addr show vmbr1
```

It should not contain an IPv4 address.

Verify the physical capture interface, capture bridge, and VM sensor NIC MTUs:

```bash
ip link show nic1 | head -1
ip link show vmbr1 | head -1
qm config 900 | grep net1
```

Expected:

```text
nic1   ... mtu 9000
vmbr1  ... mtu 9000
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

Verify SPAN traffic directly on the Proxmox host:

```bash
tcpdump -ni nic1 -c 20
```

Then verify traffic reaches the monitoring bridge:

```bash
tcpdump -ni vmbr1 -c 20
```

Finally, verify that the same traffic reaches the Security Onion capture interface and monitoring bond:

```bash
sudo tcpdump -ni ens19 -c 20
sudo tcpdump -ni bond0 -c 20
```

The expected telemetry path is:

```text
Traffic crossing Cisco Gi1/0/27
      │
      ▼
Cisco SPAN Session 1
      │
      ▼
Gi1/0/28
      │
      ▼
Proxmox nic1 (MTU 9000)
      │
      ▼
vmbr1 (MTU 9000)
      │
      ▼
Security Onion ens19
      │
      ▼
bond0
      │
      ├── Suricata
      └── Zeek
```

Once the packet-capture tests show traffic on `nic1`, `vmbr1`, `ens19`, and `bond0`, the Layer 2 monitoring backbone is functioning correctly.

---

## 8. Connectivity and Suricata Troubleshooting — Final Known-Good Fixes

### 8.1 Kali Could Reach Its Gateway but Not Proxmox

Kali uses:

```text
IP:      192.168.66.50/24
Gateway: 192.168.66.1
```

The Juniper SRX correctly learned both Kali and the Proxmox host:

```text
22:12:4c:35:01:bb  192.168.66.50  ge-0/0/5.0
fc:9d:05:05:87:6c  172.16.99.20   ge-0/0/0.99
```

Routing was also correct:

```text
192.168.66.0/24 -> ge-0/0/5.0
172.16.99.0/24  -> ge-0/0/0.99
```

The actual connectivity failure was caused by the SRX security policy:

```text
ATTACKER -> MGMT
Policy: BLOCK-KALI
Source: any
Destination: any
Application: any
Action: deny
```

Rather than removing the segmentation policy, a narrow ICMP exception was inserted before `BLOCK-KALI`:

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

Validate and commit:

```text
show | compare
commit check
commit
```

Then verify from Kali:

```bash
ping -c 4 172.16.99.20
```

### 8.2 Verify the SPAN Path Hop by Hop

While Kali continuously pings `172.16.99.20`, validate the path in order.

On Proxmox:

```bash
tcpdump -eni nic0 icmp
tcpdump -eni nic1 icmp
tcpdump -eni vmbr1 icmp
tcpdump -eni tap900i1 icmp
```

Inside Security Onion:

```bash
sudo tcpdump -eni ens19 icmp
sudo tcpdump -ni bond0 icmp
```

Expected path:

```text
Kali 192.168.66.50
        │
        ▼
Juniper SRX
        │
        ▼
Cisco Gi1/0/27
        │
        ├──── SPAN copy ────► Gi1/0/28
        │                         │
        ▼                         ▼
Proxmox nic0                    nic1
172.16.99.20                  MTU 9000
                                  │
                                vmbr1
                              MTU 9000
                                  │
                              tap900i1
                                  │
                                ens19
                                  │
                                bond0
                                  │
                              Suricata
```

### 8.3 Suricata Saw Zero Packets Even Though `ens19` Saw Traffic

The critical symptom was:

```text
tcpdump on ens19: traffic visible
capture.kernel_packets: 0
decoder.pkts:           0
detect.alert:           0
```

The running Suricata configuration revealed:

```yaml
af-packet:
- interface: bond0
```

Suricata was listening on `bond0`, not directly on `ens19`.

Verify the running configuration:

```bash
sudo docker exec so-suricata sh -c "grep -A20 '^af-packet:' /etc/suricata/suricata.yaml"
```

The monitor interface state initially showed:

```text
bond0  MTU 9000
ens19  MTU 1500
```

and:

```text
bond0              bond      bond0
bond0-slave-ens19  ethernet  --
```

The `ens19` monitoring NIC was therefore not participating correctly in `bond0`.

### 8.4 Final Capture MTU Fix

The capture path was standardized on MTU 9000:

```text
Proxmox nic1        = 9000
Proxmox vmbr1       = 9000
VM 900 net1         = 9000
Security Onion ens19 = 9000
Security Onion bond0 = 9000
```

The Proxmox management path remains MTU 1500.

Verify on Proxmox:

```bash
ip link show nic1 | head -1
ip link show vmbr1 | head -1
qm config 900 | grep net1
```

Expected:

```text
nic1   ... mtu 9000
vmbr1  ... mtu 9000
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

Security Onion's monitor interface profile can be created with:

```bash
sudo so-monitor-add ens19
```

Verify:

```bash
nmcli -f NAME,TYPE,DEVICE connection show | grep -E 'bond0|ens19'
ip link show master bond0
ip -br link show bond0
```

The final state must show `ens19` attached to `bond0`.

### 8.5 Verify Suricata Is Processing Packets

Check the Suricata counters:

```bash
sudo grep -E 'capture.kernel_packets|decoder.pkts|detect.alert' \
/opt/so/log/suricata/stats.log | tail -15
```

Broken state:

```text
capture.kernel_packets = 0
decoder.pkts           = 0
detect.alert           = 0
```

Known-good state observed after the fix:

```text
capture.kernel_packets | Total | 1473
decoder.pkts           | Total | 1510
detect.alert           | Total | 28
```

Non-zero packet, decoder, and alert counters prove that Suricata is receiving and inspecting the mirrored traffic.

### 8.6 Custom Detection Validation

A deterministic test rule was created in Security Onion:

```text
alert icmp 192.168.66.50 any -> 172.16.99.20 any (msg:"LAB TEST - Kali ICMP to Proxmox"; sid:1000001; rev:1;)
```

Verify that the running Suricata container has the rule:

```bash
sudo docker exec so-suricata grep -Rni 'sid:1000001' /etc/suricata/rules 2>/dev/null
```

Expected:

```text
/etc/suricata/rules/all-rulesets.rules:...:alert icmp 192.168.66.50 any -> 172.16.99.20 any (msg:"LAB TEST - Kali ICMP to Proxmox"; sid:1000001; rev:1;)
```

Security Onion SOC ultimately displayed:

```text
LAB TEST - Kali ICMP to Proxmox
event.module: suricata
SID / rule UUID: 1000001
severity: low
```

The built-in `GPL ICMP PING *NIX` rule also fired, confirming that the full capture and detection pipeline was operational.

### 8.7 Final Known-Good State

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

![Proxmox Disk Usage](/images/Proxmox/backbone.png)
