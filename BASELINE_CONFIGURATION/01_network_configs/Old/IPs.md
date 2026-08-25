&#x20;**The External Threat Boundary (Zone: ATTACKER)**

* **Subnet**: 192.168.66.0/24
* **Gateway**: 192.168.66.1 (Juniper ge-0/0/5.0)
* **Hardware**: Netgear GS308 unmanaged switch.
* **Endpoints**: Kali Linux is statically anchored here at 192.168.66.50. This segment simulates the "outside internet" and is physically and logically blind to your internal lab until its traffic is explicitly permitted through the Juniper firewall.





**The Core Infrastructure (Zone: MGMT | VLAN 99)**

* **Subnet**: 172.16.99.0/24
* **Gateway**: 172.16.99.1 (Juniper ge-0/0/0.99)
* **Hardware**: Cisco Catalyst 2960-X switch.
* **Endpoints**: This highly trusted administrative segment houses your Proxmox VE hypervisor (172.16.99.20), your Windows 11 Pro analyst station, and the management interface for your Security Onion 3.1.0 deployment.



**The Target Environment (Zone: VICTIMS | VLAN 10)**

* **Subnet**: 172.16.10.0/24
* **Gateway**: 172.16.10.1 (Juniper ge-0/0/0.10)
* **Hardware**: Virtualized inside Proxmox and passed through the Cisco 802.1Q trunk link.
* **Endpoints**: This is the blast radius. Vulnerable endpoints like your antiX Linux VMs sit here (e.g., 172.16.10.15), waiting for incoming exploit traffic to traverse the router and match the ATTACK-TRAFFIC firewall policy.



**Traffic Flow \& Sensor Visibility**

* The routing is deliberately pinned through the Juniper SRX to enforce stateful security boundaries. When Kali launches an exploit, the packets traverse the Netgear switch, pass the firewall rules, and travel down the Cisco trunk into VLAN 10. Because the topology forces all lateral movement through the physical Cisco hardware, you can easily configure the switch to SPAN (mirror) that specific VLAN 10 traffic. This allows Suricata and your SIEM to ingest the raw network data for custom detection rule tuning.

