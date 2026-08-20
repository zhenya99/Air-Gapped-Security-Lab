# \## 1. VM Provisioning in Proxmox

# 

# Before booting the Security Onion ISO, configure the virtual hardware to match the required network segmentation and storage layout.

# 

# \### Verify Proxmox Host Resources

# 

# From the Proxmox shell, verify the available CPU, memory, and storage:

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

# These commands provide information about:

# 

# \* CPU architecture and available processors

# \* Proxmox node status and resource allocation

# \* Available system memory

# \* Mounted filesystems and available disk space

# \* Block devices and attached storage

# 

# \### Security Onion VM Blueprint

# 

# | Resource           | Recommended Configuration |

# | ------------------ | ------------------------- |

# | \*\*CPU\*\*            | 8–12 cores                |

# | \*\*CPU Type\*\*       | `host`                    |

# | \*\*Memory\*\*         | 24–28 GB                  |

# | \*\*Ballooning\*\*     | Disabled                  |

# | \*\*Storage\*\*        | 250–500 GB                |

# | \*\*Management NIC\*\* | `vmbr0`, VLAN `99`        |

# | \*\*Capture NIC\*\*    | `vmbr1`, VLAN tag blank   |

# 

# > \*\*Note:\*\* The lab host uses an Intel i7-12700K with 46 GB of RAM, a 240 GB internal SSD, and a 1 TB external SSD. The Security Onion VM should therefore be sized carefully to leave sufficient resources for the Proxmox host and other virtual machines.

# 

# \### Network Interfaces

# 

# The Security Onion VM requires two separate network interfaces:

# 

# \*\*Management Interface\*\*

# 

# ```text

# Bridge:    vmbr0

# VLAN Tag:  99

# Firewall:  Enabled

# Purpose:   Security Onion management and SOC access

# ```

# 

# \*\*Capture Interface\*\*

# 

# ```text

# Bridge:    vmbr1

# VLAN Tag:  <Leave Blank>

# Firewall:  Disabled

# Purpose:   Mirrored network traffic capture

# ```

# 

# > \*\*Important:\*\* Keep the capture interface dedicated to monitoring traffic. Do not configure it as a normal management interface or assign a management IP address to it.



