\# The Network Backbone — `/etc/network/interfaces`



This configuration defines the finalized Layer 2 transport architecture for the Proxmox VE hypervisor.



The two physical interfaces have completely separate responsibilities:



\* \*\*`nic0` → `vmbr0` → Cisco Gi1/0/27\*\*

&#x20; Carries Proxmox management traffic on VLAN 99 and VLAN-tagged virtual-machine traffic such as the VLAN 10 victim network.



\* \*\*`nic1` → `vmbr1` → Cisco Gi1/0/28\*\*

&#x20; Provides a dedicated passive monitoring path for Cisco SPAN traffic destined for the Security Onion sensor.



`vmbr0` is configured as a \*\*VLAN-aware Linux bridge\*\*, allowing the hypervisor to transport multiple Layer 2 VLANs over the same physical uplink.



`vmbr1` is intentionally configured with \*\*MAC address learning disabled\*\* using `bridge-ageing 0`. This prevents the monitoring bridge from behaving like a conventional learned Ethernet switch and ensures mirrored traffic is forwarded toward the Security Onion capture interface.



> \*\*Important:\*\* `vmbr1` must not have an IP address, default gateway, or VLAN tag. It exists exclusively as a passive Layer 2 transport path for mirrored traffic.



\---



\## 1. Configure `/etc/network/interfaces`



Open the Proxmox network configuration:



```bash

nano /etc/network/interfaces

```



Replace or verify the configuration as follows:



```text

auto lo

iface lo inet loopback





\# ============================================================

\# PHYSICAL INTERFACES

\# ============================================================



iface nic0 inet manual



iface nic1 inet manual





\# ============================================================

\# CABLE 1 — MANAGEMENT + LIVE VM TRAFFIC

\# Proxmox nic0 <-> Cisco Catalyst Gi1/0/27

\#

\# Native/Untagged VLAN: 99

\# Tagged VLAN:          10

\# ============================================================



auto vmbr0

iface vmbr0 inet static

&#x20;       address 172.16.99.20/24

&#x20;       gateway 172.16.99.1

&#x20;       bridge-ports nic0

&#x20;       bridge-stp off

&#x20;       bridge-fd 0

&#x20;       bridge-vlan-aware yes

&#x20;       bridge-vids 2-4094





\# ============================================================

\# CABLE 2 — SECURITY ONION SPAN / CAPTURE TRAFFIC

\# Proxmox nic1 <-> Cisco Catalyst Gi1/0/28

\#

\# No IP Address

\# No Gateway

\# No VLAN Tag

\# MAC Learning Disabled

\# ============================================================



auto vmbr1

iface vmbr1 inet manual

&#x20;       bridge-ports nic1

&#x20;       bridge-stp off

&#x20;       bridge-fd 0

&#x20;       bridge-ageing 0





\# ============================================================

\# ADDITIONAL PROXMOX NETWORK CONFIGURATION

\# ============================================================



source /etc/network/interfaces.d/\*

```



\### Network Path Summary



```text

&#x20;                   CISCO CATALYST 2960-X

&#x20;                          │

&#x20;            ┌─────────────┴─────────────┐

&#x20;            │                           │

&#x20;        Gi1/0/27                    Gi1/0/28

&#x20;     Management / VM                    │

&#x20;        VLAN Traffic                    │

&#x20;            │                       SPAN Output

&#x20;            │                           │

&#x20;          nic0                        nic1

&#x20;            │                           │

&#x20;            ▼                           ▼

&#x20;          vmbr0                       vmbr1

&#x20;      VLAN-Aware Bridge          Capture-Only Bridge

&#x20;            │                           │

&#x20;      ┌─────┴──────┐                    │

&#x20;      │            │                    │

&#x20; Proxmox Host   VM net0          Security Onion net1

&#x20; 172.16.99.20    │                    ens19

&#x20;                 │                     │

&#x20;          ┌──────┴───────┐             │

&#x20;          │              │             │

&#x20;     Security Onion    antiX           │

&#x20;         ens18          VLAN 10         │

&#x20;     172.16.99.30   172.16.10.15       │

&#x20;                                         

&#x20;                                 Passive Packet Capture

&#x20;                              Suricata / Zeek / Strelka

```



\---



\## 2. Physical Hardware and Storage Profile



\### Proxmox Administrative Access



The Proxmox VE management plane resides on:



```text

VLAN:       99

Subnet:     172.16.99.0/24

Proxmox IP: 172.16.99.20

Gateway:    172.16.99.1

```



The hypervisor can be administered through either the Proxmox Web GUI or SSH.



\### Web Management



```text

https://172.16.99.20:8006

```



\### SSH Management



```bash

ssh root@172.16.99.20

```



\---



\### Physical Interface Mapping



| Interface | MAC Address         | Cisco Port | Purpose                               |

| --------- | ------------------- | ---------- | ------------------------------------- |

| `nic0`    | `fc:9d:05:05:87:6c` | Gi1/0/27   | Management + VLAN-aware VM traffic    |

| `nic1`    | `6c:6e:07:50:e9:18` | Gi1/0/28   | Dedicated Security Onion SPAN capture |



The physical cabling must remain consistent with this mapping.



\### Cable 1



```text

Proxmox nic0

&#x20;    │

&#x20;    └──────────── Cisco Gi1/0/27

&#x20;                  Management + VM Traffic

&#x20;                  Native VLAN 99

&#x20;                  Tagged VLAN 10

```



\### Cable 2



```text

Proxmox nic1

&#x20;    │

&#x20;    └──────────── Cisco Gi1/0/28

&#x20;                  SPAN Destination

&#x20;                  Passive Capture Only

```



> \*\*Do not reverse these cables.\*\*

> Cisco Gi1/0/28 is a SPAN destination and should not be used for normal Proxmox management or virtual-machine connectivity.



\---



\## External Security Onion Storage



Security Onion is stored on a dedicated \*\*1 TB high-speed external SSD\*\* to isolate its high-volume packet capture, telemetry, Elasticsearch, and log I/O from the primary Proxmox system disk.



The SSD is:



\* Formatted as `ext4`.

\* Configured through the Proxmox storage interface as a \*\*Directory\*\* storage target.

\* Mounted and registered as:



```text

SecOnion-Storage

```



This storage is reserved primarily for the Security Onion VM.



\---



\# 3. Virtual Machine Hardware Bindings



\## Victim Systems — antiX Linux VMs



The antiX Linux systems represent hosts located inside the \*\*VICTIMS security zone\*\*.



\### Storage



```text

Storage: local-lvm

```



The victim systems remain on the primary Proxmox storage pool because they do not require the sustained storage I/O expected from Security Onion.



\### Network Configuration



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

&#x20;     │

&#x20;   net0

&#x20;     │

&#x20;VLAN Tag 10

&#x20;     │

&#x20;   vmbr0

&#x20;     │

&#x20;   nic0

&#x20;     │

Cisco Gi1/0/27

&#x20;     │

&#x20;   VLAN 10

&#x20;     │

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



\### Proxmox Firewall



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



\---



\# Security Onion 3.2.0 Sensor Node



Security Onion is deployed as a dual-interface monitoring system.



The VM has completely separate interfaces for:



1\. \*\*Management\*\*

2\. \*\*Passive packet acquisition\*\*



This separation is fundamental to the architecture.



\---



\## Security Onion Storage



```text

Storage: SecOnion-Storage

```



The Security Onion VM is installed entirely on the dedicated external SSD.



This provides additional I/O capacity for:



\* Elasticsearch data

\* Suricata telemetry

\* Zeek telemetry

\* Full packet capture

\* Strelka analysis

\* Alert data

\* Case data

\* Log retention



\---



\## Security Onion Management NIC — `net0`



```text

Device:     net0

Bridge:     vmbr0

VLAN Tag:   Blank

Firewall:   Enabled

Guest NIC:  ens18

IP Address: 172.16.99.30/24

Gateway:    172.16.99.1

```



\### Why the VLAN Tag Is Blank



Cisco Gi1/0/27 uses \*\*VLAN 99 as its native VLAN\*\* for management traffic.



Therefore, Security Onion management traffic is transmitted untagged from the VM:



```text

Security Onion ens18

&#x20;       │

&#x20;     net0

&#x20;       │

&#x20;  No VLAN Tag

&#x20;       │

&#x20;     vmbr0

&#x20;       │

&#x20;      nic0

&#x20;       │

&#x20;Cisco Gi1/0/27

&#x20;       │

&#x20;Native VLAN 99

&#x20;       │

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



> Do \*\*not\*\* configure `tag=99` on the Security Onion management NIC when Cisco Gi1/0/27 is using VLAN 99 as the native/untagged VLAN.



\---



\## Security Onion Capture NIC — `net1`



```text

Device:     net1

Bridge:     vmbr1

VLAN Tag:   Blank

Firewall:   Disabled

Guest NIC:  ens19

IP Address: NONE

Gateway:    NONE

```



This interface exists solely to receive Cisco SPAN traffic.



The complete telemetry path is:



```text

&#x20;                VLAN 10 Traffic

&#x20;                      │

&#x20;                      ▼

&#x20;               Cisco Catalyst

&#x20;                      │

&#x20;           SPAN Source: VLAN 10

&#x20;                      │

&#x20;                      ▼

&#x20;                 Gi1/0/28

&#x20;              SPAN Destination

&#x20;                      │

&#x20;                      ▼

&#x20;                   nic1

&#x20;                      │

&#x20;                      ▼

&#x20;                   vmbr1

&#x20;             MAC Learning Disabled

&#x20;                      │

&#x20;                      ▼

&#x20;             Security Onion net1

&#x20;                      │

&#x20;                      ▼

&#x20;                    ens19

&#x20;                      │

&#x20;            ┌─────────┴─────────┐

&#x20;            │                   │

&#x20;         Suricata              Zeek

&#x20;            │                   │

&#x20;      IDS Detection       Network Metadata

```



The capture interface must remain:



```text

No IP address

No default gateway

No Proxmox VLAN tag

No Proxmox firewall

```



This prevents the monitoring interface from becoming an active participant in the network it is observing.



\---



\# 4. Final VM Network Matrix



| System         | VM NIC | Proxmox Bridge |  VLAN Tag | Guest IP          | Purpose               |

| -------------- | ------ | -------------- | --------: | ----------------- | --------------------- |

| Proxmox VE     | Host   | `vmbr0`        | Native 99 | `172.16.99.20/24` | Hypervisor management |

| antiX Linux    | `net0` | `vmbr0`        |      `10` | `172.16.10.15/24` | Victim system         |

| Security Onion | `net0` | `vmbr0`        | \*\*Blank\*\* | `172.16.99.30/24` | Management            |

| Security Onion | `net1` | `vmbr1`        | \*\*Blank\*\* | \*\*None\*\*          | Passive SPAN capture  |



\---



\# 5. Final Physical Port Matrix



| Cisco Port | Connected Device       | Function                       |

| ---------- | ---------------------- | ------------------------------ |

| Gi1/0/1    | Juniper SRX300         | 802.1Q trunk                   |

| Gi1/0/27   | Proxmox `nic0`         | Management + VM VLAN traffic   |

| Gi1/0/28   | Proxmox `nic1`         | \*\*Dedicated SPAN destination\*\* |

| Gi1/0/47   | Windows 11 workstation | VLAN 99 management access      |



The Cisco SPAN relationship must therefore be:



```text

Source:

&#x20;   VLAN 10

&#x20;   RX + TX



Destination:

&#x20;   GigabitEthernet1/0/28

```



The Proxmox management/live-traffic connection remains:



```text

GigabitEthernet1/0/27

&#x20;       │

&#x20;      nic0

&#x20;       │

&#x20;     vmbr0

```



while packet telemetry follows the physically isolated path:



```text

VLAN 10

&#x20;  │

Cisco SPAN

&#x20;  │

Gi1/0/28

&#x20;  │

&#x20;nic1

&#x20;  │

vmbr1

&#x20;  │

Security Onion net1 / ens19

&#x20;  │

Suricata + Zeek

```



\---



\## 6. Post-Configuration Verification



After applying the configuration, verify the bridges:



```bash

ip -br addr

```



Verify bridge membership:



```bash

bridge link

```



Verify VLAN handling:



```bash

bridge vlan show

```



Verify the Proxmox routing table:



```bash

ip route

```



The only default route should use the management network:



```text

default via 172.16.99.1 dev vmbr0

```



Verify `vmbr1` has no Layer 3 address:



```bash

ip addr show vmbr1

```



It should not contain an IPv4 address.



Verify the physical capture interface:



```bash

ip link show nic1

```



Verify SPAN traffic directly on the Proxmox host:



```bash

tcpdump -ni nic1 -c 20

```



Then verify traffic reaches the monitoring bridge:



```bash

tcpdump -ni vmbr1 -c 20

```



Finally, after Security Onion is installed, verify the same traffic reaches its capture interface:



```bash

sudo tcpdump -ni ens19 -c 20

```



The expected telemetry path is:



```text

Cisco VLAN 10

&#x20;     │

&#x20;     ▼

Cisco SPAN

&#x20;     │

&#x20;     ▼

Gi1/0/28

&#x20;     │

&#x20;     ▼

Proxmox nic1

&#x20;     │

&#x20;     ▼

vmbr1

&#x20;     │

&#x20;     ▼

Security Onion ens19

&#x20;     │

&#x20;     ├── Suricata

&#x20;     └── Zeek

```



Once all three packet-capture tests show traffic, the Layer 2 monitoring backbone is functioning correctly.

