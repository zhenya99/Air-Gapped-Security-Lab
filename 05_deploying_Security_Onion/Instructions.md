# \# Security Onion v3.2.0 Deployment Guide

# 

# \## Overview

# 

# Deploying \*\*Security Onion 3.2.x\*\* requires precise interface alignment so that mirrored \*\*VLAN 10 traffic\*\* successfully reaches the \*\*Suricata\*\* and \*\*Zeek\*\* sensors.

# 

# This guide documents the recommended Proxmox VM configuration, base OS installation, network configuration, and Security Onion setup.

# 

# \---

# 

# \## 1. VM Provisioning in Proxmox

# 

# Before booting the Security Onion ISO, configure the virtual hardware to match the required network segmentation and storage layout.

# 

# \### Verify Proxmox Host Resources

# 

# From the Proxmox shell:

# 

# ```bash

# ssh root@lab

# 

# lscpu

# pvesh get /nodes/localhost/status

# free -h

# df -h

# lsblk

# ```

# 

# \### Host Hardware

# 

# The lab host is equipped with:

# 

# \* \*\*CPU:\*\* Intel Core i7-12700K

# 

# &#x20; \* 8 Performance cores

# &#x20; \* 4 Efficient cores

# &#x20; \* 20 logical threads with Hyper-Threading

# \* \*\*Memory:\*\* 46 GB RAM

# \* \*\*Internal Storage:\*\* 240 GB SSD

# \* \*\*External Storage:\*\* 1 TB SSD

# 

# > \*\*Note:\*\* Because the host has approximately 46 GB of RAM, allocate resources carefully. Security Onion is resource-intensive, particularly when running Suricata, Zeek, Elasticsearch/OpenSearch components, and the SOC interface together.

# 

# \---

# 

# \## 2. Security Onion VM Blueprint

# 

# \### CPU

# 

# Allocate:

# 

# ```text

# 8–12 CPU cores

# ```

# 

# Under the Proxmox \*\*Advanced CPU\*\* settings, use:

# 

# ```text

# CPU Type: host

# ```

# 

# Using `host` exposes the host CPU features to the VM and can provide better performance than the generic `kvm64` CPU model.

# 

# \### Memory

# 

# Recommended allocation:

# 

# ```text

# 24–28 GB RAM

# ```

# 

# Equivalent values:

# 

# ```text

# 24576 MB – 28672 MB

# ```

# 

# Disable \*\*Memory Ballooning\*\* so the assigned memory remains dedicated to the Security Onion VM.

# 

# \### Storage

# 

# Allocate approximately:

# 

# ```text

# 250–500 GB

# ```

# 

# Place the Security Onion storage on the \*\*1 TB external SSD\*\*.

# 

# This is preferable because Security Onion can generate substantial amounts of:

# 

# \* Network metadata

# \* Zeek logs

# \* Suricata alerts

# \* Elasticsearch/OpenSearch data

# \* Packet-related data

# \* SOC telemetry

# 

# \### Network Interfaces

# 

# Configure two virtual network interfaces.

# 

# | Interface | Purpose        | Proxmox Bridge | VLAN Tag | Firewall |

# | --------- | -------------- | -------------- | -------- | -------- |

# | NIC 1     | Management     | `vmbr0`        | `99`     | Enabled  |

# | NIC 2     | Packet Capture | `vmbr1`        | Blank    | Disabled |

# 

# \### Management Interface

# 

# ```text

# Bridge: vmbr0

# VLAN Tag: 99

# Firewall: Enabled

# ```

# 

# This interface provides management connectivity to the Security Onion host.

# 

# \### Capture Interface

# 

# ```text

# Bridge: vmbr1

# VLAN Tag: <Leave Blank>

# Firewall: Disabled

# ```

# 

# The capture interface should receive the mirrored network traffic.

# 

# > \*\*Important:\*\* Do not apply a VLAN tag directly to the Security Onion capture NIC when the Proxmox bridge is already delivering the required mirrored traffic. The capture interface should remain dedicated to monitoring traffic rather than normal management communication.

# 

# \---

# 

# \# 3. Base OS Installation

# 

# Boot the Security Onion VM using the \*\*Security Onion 3.2.0 ISO\*\*.

# 

# \### Installation Steps

# 

# 1\. Start the VM.

# 2\. Boot from the Security Onion ISO.

# 3\. Select:

# 

# ```text

# Install Security Onion

# ```

# 

# 4\. Follow the operating-system installation prompts.

# 5\. Create the administrative OS account and password.

# 6\. Record the credentials securely.

# 7\. Allow the installation to complete.

# 8\. Reboot the VM when prompted.

# 

# > \*\*Important:\*\* The OS credentials created during installation are required for subsequent administrative configuration.

# 

# \---

# 

# \# 4. Network Configuration

# 

# After the VM reboots, log in using the administrative OS credentials.

# 

# Run:

# 

# ```bash

# sudo so-setup-network

# ```

# 

# Select the \*\*Management Interface\*\*.

# 

# Depending on the VM's interface naming, this may appear as:

# 

# ```text

# ens18

# ```

# 

# or:

# 

# ```text

# eth0

# ```

# 

# Do not assume the interface name. Verify the actual interface assignment in the VM before configuring it.

# 

# \---

# 

# \## 5. Management Interface Configuration

# 

# Configure the management interface with a static IPv4 configuration.

# 

# \### IP Configuration

# 

# ```text

# IP Address:   172.16.99.30

# Subnet Mask:  255.255.255.0

# Gateway:      172.16.99.1

# DNS:          8.8.8.8

# ```

# 

# Alternatively, use the lab's internal DNS resolver if one is available.

# 

# The resulting management network is:

# 

# ```text

# Network:      172.16.99.0/24

# Security Onion: 172.16.99.30

# Gateway:      172.16.99.1

# ```

# 

# After applying the network configuration, reboot the VM:

# 

# ```bash

# sudo reboot

# ```

# 

# \---

# 

# \# 6. Security Onion Application Setup

# 

# After the system reboots, log back into the Security Onion console.

# 

# Run:

# 

# ```bash

# sudo so-setup

# ```

# 

# Follow the setup wizard.

# 

# \### Deployment Type

# 

# Select:

# 

# ```text

# Install

# ```

# 

# Then select:

# 

# ```text

# Standalone

# ```

# 

# The standalone deployment installs the primary Security Onion components on the same system.

# 

# Select:

# 

# ```text

# Standard

# ```

# 

# when prompted for the deployment configuration.

# 

# \---

# 

# \# 7. Select the Monitoring Interface

# 

# When prompted to select the monitoring/capture interface, select the \*\*second network interface\*\*.

# 

# Depending on the VM configuration, this may appear as:

# 

# ```text

# ens19

# ```

# 

# or:

# 

# ```text

# eth1

# ```

# 

# Again, verify the actual interface name rather than assuming it.

# 

# The architecture should conceptually be:

# 

# ```text

# &#x20;                MANAGEMENT NETWORK

# &#x20;                      VLAN 99

# &#x20;                         |

# &#x20;                         |

# &#x20;                   +-----------+

# &#x20;                   | Security  |

# &#x20;                   |  Onion    |

# &#x20;                   |    VM     |

# &#x20;                   +-----------+

# &#x20;                    |         |

# &#x20;             NIC 1  |         |  NIC 2

# &#x20;                    |         |

# &#x20;                 vmbr0       vmbr1

# &#x20;                    |         |

# &#x20;                 VLAN 99   MIRRORED TRAFFIC

# &#x20;                              |

# &#x20;                           VLAN 10

# ```

# 

# The first NIC handles management traffic.

# 

# The second NIC is dedicated to network monitoring/capture.

# 

# \---

# 

# \# 8. Web/SOC Administrator Configuration

# 

# During the `so-setup` process:

# 

# 1\. Configure the Security Onion administrator email address.

# 2\. Configure the administrator password.

# 3\. Confirm the deployment settings.

# 4\. Allow the installer to deploy the required Security Onion services.

# 5\. Allow the required containerized components to initialize.

# 6\. Wait for the installation to complete.

# 

# The deployment may take a significant amount of time depending on:

# 

# \* CPU allocation

# \* RAM allocation

# \* SSD performance

# \* Internet connectivity

# \* Container/image download speed

# 

# Do not interrupt the installation while the services are being deployed.

# 

# \---

# 

# \# 9. Accessing the Security Onion SOC

# 

# Once installation is complete, access the Security Onion web interface from the Windows workstation.

# 

# Use:

# 

# ```text

# https://172.16.99.30

# ```

# 

# The browser may initially display a certificate warning because the environment uses a lab/self-signed certificate.

# 

# Authenticate using the administrator credentials created during the Security Onion setup.

# 

# \---

# 

# \# 10. Final Architecture

# 

# The completed lab should provide a clear separation between \*\*management traffic\*\* and \*\*security-monitoring traffic\*\*.

# 

# ```text

# &#x20;                        PROXMOX HOST

# &#x20;                             |

# &#x20;             +---------------+---------------+

# &#x20;             |                               |

# &#x20;         vmbr0 / VLAN 99                 vmbr1

# &#x20;             |                               |

# &#x20;             |                        Mirrored Traffic

# &#x20;             |                               |

# &#x20;             |                            VLAN 10

# &#x20;             |                               |

# &#x20;       +-----+-------------------------------+-----+

# &#x20;       |          SECURITY ONION VM                 |

# &#x20;       |                                             |

# &#x20;       |  NIC 1                    NIC 2             |

# &#x20;       |  Management               Monitoring        |

# &#x20;       |                                             |

# &#x20;       |  172.16.99.30             Capture Only      |

# &#x20;       |       |                         |            |

# &#x20;       |       |                         +------------+

# &#x20;       |       |                                      |

# &#x20;       |       +--> SOC / Administration              |

# &#x20;       |                                              |

# &#x20;       |       Suricata + Zeek + Security Onion      |

# &#x20;       +----------------------------------------------+

# ```

# 

# \---

# 

# \# 11. Validation Checklist

# 

# Before considering the deployment complete, verify the following.

# 

# \### Proxmox

# 

# \* \[ ] Security Onion VM has 8–12 CPU cores.

# \* \[ ] CPU type is set to `host`.

# \* \[ ] VM has 24–28 GB RAM.

# \* \[ ] Memory ballooning is disabled.

# \* \[ ] VM storage is located on the intended SSD.

# \* \[ ] Management NIC is connected to `vmbr0`.

# \* \[ ] Management NIC uses VLAN `99`.

# \* \[ ] Management NIC firewall is enabled.

# \* \[ ] Capture NIC is connected to `vmbr1`.

# \* \[ ] Capture NIC VLAN tag is blank.

# \* \[ ] Capture NIC firewall is disabled.

# 

# \### Security Onion

# 

# \* \[ ] Management interface has the correct static IP.

# \* \[ ] Management IP is `172.16.99.30`.

# \* \[ ] Subnet mask is `255.255.255.0`.

# \* \[ ] Gateway is `172.16.99.1`.

# \* \[ ] DNS is configured.

# \* \[ ] Security Onion is configured as a Standalone deployment.

# \* \[ ] Monitoring interface is the second NIC.

# \* \[ ] SOC administrator credentials were created.

# \* \[ ] Security Onion services completed initialization.

# 

# \### Connectivity

# 

# From the Windows workstation, verify:

# 

# ```text

# https://172.16.99.30

# ```

# 

# The Security Onion SOC interface should be reachable through the management network.

# 

# \### Capture Validation

# 

# The final and most important validation is confirming that the monitoring interface actually receives the mirrored traffic.

# 

# The management interface should handle administrative communication, while the capture interface should receive the mirrored \*\*VLAN 10\*\* traffic intended for inspection by:

# 

# ```text

# Suricata

# Zeek

# Security Onion

# ```

# 

# \---

# 

# \## 12. Expected Result

# 

# At the completion of this deployment:

# 

# ```text

# Windows / Management Station

# &#x20;            |

# &#x20;            | VLAN 99

# &#x20;            |

# &#x20;            v

# &#x20;     172.16.99.30

# &#x20;     Security Onion

# &#x20;            |

# &#x20;      +-----+-----+

# &#x20;      |           |

# &#x20;  Management    Capture

# &#x20;     NIC          NIC

# &#x20;      |             |

# &#x20;    vmbr0         vmbr1

# &#x20;      |             |

# &#x20;   VLAN 99       VLAN 10

# &#x20;                    |

# &#x20;             Mirrored Traffic

# &#x20;                    |

# &#x20;            +-------+-------+

# &#x20;            |               |

# &#x20;         Suricata          Zeek

# &#x20;            |               |

# &#x20;            +-------+-------+

# &#x20;                    |

# &#x20;             Security Onion

# &#x20;                    |

# &#x20;                   SOC

# ```

# 

# This provides the foundation for a dedicated network-security monitoring sensor in the Proxmox lab, with \*\*VLAN 99 used for management\*\* and the dedicated capture interface receiving \*\*mirrored VLAN 10 traffic\*\* for analysis.



