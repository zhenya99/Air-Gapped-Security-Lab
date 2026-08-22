# Step 4: Configure Security Onion for Standalone Air-Gapped Operation

After the operating system has been installed and Security Onion Setup starts, configure the platform for the lab environment.

The target architecture is:

```text
Security Onion 3.2.x
        │
        ├── Standalone deployment
        │
        ├── Airgap mode
        │
        ├── ens18 → Management (MTU 1500)
        │
        └── ens19 → Passive monitoring (MTU 9000)
```

Security Onion's Standalone deployment runs the manager and sensor components on the same host and is appropriate for labs, POCs, and low-throughput single-sensor deployments.

---

## 4.1 Start Security Onion Setup

After logging in, Setup should launch automatically.

If necessary:

```bash
sudo SecurityOnion/setup/so-setup iso
```

Proceed through the Setup wizard.

---

# 4.2 Select the Deployment Type

When Setup asks for the Security Onion installation/deployment type, select:

```text
STANDALONE
```

The Standalone node will provide both:

```text
Management / SOC Services
            +
Network Sensor Services
```

on the same Security Onion system.

---

# 4.3 Select Airgap Mode

When Setup asks whether the deployment is:

```text
Standard
```

or:

```text
Airgap
```

select:

```text
Airgap
```

This lab is intentionally isolated and should not depend on Internet connectivity.

Security Onion supports air-gapped deployment from the official ISO; the ISO supplies the resources required for installation rather than requiring the normal Internet-based installation path.

Do not configure the deployment as Standard and then manually attempt to reconstruct missing Internet resources.

---

# 4.4 Accept the Security Onion License

Review the Security Onion license presented by Setup.

Accept it to continue.

---

# 4.5 Configure the Hostname

Configure the Security Onion hostname.

For example:

```text
securityonion
```

or an appropriate internal fully qualified hostname if internal DNS is available.

> Choose the hostname carefully.
>
> Security Onion generates certificates based on the configured hostname and does not support casually changing the hostname after Setup.

---

# 4.6 Select the Management Interface

Select:

```text
ens18
```

as the Security Onion management interface.

The intended management configuration is:

```text
Interface:  ens18
Purpose:    Management
Addressing: Static
IP Address: 172.16.99.30/24
Gateway:    172.16.99.1
```

Select:

```text
STATIC
```

addressing when prompted.

Security Onion recommends using a dedicated management interface and static addressing where possible.

---

# 4.7 Configure the Management IP Address

Enter:

```text
172.16.99.30/24
```

The management network is:

```text
172.16.99.0/24
```

and Security Onion will use:

```text
172.16.99.30
```

as its management address.

---

# 4.8 Configure the Default Gateway

Enter:

```text
172.16.99.1
```

The default gateway belongs only to the management network.

The monitoring interface must not receive a gateway.

---

# 4.9 Configure DNS

When Setup requests DNS servers, use an **internal DNS server available to the air-gapped management network**, if one exists.

Do not configure public DNS servers such as:

```text
8.8.8.8
1.1.1.1
```

unless the lab is intentionally designed to provide Internet access to those services.

For a strictly air-gapped environment, DNS should remain internal to the lab.

Configure a DNS search domain only if the environment uses one.

---

# 4.10 Docker Network

Security Onion Setup may offer the ability to change the internal Docker network range.

Unless the default Docker network overlaps one of the lab networks, leave the default value unchanged.

The lab currently uses:

```text
172.16.99.0/24     Management
172.16.10.0/24     Victim VLAN
192.168.66.0/24    Kali network
```

If Setup identifies an overlap, select a Docker address range that does not conflict with any lab subnet.

---

# 4.11 Configure the Monitoring Interface

Select the second interface as the monitoring/sniffing interface:

```text
ens19
```

Its configuration must remain:

```text
Interface:   ens19
Purpose:     Passive monitoring
MTU:         9000
IP Address:  NONE
Gateway:     NONE
DHCP:        NONE
```

Security Onion explicitly recommends that sniffing interfaces used with TAP/SPAN traffic have **no IP address**.

For this Proxmox 9.x lab, the validated capture path is MTU 9000 from `nic1` through `vmbr1`, VM `net1`, `ens19`, and Security Onion `bond0`. Do not reduce only the VM capture NIC to MTU 1500 while `bond0` remains at 9000.

The resulting interface design is:

```text
                  SECURITY ONION
                        │
            ┌───────────┴───────────┐
            │                       │
          ens18                   ens19
        Management               Monitoring
            │                       │
   172.16.99.30/24                NO IP
            │                       │
            ▼                       ▼
          net0                    net1
            │                       │
          vmbr0                   vmbr1
            │                       │
          nic0                    nic1
            │                       │
    Cisco Gi1/0/27          Cisco Gi1/0/28
                              SPAN Destination
```

Security Onion will use the sniffing interface for network monitoring rather than routing traffic through it.

---

# 4.12 Create the Security Onion Console Account

Setup will prompt for credentials for the Security Onion Console.

Create the SOC administrator account.

This account is separate from the Linux account created during Step 3.

```text
Linux Account
     │
     ├── Console
     ├── SSH
     └── sudo


SOC Account
     │
     ├── Security Onion Console
     ├── Alerts
     ├── Hunt
     ├── Dashboards
     ├── Cases
     ├── Detections
     └── Administration
```

Use a strong, unique password.

---

# 4.13 Configure Security Onion Console Access

When Setup asks which systems should be permitted to access Security Onion Console, authorize the management workstation or management subnet.

The SOC interface will be reached through:

```text
https://172.16.99.30
```

For tighter access control, authorize only the administrative workstation's IP address.

If the entire management VLAN is intentionally trusted for SOC administration, the applicable network is:

```text
172.16.99.0/24
```

Security Onion's host firewall is restrictive by default, so SOC access must be allowed for the appropriate analyst host or network.

---

# 4.14 Review the Setup Summary

Before allowing Setup to begin deployment, review the configuration summary.

The intended values are:

| Setting              | Configuration                      |
| -------------------- | ---------------------------------- |
| Deployment           | `STANDALONE`                       |
| Connectivity         | `AIRGAP`                           |
| Management Interface | `ens18`                            |
| Management IP        | `172.16.99.30/24`                  |
| Gateway              | `172.16.99.1`                      |
| Monitoring Interface | `ens19` (MTU 9000)                 |
| Monitoring IP        | **None**                           |
| Monitoring Gateway   | **None**                           |
| SOC Access           | Authorized management host/network |

Confirm the configuration and begin Setup.

---

# 4.15 Allow Security Onion Setup to Complete

Security Onion Setup will configure the platform and initialize the required services.

Depending on system performance, this process can take some time.

Do not:

```text
Reboot the VM
Power off the VM
Interrupt Salt
Manually restart containers
Manually modify generated configuration files
```

while Setup is still running.

The supported Airgap installation process should be allowed to complete normally using the content supplied by the Security Onion ISO.

Do not manually reconstruct:

```text
Docker registries
Salt states
Elasticsearch users
Suricata containers
Zeek containers
ElastAlert
Strelka
```

during a normal clean installation.

---

# 4.16 Setup Completion

When Setup reports completion, Security Onion has transitioned from the base operating system into the configured platform.

The system should now conceptually be:

```text
Security Onion Standalone
        │
        ├── SOC
        ├── Elasticsearch
        ├── Logstash
        ├── Redis
        ├── Suricata
        ├── Zeek
        └── Supporting Security Onion services
```

Proceed to **Step 5** for post-install configuration and sensor activation.
