## **# Engineering an Air-Gapped Stateful Security Lab: From Attack Traffic to Detection**

## 

## **I built an isolated security research lab designed to make every security control observable, testable, and repeatable. The environment combines a physical \*\*Juniper SRX300\*\*, \*\*Cisco Catalyst 2960-X\*\*, \*\*Proxmox VE\*\*, \*\*Kali Linux\*\*, \*\*antiX Linux\*\*, \*\*Security Onion 3.1.0\*\*, \*\*Windows 11\*\*, and \*\*Splunk\*\* into a controlled threat-analysis platform.**

## 

## **## The Engineering Objective**

## **\*\*Don't just simulate the network. Force the traffic through the real security boundaries.\*\***

## 

## **Attack traffic is generated from the Kali environment, routed through the Juniper SRX300 stateful firewall, transported across Cisco 802.1Q VLANs, delivered into an isolated victim segment, mirrored through a dedicated SPAN interface, captured by Security Onion, and analyzed through SIEM-driven threat hunting.**

## 

## **## Core Capabilities Demonstrated**

## **\* \*\*Stateful Enforcement:\*\* `ATTACKER` → `VICTIMS` traffic is permitted and observed.**

## **\* \*\*Explicit Denial:\*\* `ATTACKER` → `MGMT` initiation is explicitly denied and logged.**

## **\* \*\*Layer 2 Segmentation:\*\* Cisco VLAN segmentation and SPAN telemetry.**

## **\* \*\*Hypervisor Bridging:\*\* Proxmox VLAN-aware and capture-only bridges.**

## **\* \*\*Sensor Visibility:\*\* Dedicated out-of-band packet capture.**

## **\* \*\*Command Center:\*\* Windows dual-homed analyst operations.**

## **\* \*\*Threat Hunting:\*\* DNS-exfiltration hunting utilizing Splunk.**

## **\* \*\*End-to-End Validation:\*\* From raw packet flow to SIEM detection.**

## 

## **## Critical Traffic Separation**

## **One of the most important engineering corrections in this architecture is the strict physical separation of the Proxmox paths to ensure management traffic and mirrored frames never mix:**

## **\* \*\*Cisco Gi1/0/27 → Proxmox nic0 / vmbr0:\*\* Management + live VLAN traffic.**

## **\* \*\*Cisco Gi1/0/28 → Proxmox nic1 / vmbr1:\*\* Security Onion SPAN/capture feed.**

## 

## **> \*This project is a practical demonstration of how network engineering, infrastructure security, packet analysis, and SOC operations converge into one observable security system. Every control should be configurable. Every control should be testable. And every test should generate evidence.\***

