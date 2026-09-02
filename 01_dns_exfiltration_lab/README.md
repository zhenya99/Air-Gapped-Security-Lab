> **Current scope, confirmed 2026-09-02:** This lab is for Splunk detection engineering. Security Onion is the only deployed VM; antiX and Splunk are not installed. The analyst and Kali intentionally use separate Internet adapters. The Fios router is unplugged and reserved for later wireless experiments.
>
> Start with [the Cisco/Juniper setup runbook](02_network_changes.md), [the corrected architecture](01_architecture.md), and [rollback](12_rollback.md). The configurations are prepared for review and have not been applied to devices. The historical overview below describes planned additions.

\# DNS Exfiltration Detection Lab



\## Overview



This lab extends the existing \*\*Air-Gapped Security Lab\*\* with a controlled DNS exfiltration scenario designed to prepare the environment for later \*\*Splunk Detection Engineering\*\*.



The existing lab configuration under `BASELINE\_CONFIGURATION/` remains the authoritative \*\*known-good rollback state\*\*.



All infrastructure changes, new virtual machines, detection logic, telemetry configuration, scripts, evidence, and rollback procedures required specifically for this DNS lab are documented only inside:



```text

01\_dns\_exfiltration\_lab/

```



The baseline configuration is not modified to reflect DNS-lab-specific changes.



\---



\## Lab Objectives



The objectives of this lab are to:



1\. Extend the existing segmented network with a dedicated DNS laboratory VLAN.

2\. Deploy a Windows 11 victim system on the existing VICTIMS network.

3\. Deploy a controlled Linux DNS server on a dedicated DNS network.

4\. Route DNS traffic through the existing Juniper SRX.

5\. Preserve the existing Cisco SPAN and Security Onion monitoring architecture.

6\. Capture DNS traffic with Security Onion.

7\. Generate a normal DNS traffic baseline.

8\. Generate controlled DNS exfiltration-style traffic using synthetic laboratory data.

9\. Observe DNS activity through multiple telemetry sources.

10\. Develop and validate network-based detections.

11\. Instrument the Windows victim with Sysmon for endpoint telemetry.

12\. Prepare the resulting telemetry for future ingestion and correlation in Splunk.



\---



\## Existing Baseline



The DNS lab begins from the existing known-good environment stored under:



```text

BASELINE\_CONFIGURATION/

```



The current baseline contains three routed security networks:



```text

ATTACKER

192.168.66.0/24

Gateway: 192.168.66.1



VICTIMS — VLAN 10

172.16.10.0/24

Gateway: 172.16.10.1



MGMT — VLAN 99

172.16.99.0/24

Gateway: 172.16.99.1

```



The existing attacker host is Kali Linux:



```text

Kali

192.168.66.50/24

```



The existing management infrastructure includes:



```text

Juniper SRX        172.16.99.1

Cisco Catalyst     172.16.99.2

Windows Analyst    172.16.99.10

Proxmox VE         172.16.99.20

Security Onion     172.16.99.30

```



The existing Security Onion monitoring path remains unchanged:



```text

Cisco Gi1/0/27

&#x20;     |

&#x20;     | SPAN source — both directions

&#x20;     |

&#x20;     +-----------------------> Cisco Gi1/0/28

&#x20;                                     |

&#x20;                                     v

&#x20;                                 Proxmox nic1

&#x20;                                     |

&#x20;                                   vmbr1

&#x20;                                     |

&#x20;                               VM 900 net1

&#x20;                                     |

&#x20;                                   ens19

&#x20;                                     |

&#x20;                                   bond0

&#x20;                                /         \\

&#x20;                           Suricata       Zeek

```



\---



\## DNS Lab Additions



This lab introduces the following planned components.



\### VLAN 20 — DNS-LAB



```text

VLAN:       20

Name:       DNS\_LAB

Subnet:     172.16.20.0/24

Gateway:    172.16.20.1

```



\### Windows 11 Victim



```text

VMID:       910

Hostname:   DNS-WIN11-VICTIM

Network:    VLAN 10

IP:         172.16.10.50/24

Gateway:    172.16.10.1

```



\### Ubuntu DNS Server



```text

VMID:       920

Hostname:   DNS-LAB-SERVER

Network:    VLAN 20

IP:         172.16.20.53/24

Gateway:    172.16.20.1

Service:    BIND9

```



The laboratory DNS namespace will use:



```text

exfil.test

```



The `.test` namespace is used only for controlled laboratory traffic.



\---



\## Target Traffic Flow



The primary DNS path will be:



```text

Windows 11 Victim

172.16.10.50

VLAN 10

&#x20;     |

&#x20;     v

Juniper SRX

172.16.10.1

&#x20;     |

&#x20;     | inter-VLAN routing

&#x20;     |

&#x20;     v

Juniper VLAN 20

172.16.20.1

&#x20;     |

&#x20;     v

Ubuntu DNS Server

172.16.20.53

```



The traffic crosses the existing Proxmox uplink and therefore remains observable through the existing Cisco SPAN architecture.



\---



\## Detection Telemetry



The lab is designed to produce several independent views of the same DNS activity.



\### Endpoint Telemetry



Windows 11:



```text

Sysmon

Windows Event Logs

PowerShell logging

Process creation

DNS queries

Network connections

```



\### Network Telemetry



Security Onion:



```text

Zeek DNS telemetry

Suricata

Packet capture

```



\### DNS Server Telemetry



Ubuntu/BIND:



```text

DNS query logs

Client address

Queried domain

Record type

Timestamp

```



These telemetry sources will later provide the foundation for Splunk correlation and detection engineering.



\---



\## Repository Structure



```text

01\_dns\_exfiltration\_lab/

│

├── README.md

├── 01\_architecture.md

├── 02\_network\_changes.md

├── 03\_proxmox\_vms.md

├── 04\_windows11\_victim.md

├── 05\_dns\_server.md

├── 06\_sysmon\_telemetry.md

├── 07\_dns\_baseline.md

├── 08\_dns\_exfiltration\_simulation.md

├── 09\_security\_onion\_validation.md

├── 10\_detection\_engineering.md

├── 11\_results.md

├── 12\_rollback.md

│

├── configs/

├── diagrams/

├── evidence/

└── scripts/

```



\---



\## Documentation Model



Each part of the lab has a specific purpose:



```text

Markdown documentation

&#x20;       |

&#x20;       +---- What was built

&#x20;       +---- Why it was built

&#x20;       +---- Commands used

&#x20;       +---- Validation performed

&#x20;       +---- Problems encountered

&#x20;       +---- Final known-good state



configs/

&#x20;       |

&#x20;       +---- Exact configuration changes



scripts/

&#x20;       |

&#x20;       +---- Executable laboratory scripts



evidence/

&#x20;       |

&#x20;       +---- PCAPs

&#x20;       +---- Logs

&#x20;       +---- Screenshots

&#x20;       +---- Validation output



diagrams/

&#x20;       |

&#x20;       +---- DNS-lab-specific architecture diagrams

```



\---



\## Build Sequence



The lab will be constructed in the following order:



```text

1\. Document architecture

&#x20;       |

&#x20;       v

2\. Extend network with VLAN 20

&#x20;       |

&#x20;       v

3\. Create Proxmox VMs

&#x20;       |

&#x20;       v

4\. Configure Windows 11 victim

&#x20;       |

&#x20;       v

5\. Configure Ubuntu/BIND DNS

&#x20;       |

&#x20;       v

6\. Install Sysmon telemetry

&#x20;       |

&#x20;       v

7\. Establish normal DNS baseline

&#x20;       |

&#x20;       v

8\. Generate controlled DNS exfiltration traffic

&#x20;       |

&#x20;       v

9\. Validate Security Onion visibility

&#x20;       |

&#x20;       v

10\. Develop detections

&#x20;       |

&#x20;       v

11\. Record results

&#x20;       |

&#x20;       v

12\. Validate rollback procedure

```



\---



\## Safety and Scope



This environment is designed for isolated laboratory use.



DNS exfiltration simulations will use:



\* synthetic data;

\* reserved laboratory namespaces;

\* internal systems;

\* controlled network paths;

\* explicit validation and rollback procedures.



No production information is required for the exercises.



\---



\## Rollback Principle



`BASELINE\_CONFIGURATION/` represents the original known-good environment.



The DNS lab is treated as a set of additions to that environment:



```text

BASELINE

&#x20;  |

&#x20;  + VLAN 20

&#x20;  + Windows VM 910

&#x20;  + Ubuntu VM 920

&#x20;  + DNS-LAB Juniper zone

&#x20;  + DNS-specific security policies

&#x20;  + BIND

&#x20;  + Sysmon

&#x20;  + DNS detections

&#x20;  |

&#x20;  v

DNS EXFILTRATION LAB

```



The rollback procedure in:



```text

12\_rollback.md

```



will remove these additions and return the infrastructure to the documented baseline state.



\---



\## End Goal



At completion, the environment should provide a repeatable chain from:



```text

Controlled activity

&#x20;       |

&#x20;       v

Endpoint telemetry

&#x20;       |

&#x20;       v

DNS network traffic

&#x20;       |

&#x20;       v

Security Onion

&#x20;       |

&#x20;       +---- Zeek

&#x20;       +---- Suricata

&#x20;       +---- PCAP

&#x20;       |

&#x20;       v

Detection development

&#x20;       |

&#x20;       v

Future Splunk ingestion

&#x20;       |

&#x20;       v

Splunk Detection Engineering

```



The DNS exfiltration lab therefore serves as the telemetry and detection-development prerequisite for the next stage of the project.



