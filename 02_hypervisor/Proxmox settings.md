1. **The Network Backbone (/etc/network/interfaces)**


This is the finalized Layer 2 routing logic. vmbr0 is officially VLAN-aware to successfully route your management and victim traffic, while vmbr1 is permanently locked into a "dumb hub" state to flood SPAN traffic to your sensor.

- *nano /etc/network/interfaces*

auto lo

iface lo inet loopback



iface nic0 inet manual



iface nic1 inet manual



\# --- CABLE 1: MANAGEMENT \& LIVE TRAFFIC (To Cisco Port 26) ---

auto vmbr0

iface vmbr0 inet static

&#x20;       address 172.16.99.20/24

&#x20;       gateway 172.16.99.1

&#x20;       bridge-ports nic0

&#x20;       bridge-stp off

&#x20;       bridge-fd 0

&#x20;       bridge-vlan-aware yes

&#x20;       bridge-vids 2-4094



\# --- CABLE 2: SPAN / CAPTURE TRAFFIC (To Cisco Port 27) ---

auto vmbr1

iface vmbr1 inet manual

&#x20;       bridge-ports nic1

&#x20;       bridge-stp off

&#x20;       bridge-fd 0

&#x20;       bridge-ageing 0



source /etc/network/interfaces.d/\*





**2. Physical Hardware \& Storage Profile**

* Proxmox Administrative Access: Available natively via Web GUI (\[https://172.16.99.20:8006](https://172.16.99.20:8006)) and root SSH over VLAN 99.
* Management MAC Address (nic0): fc:9d:05:05:87:6c
* Capture MAC Address (nic1): 6c:6e:07:50:e9:18
* External Logging Storage: 1TB external fast SSD, formatted via the Proxmox GUI as an ext4 Directory and mounted as SecOnion-Storage.





**3. Virtual Machine Hardware Bindings**



**The Target Nodes (antiX Linux VMs)**



* Storage: Installed on the primary hypervisor drive (local-lvm).
* Network Device (net0): Bound to vmbr0.
* VLAN Tag: 10 (Forces the machine into the 172.16.10.0/24 VICTIMS zone).
* Proxmox Firewall: Unchecked (Must be disabled so raw exploit traffic successfully hits the guest OS).



**The Sensor Node (Security Onion 3.1.0)**



* Storage: Installed entirely on the SecOnion-Storage drive to handle high log I/O.
* Management NIC (net0): Bound to vmbr0, VLAN Tag 99 (or left blank if Cisco Port 26 is configured as an access port), Proxmox Firewall Checked.
* Capture NIC (net1): Bound to vmbr1, VLAN Tag left blank (requires raw, untagged frames), Proxmox Firewall Unchecked.

