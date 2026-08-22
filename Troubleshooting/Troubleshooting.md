# Security Onion Connectivity and Suricata Troubleshooting Report

## Kali → Juniper → Cisco → Proxmox → Security Onion → Suricata

**Lab platform:** Proxmox VE 9.2.x
**Security Onion:** 3.2.x
**Sensor engine:** Suricata
**Troubleshooting date:** August 22, 2026

---

# 1. Executive Summary

This document records the complete troubleshooting process used to restore end-to-end connectivity and Suricata detection in the Security Onion lab.

The original symptoms were:

* Kali could not initially reach the Proxmox management address.
* Cisco SPAN traffic was eventually confirmed to reach the Security Onion monitoring NIC.
* `tcpdump` on Security Onion `ens19` could see mirrored packets.
* Suricata nevertheless processed **zero packets**.
* Custom Suricata rule SID `1000001` was correctly deployed but did not initially generate an event.
* Security Onion's `bond0` monitoring interface had no active slave.
* `ens19` was operating at MTU 1500 while Security Onion `bond0` expected MTU 9000.
* Once the Proxmox capture path was changed to MTU 9000 and `ens19` successfully joined `bond0`, Suricata immediately began processing packets and generating alerts.

The final working packet path is:

```text
Kali
192.168.66.50
        |
        v
Netgear Switch
        |
        v
Juniper SRX
ge-0/0/5.0
192.168.66.1
ATTACKER Zone
        |
        | Routing + Security Policy
        v
Juniper ge-0/0/0.99
172.16.99.1
MGMT Zone
        |
        v
Cisco Gi1/0/1
        |
        v
Cisco Gi1/0/27
Proxmox Uplink
        |
        +---------------- SPAN ----------------+
        |                                      |
        v                                      v
Proxmox nic0                            Cisco Gi1/0/28
        |                                      |
        v                                      v
vmbr0                                  Proxmox nic1
172.16.99.20                           MTU 9000
                                               |
                                               v
                                             vmbr1
                                             MTU 9000
                                               |
                                               v
                                          VM 900 net1
                                             MTU 9000
                                               |
                                               v
                                             ens19
                                               |
                                               v
                                             bond0
                                               |
                                               v
                                            Suricata
                                               |
                                               v
                                      Security Onion SOC
                                               |
                                               v
                                         ALERT GENERATED
```

---

# 2. Final Addressing and Interface Matrix

| System         | Interface     | Address / VLAN       | Purpose                       |
| -------------- | ------------- | -------------------- | ----------------------------- |
| Kali           | Ethernet      | `192.168.66.50/24`   | Attacker                      |
| Juniper SRX    | `ge-0/0/5.0`  | `192.168.66.1/24`    | Attacker gateway              |
| Juniper SRX    | `ge-0/0/0.10` | `172.16.10.1/24`     | Victim gateway                |
| Juniper SRX    | `ge-0/0/0.99` | `172.16.99.1/24`     | Management gateway            |
| Cisco          | `Gi1/0/1`     | 802.1Q trunk         | Juniper uplink                |
| Cisco          | `Gi1/0/27`    | Native VLAN 99 trunk | Proxmox main uplink           |
| Cisco          | `Gi1/0/28`    | SPAN destination     | Security Onion capture        |
| Proxmox        | `vmbr0`       | `172.16.99.20/24`    | Management/live traffic       |
| Security Onion | `net0`        | `172.16.99.30/24`    | Management                    |
| Proxmox        | `nic1`        | No IP                | SPAN physical NIC             |
| Proxmox        | `vmbr1`       | No IPv4              | Passive capture bridge        |
| Security Onion | `ens19`       | No IP                | Monitoring NIC                |
| Security Onion | `bond0`       | No sensor IP         | Suricata/Zeek monitoring bond |

---

# 3. Important MAC Addresses

During troubleshooting, the following MAC addresses were verified.

```text
Proxmox vmbr0 / nic0:
FC:9D:05:05:87:6C

Security Onion net0:
BC:24:11:65:9F:86

Security Onion net1 / ens19:
BC:24:11:EE:90:F1

Kali:
22:12:4C:35:01:BB
```

The Juniper ARP table confirmed:

```text
fc:9d:05:05:87:6c 172.16.99.20 ge-0/0/0.99
bc:24:11:65:9f:86 172.16.99.30 ge-0/0/0.99
22:12:4c:35:01:bb 192.168.66.50 ge-0/0/5.0
```

This proved Layer 2 connectivity existed to both Kali and Proxmox.

---

# 4. Initial Proxmox VLAN Problem

The initial Proxmox configuration allowed essentially every VLAN:

```text
bridge-vlan-aware yes
bridge-vids 2-4094
```

This did not create thousands of VLAN interfaces, but it allowed the bridge to forward VLAN IDs from 2 through 4094.

For this lab, only VLANs 10 and 99 were required across `vmbr0`.

The configuration was changed to:

```text
bridge-vlan-aware yes
bridge-vids 10 99
```

Verification:

```bash
grep -nE 'bridge-vlan-aware|bridge-vids' /etc/network/interfaces
```

Expected:

```text
bridge-vlan-aware yes
bridge-vids 10 99
```

The live VLAN table was checked with:

```bash
bridge -compressvlans vlan show
```

Final relevant output:

```text
nic0
    1 PVID Egress Untagged
    10
    99

nic1
    1 PVID Egress Untagged

vmbr0
    1 PVID Egress Untagged

vmbr1
    1 PVID Egress Untagged

tap900i0
    1 PVID Egress Untagged
    2-4094

tap900i1
    1 PVID Egress Untagged
```

The remaining `2-4094` range on `tap900i0` was a dynamically created Proxmox VM tap configuration.

The important physical uplink `nic0` was successfully restricted to VLANs:

```text
10
99
```

The SPAN interface remained non-VLAN-aware.

---

# 5. Final Proxmox Network Configuration

The final `/etc/network/interfaces` design uses one bridge for normal management/live traffic and another isolated bridge for passive packet capture.

```bash
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
        post-up for i in rx tx sg tso ufo gso gro lro rxvlan txvlan; do ethtool -K $IFACE $i off 2>/dev/null || true; done
        post-up ip link set $IFACE up

# ============================================================
# BRIDGE 0 - MANAGEMENT + LIVE VM TRAFFIC
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

The capture bridge intentionally has:

```text
No IPv4 address
No gateway
No VLAN filtering
MAC ageing disabled
MTU 9000
```

---

# 6. Security Onion VM NIC Configuration

VM ID:

```text
900
```

The VM network configuration was verified with:

```bash
qm config 900 | grep -E '^net'
```

Final configuration:

```text
net0: virtio=BC:24:11:65:9F:86,bridge=vmbr0
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

Important characteristics:

```text
net0:
    Management
    vmbr0
    No Proxmox VLAN tag

net1:
    Passive capture
    vmbr1
    No Proxmox VLAN tag
    MTU 9000
```

There are intentionally no:

```text
tag=
trunks=
```

options on the Security Onion interfaces.

The sensor interface is not joining VLAN 10. It is receiving mirrored copies of traffic.

---

# 7. Cisco Topology Verification

The Cisco switch showed:

```text
Gi1/0/1   UPLINK_TO_JUNIPER   connected   trunk
Gi1/0/27  PROXMOX_MAIN_UPLIN  connected   trunk
Gi1/0/28  SECONION_CAPTURE_N  monitoring  1
```

The Juniper-facing trunk:

```text
Gi1/0/1
Native VLAN: 999
```

The Proxmox-facing trunk:

```text
Gi1/0/27
Native VLAN: 99
```

The native VLAN configuration was confirmed with:

```text
show interfaces Gi1/0/27 switchport
```

Relevant output:

```text
Administrative Mode: trunk
Operational Mode: trunk
Trunking Native Mode VLAN: 99
Administrative Native VLAN tagging: disabled
```

This is why Proxmox `vmbr0` and Security Onion `net0` use untagged/native VLAN 99 instead of explicitly applying:

```text
tag=99
```

---

# 8. Important Topology Correction

During troubleshooting, Cisco `Gi1/0/2` appeared as:

```text
notconnect
```

It was initially suspected to be the Kali/Netgear uplink.

That assumption was incorrect.

The actual physical topology was unchanged:

```text
Kali
  |
Netgear
  |
Juniper SRX
  |
Cisco Gi1/0/1
```

Therefore `Gi1/0/2` was not involved in the active Kali path.

This was an important troubleshooting correction because the physical state of `Gi1/0/2` was unrelated to the connectivity failure.

---

# 9. Cisco MAC Table Verification

The Cisco MAC table showed:

```text
Vlan    Mac Address       Ports
99      bc24.1165.9f86    Gi1/0/27
99      d007.cae5.35c8    Gi1/0/1
99      fc9d.0505.876c    Gi1/0/27
```

This verified that both:

```text
Proxmox
FC:9D:05:05:87:6C
```

and:

```text
Security Onion management
BC:24:11:65:9F:86
```

were correctly learned through `Gi1/0/27` on VLAN 99.

---

# 10. SPAN Configuration

The active Cisco SPAN session was:

```text
Session 1
---------
Type                     : Local Session
Source Ports             :
    Both                 : Gi1/0/27
Destination Ports        : Gi1/0/28
    Encapsulation        : Replicate
    Ingress              : Disabled
```

This means:

```text
Gi1/0/27 RX + TX
        |
        | mirrored copy
        v
Gi1/0/28
```

The SPAN destination operating in `monitoring` state is expected.

---

# 11. Why Pinging the Kali Gateway Did Not Test SPAN

The original test:

```bash
ping 192.168.66.1
```

only exercised:

```text
Kali
  |
Netgear
  |
Juniper
```

It did not cross Cisco `Gi1/0/27`.

Because the SPAN source was `Gi1/0/27`, this traffic was not useful for validating the Security Onion capture path.

The correct test became:

```bash
ping 172.16.99.20
```

because Proxmox resides behind `Gi1/0/27`.

---

# 12. Juniper Interface Verification

The SRX interfaces were verified with:

```text
show interfaces terse
```

Relevant output:

```text
ge-0/0/0.10   up up inet 172.16.10.1/24
ge-0/0/0.99   up up inet 172.16.99.1/24
ge-0/0/5.0    up up inet 192.168.66.1/24
```

The routes were also correct.

```text
192.168.66.0/24
    Direct
    via ge-0/0/5.0

172.16.99.0/24
    Direct
    via ge-0/0/0.99
```

This proved that routing information was present.

---

# 13. Juniper ARP Verification

The SRX ARP table contained:

```text
MAC Address          Address          Interface

60:cf:84:78:1f:7b    172.16.99.10     ge-0/0/0.99
fc:9d:05:05:87:6c    172.16.99.20     ge-0/0/0.99
bc:24:11:65:9f:86    172.16.99.30     ge-0/0/0.99
22:12:4c:35:01:bb    192.168.66.50    ge-0/0/5.0
```

This demonstrated that the SRX could see:

```text
Kali
Proxmox
Security Onion
```

at Layer 2.

---

# 14. Juniper Security Zones

The zones were:

```text
ATTACKER
    ge-0/0/5.0
    host-inbound ping

VICTIMS
    ge-0/0/0.10
    host-inbound ping

MGMT
    ge-0/0/0.99
    host-inbound all
```

Verification:

```text
show configuration security zones | display set
```

Relevant configuration:

```text
set security zones security-zone ATTACKER host-inbound-traffic system-services ping
set security zones security-zone ATTACKER interfaces ge-0/0/5.0

set security zones security-zone VICTIMS host-inbound-traffic system-services ping
set security zones security-zone VICTIMS interfaces ge-0/0/0.10

set security zones security-zone MGMT host-inbound-traffic system-services all
set security zones security-zone MGMT interfaces ge-0/0/0.99
```

---

# 15. Root Cause of Kali → Proxmox Connectivity Failure

Kali could reach its gateway:

```text
192.168.66.1
```

but initially could not reach:

```text
172.16.99.20
```

The SRX security policy revealed the reason:

```text
From zone: ATTACKER
To zone: MGMT

Policy: BLOCK-KALI
Source addresses: any
Destination addresses: any
Applications: any
Action: deny
```

Configuration:

```text
set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI match source-address any
set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI match destination-address any
set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI match application any
set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI then deny
set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI then log session-init
```

The firewall was behaving correctly.

The solution was **not** to remove the segmentation policy.

Instead, a narrow exception was created allowing only Kali ICMP traffic to the Proxmox host.

---

# 16. Narrow Kali → Proxmox ICMP Exception

Address objects:

```text
set security zones security-zone ATTACKER address-book address KALI-HOST 192.168.66.50/32
set security zones security-zone MGMT address-book address PROXMOX-HOST 172.16.99.20/32
```

Permit policy:

```text
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX match source-address KALI-HOST
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX match destination-address PROXMOX-HOST
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX match application junos-ping
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX then permit
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX then log session-init
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX then log session-close
```

The permit rule had to be evaluated before `BLOCK-KALI`:

```text
insert security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX before policy BLOCK-KALI
```

Validation:

```text
show | compare
commit check
commit
```

After this change:

```bash
ping 172.16.99.20
```

worked successfully from Kali.

---

# 17. End-to-End SPAN Verification

With Kali continuously pinging:

```bash
ping 172.16.99.20
```

the packet was traced hop-by-hop.

On Proxmox:

```bash
tcpdump -eni nic0 icmp
```

Confirmed original traffic.

Then:

```bash
tcpdump -eni nic1 icmp
```

Confirmed the Cisco SPAN copy reached the physical capture NIC.

Then:

```bash
tcpdump -eni vmbr1 icmp
```

Confirmed the Linux capture bridge received it.

Then:

```bash
tcpdump -eni tap900i1 icmp
```

Confirmed the Security Onion VM tap interface received it.

Inside Security Onion:

```bash
sudo tcpdump -eni ens19 icmp
```

Confirmed mirrored ICMP reached the Security Onion sensor NIC.

At this stage the network path was fully operational.

---

# 18. Suricata Still Processed Zero Packets

Despite `ens19` receiving traffic, Suricata reported:

```text
capture.kernel_packets | Total | 0
decoder.pkts           | Total | 0
detect.alert           | Total | 0
```

This was checked using:

```bash
sudo grep -E 'capture.kernel_packets|decoder.pkts|detect.alert' \
/opt/so/log/suricata/stats.log | tail -30
```

Therefore the issue was no longer:

```text
Cisco
Proxmox
SPAN
vmbr1
ens19
```

The fault existed between the Security Onion monitoring interface and Suricata.

---

# 19. Custom Suricata Rule Verification

A custom rule was created:

```text
alert icmp 192.168.66.50 any -> 172.16.99.20 any (msg:"LAB TEST - Kali ICMP to Proxmox"; sid:1000001; rev:1;)
```

The rule appeared in Security Onion Detections as:

```text
LAB TEST - Kali ICMP to Proxmox
Public ID: 1000001
Type: Suricata
Status: Enabled
```

The deployed rule was verified inside the running Suricata container:

```bash
sudo docker exec so-suricata \
grep -Rni 'sid:1000001' /etc/suricata/rules 2>/dev/null
```

Result:

```text
/etc/suricata/rules/all-rulesets.rules:51514:
alert icmp 192.168.66.50 any -> 172.16.99.20 any
(msg:"LAB TEST - Kali ICMP to Proxmox"; sid:1000001; rev:1;)
```

This proved the rule itself was not the problem.

---

# 20. Suricata Was Listening on bond0

The running Suricata configuration was checked:

```bash
sudo docker exec so-suricata sh -c \
"grep -A20 '^af-packet:' /etc/suricata/suricata.yaml"
```

Result:

```yaml
af-packet:
- interface: bond0
  cluster-id: 59
  cluster-type: cluster_flow
  defrag: true
  use-mmap: true
  mmap-locked: false
  threads: 3
  tpacket-v3: true
  ring-size: 5000
  block-size: 69632
  block-timeout: 10
  use-emergency-flush: true
  buffer-size: 32768
  disable-promisc: false
  checksum-checks: kernel
```

This was the critical discovery.

Suricata was **not** listening directly on:

```text
ens19
```

It was listening on:

```text
bond0
```

Therefore the required path was:

```text
ens19
  |
  v
bond0
  |
  v
Suricata
```

---

# 21. bond0 Had No Slave

Security Onion reported:

```bash
ip -br link show bond0
```

Result:

```text
bond0 DOWN  <NO-CARRIER,BROADCAST,MULTICAST,MASTER,UP>
```

Checking members:

```bash
ip link show master bond0
```

returned nothing.

Meanwhile:

```bash
ip -br link show ens19
```

showed:

```text
ens19 UP BC:24:11:EE:90:F1 <BROADCAST,MULTICAST,UP,LOWER_UP>
```

This proved:

```text
ens19      = healthy
bond0      = no active slave
Suricata   = listening on bond0
```

---

# 22. Security Onion Monitor Profile

The supported Security Onion utility was used:

```bash
sudo so-monitor-add ens19
```

The command created:

```text
bond0-slave-ens19
```

Verification:

```bash
nmcli -f NAME,TYPE,DEVICE connection show | grep -E 'bond0|ens19'
```

Initially showed:

```text
bond0              bond      bond0
bond0-slave-ens19  ethernet  --
```

The profile existed, but `ens19` still was not attached.

---

# 23. MTU Mismatch Discovery

The Security Onion interfaces were inspected:

```bash
nmcli device show ens19 | \
grep -E 'GENERAL.STATE|GENERAL.CONNECTION|GENERAL.MTU'
```

Result:

```text
GENERAL.MTU:        1500
GENERAL.STATE:      30 (disconnected)
GENERAL.CONNECTION: --
```

The bond showed:

```bash
nmcli device show bond0 | \
grep -E 'GENERAL.STATE|GENERAL.CONNECTION|GENERAL.MTU'
```

Result:

```text
GENERAL.MTU:        9000
GENERAL.STATE:      100 (connected)
GENERAL.CONNECTION: bond0
```

The critical mismatch was therefore:

```text
ens19 = MTU 1500
bond0 = MTU 9000
```

This prevented the Security Onion monitor NIC from successfully participating in the monitoring bond.

---

# 24. Important Troubleshooting Correction

During earlier troubleshooting, the Proxmox sensor NIC had been changed from MTU 9000 to MTU 1500 to eliminate a Proxmox warning.

That produced:

```text
net1 MTU 1500
vmbr1 MTU 1500
ens19 MTU 1500
```

However, Security Onion `bond0` expected:

```text
MTU 9000
```

Therefore the sensor path had to be restored to MTU 9000.

The management path remained MTU 1500.

Correct design:

```text
MANAGEMENT

nic0
 MTU 1500
   |
vmbr0
 MTU 1500
   |
net0


CAPTURE

nic1
 MTU 9000
   |
vmbr1
 MTU 9000
   |
net1
 MTU 9000
   |
ens19
 MTU 9000
   |
bond0
 MTU 9000
```

---

# 25. Proxmox Capture MTU Fix

The physical SPAN NIC was changed to:

```text
mtu 9000
```

The capture bridge was changed to:

```text
mtu 9000
```

The Security Onion virtual capture NIC was changed with:

```bash
qm set 900 \
--net1 virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

Verification:

```bash
ip link show nic1 | head -1
ip link show vmbr1 | head -1
qm config 900 | grep net1
```

Final result:

```text
nic1:
mtu 9000

vmbr1:
mtu 9000

net1:
virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

---

# 26. ifreload Warning

During:

```bash
ifreload -a
```

Proxmox returned:

```text
warning: cant remove bridge vmbr0, port tap900i0 is present
```

This occurred because Security Onion VM 900 was running and its management tap interface:

```text
tap900i0
```

was attached to:

```text
vmbr0
```

This warning did not prevent the capture-path MTU changes from being applied.

Verification proved:

```text
nic1   MTU 9000
vmbr1  MTU 9000
net1   MTU 9000
```

Therefore no manual deletion of `tap900i0` or `vmbr0` was performed.

---

# 27. Final Suricata Packet Counters

After correcting the capture path and restoring the monitoring bond, Suricata statistics changed dramatically.

Command:

```bash
sudo grep -E 'capture.kernel_packets|decoder.pkts|detect.alert' \
/opt/so/log/suricata/stats.log | tail -15
```

Observed results:

```text
capture.kernel_packets | Total | 1473
decoder.pkts           | Total | 1510
detect.alert           | Total | 28

capture.kernel_packets | Total | 3946
decoder.pkts           | Total | 4013
detect.alert           | Total | 57

capture.kernel_packets | Total | 849
decoder.pkts           | Total | 855
detect.alert           | Total | 28
```

Before the fix:

```text
capture.kernel_packets = 0
decoder.pkts           = 0
detect.alert           = 0
```

After the fix:

```text
capture.kernel_packets > 0
decoder.pkts           > 0
detect.alert           > 0
```

This definitively proved Suricata was receiving and processing mirrored packets.

---

# 28. Final Security Onion Alert

Security Onion SOC displayed two ICMP detections.

Built-in detection:

```text
GPL ICMP PING *NIX

Module:
suricata

SID:
2100366

Severity:
low
```

Custom detection:

```text
LAB TEST - Kali ICMP to Proxmox

Module:
suricata

SID:
1000001

Severity:
low
```

The custom detection appeared with a non-zero event count.

This verified the complete pipeline:

```text
Packet received
      |
      v
SPAN successful
      |
      v
Proxmox capture bridge successful
      |
      v
ens19 receives packet
      |
      v
bond0 receives packet
      |
      v
Suricata AF_PACKET capture
      |
      v
Rule SID 1000001 matched
      |
      v
Alert generated
      |
      v
Security Onion SOC displays event
```

---

# 29. Why zgrep Initially Returned Nothing

The command:

```bash
sudo zgrep -H '"signature_id":1000001' \
/nsm/suricata/*.gz 2>/dev/null | tail -20
```

did not return a result.

This did not mean the detection failed.

`zgrep` searches compressed/rotated EVE files only.

A newly generated alert may still exist in the currently active uncompressed EVE data or may already have been ingested into SOC before file rotation.

Security Onion SOC itself ultimately confirmed SID:

```text
1000001
```

was firing.

---

# 30. Final Root Causes

There were **two separate connectivity/detection problems**.

## Root Cause 1 — Juniper Security Policy

Kali traffic from:

```text
192.168.66.50
```

to:

```text
172.16.99.20
```

was blocked by:

```text
ATTACKER → MGMT
BLOCK-KALI
any → any
DENY
```

Resolution:

```text
Create a narrow ICMP-only exception
Kali → Proxmox
before BLOCK-KALI
```

This restored Kali → Proxmox connectivity without weakening the rest of the segmentation policy.

---

## Root Cause 2 — Security Onion Monitor Bond MTU

SPAN traffic successfully reached:

```text
ens19
```

but Suricata listened on:

```text
bond0
```

`ens19` was not participating in the monitoring bond.

The discovered MTUs were:

```text
ens19 = 1500
bond0 = 9000
```

Resolution:

```text
Proxmox nic1  = MTU 9000
Proxmox vmbr1 = MTU 9000
VM 900 net1   = MTU 9000
Security Onion ens19 → bond0
```

After correcting the capture path, Suricata immediately began decoding packets and generating alerts.

---

# 31. Final Known-Good Validation Commands

## Proxmox

```bash
ip link show nic1 | head -1
ip link show vmbr1 | head -1
qm config 900 | grep -E '^net'
bridge -compressvlans vlan show
ip -br addr
```

Expected capture MTUs:

```text
nic1  MTU 9000
vmbr1 MTU 9000
net1  MTU 9000
```

---

## Cisco

```text
show interfaces status
show interfaces trunk
show interfaces Gi1/0/27 switchport
show monitor session 1
show mac address-table dynamic
```

Expected SPAN relationship:

```text
Source:
Gi1/0/27 both

Destination:
Gi1/0/28

Encapsulation:
Replicate
```

---

## Juniper

```text
show interfaces terse
show route 192.168.66.0/24
show route 172.16.99.0/24
show arp no-resolve
show security policies from-zone ATTACKER to-zone MGMT
show configuration security policies | display set
```

---

## Security Onion

```bash
ip -br link show ens19
ip -br link show bond0

ip link show master bond0

nmcli device status

nmcli -f NAME,TYPE,DEVICE connection show | \
grep -E 'bond0|ens19'
```

Suricata interface:

```bash
sudo docker exec so-suricata sh -c \
"grep -A20 '^af-packet:' /etc/suricata/suricata.yaml"
```

Expected:

```text
interface: bond0
```

Rule deployment:

```bash
sudo docker exec so-suricata \
grep -Rni 'sid:1000001' /etc/suricata/rules 2>/dev/null
```

Suricata statistics:

```bash
sudo grep -E \
'capture.kernel_packets|decoder.pkts|detect.alert' \
/opt/so/log/suricata/stats.log | tail -15
```

All three counters should be non-zero while traffic is being mirrored.

---

# 32. End-to-End Packet Capture Validation

From Kali:

```bash
ping 172.16.99.20
```

Proxmox physical management uplink:

```bash
tcpdump -eni nic0 icmp
```

Proxmox physical SPAN NIC:

```bash
tcpdump -eni nic1 icmp
```

SPAN bridge:

```bash
tcpdump -eni vmbr1 icmp
```

Security Onion virtual sensor tap:

```bash
tcpdump -eni tap900i1 icmp
```

Security Onion physical/virtual monitoring interface:

```bash
sudo tcpdump -eni ens19 icmp
```

Security Onion monitoring bond:

```bash
sudo tcpdump -ni bond0 icmp
```

A packet visible at every point proves:

```text
Cisco SPAN
    +
Proxmox bridge
    +
Security Onion NIC
    +
Security Onion bond
```

are functioning end-to-end.

---

# 33. Final Known-Good Architecture

```text
                         ┌─────────────────────────┐
                         │       Kali Linux        │
                         │    192.168.66.50/24     │
                         └────────────┬────────────┘
                                      │
                                   Netgear
                                      │
                                      ▼
                         ┌─────────────────────────┐
                         │       Juniper SRX       │
                         │                         │
                         │ ge-0/0/5.0              │
                         │ 192.168.66.1/24         │
                         │ ATTACKER                 │
                         │                         │
                         │        Routing          │
                         │           │             │
                         │           ▼             │
                         │ ge-0/0/0.99             │
                         │ 172.16.99.1/24          │
                         │ MGMT                    │
                         └────────────┬────────────┘
                                      │
                                      ▼
                             Cisco Gi1/0/1
                                  Trunk
                                      │
                                      ▼
                               Cisco Switch
                                      │
                     ┌────────────────┴────────────────┐
                     │                                 │
                     ▼                                 ▼
                Gi1/0/27                          Gi1/0/28
              Proxmox Uplink                  SPAN Destination
              Native VLAN 99                        │
                     │                               │
                     ▼                               ▼
                   nic0                            nic1
                MTU 1500                         MTU 9000
                     │                               │
                     ▼                               ▼
                   vmbr0                           vmbr1
              172.16.99.20                      MTU 9000
                     │                               │
                     ▼                               ▼
                SO net0                         SO net1
              Management                       MTU 9000
                                                     │
                                                     ▼
                                                   ens19
                                                     │
                                                     ▼
                                                   bond0
                                                     │
                                                     ▼
                                                 Suricata
                                                     │
                                                     ▼
                                              SID 1000001
                                                     │
                                                     ▼
                                             Security Onion SOC
                                                     │
                                                     ▼
                                                ALERT ✅
```

---

# 34. Lessons Learned

1. **Packet visibility on the sensor NIC does not prove Suricata is receiving packets.**

   `tcpdump ens19` worked while:

   ```text
   capture.kernel_packets = 0
   ```

   because Suricata was listening on `bond0`.

2. **Always verify the interface configured in Suricata.**

   ```bash
   grep -A20 '^af-packet:' /etc/suricata/suricata.yaml
   ```

3. **Security Onion monitoring NICs must be correctly attached to the monitoring bond.**

4. **MTU must be consistent across the entire Security Onion capture path.**

   Final capture path:

   ```text
   nic1   9000
   vmbr1  9000
   net1   9000
   ens19  9000
   bond0  9000
   ```

5. **Management and capture paths do not need identical MTUs.**

   Management remains:

   ```text
   MTU 1500
   ```

6. **A firewall policy can make a perfectly functioning routed topology appear broken.**

   The SRX `BLOCK-KALI` rule was correctly denying Kali → MGMT traffic.

7. **Use narrow firewall exceptions rather than disabling segmentation.**

8. **SPAN tests must generate traffic that crosses the configured SPAN source.**

   Because the source was:

   ```text
   Gi1/0/27
   ```

   pinging the Juniper attacker gateway did not test the SPAN path.

9. **Trace packets hop-by-hop.**

   The most effective sequence was:

   ```text
   nic0
    ↓
   nic1
    ↓
   vmbr1
    ↓
   tap900i1
    ↓
   ens19
    ↓
   bond0
    ↓
   Suricata
   ```

10. **A deployed Suricata rule does not prove the capture engine is working.**

    SID `1000001` existed correctly while Suricata still processed zero packets.

---

# 35. Final Status

The lab is now fully operational.

```text
Kali routing                 PASS
Juniper routing              PASS
Juniper ATTACKER policy      PASS
Cisco VLAN connectivity      PASS
Cisco SPAN                   PASS
Proxmox management bridge    PASS
Proxmox capture bridge       PASS
Security Onion ens19         PASS
Security Onion bond0         PASS
Suricata AF_PACKET capture   PASS
Suricata packet decoding     PASS
Custom SID 1000001           PASS
Security Onion SOC alert     PASS
```

Final proof:

```text
capture.kernel_packets > 0
decoder.pkts           > 0
detect.alert           > 0
```

Custom detection:

```text
LAB TEST - Kali ICMP to Proxmox
SID: 1000001
Module: suricata
Severity: low
Status: ALERTING
```

## Troubleshooting Result

**Connectivity and IDS detection successfully restored end-to-end.**
