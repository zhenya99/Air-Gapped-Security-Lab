# Deploying Security Onion v3.2.0

Deploying Security Onion 3.2.x requires precise interface alignment to ensure that mirrored **VLAN 10** traffic successfully reaches the **Suricata** and **Zeek** sensors.

\---

## 1\. VM Provisioning in Proxmox

Download the Security Onion ISO image by following the official \[Security Onion ISO Download and Verification Guide](https://github.com/Security-Onion-Solutions/securityonion/blob/3/main/DOWNLOAD\_AND\_VERIFY\_ISO.md).



Open PowerShell on your Windows 11 machine.



Run the following command, replacing the Windows path with the exact location of the ISO file on your machine:



```bash

scp "C:\\Users\\YourUser\\Downloads\\securityonion-3.2.0.iso" root@172.16.99.20:/var/lib/vz/template/iso

```



\## Step 1: Verify the ISO and Storage Pool



\### Check the exact ISO name in local storage



Run:



```bash

pvesm list local --content iso

```



\### Verify available storage and resources on the Proxmox host



Run:



Run:



```bash

pvesm status

```

!\[Disk](images/Proxmox/disk\_usage.png)

Before booting the Security Onion ISO...














































Before booting the Security Onion ISO,configure the virtual hardware to match the required network segmentation and storage layout.

You can verify the Proxmox host's available resources from the Proxmox shell.

### Verify Proxmox Host Resources

```
ssh root@lab

lscpu
pvesh get /nodes/localhost/status
free -h
df -h
lsblk
```

### Host Hardware

The lab host is equipped with:

* **CPU:** Intel Core i7-12700K

  * 8 Performance cores
  * 4 Efficient cores
  * 20 logical threads with Hyper-Threading
* **Memory:** 46 GB RAM
* **Internal Storage:** 240 GB SSD
* **External Storage:** 1 TB SSD

### Security Onion 3.2.0 VM Blueprint

|Resource|Configuration|
|-|-|
|**CPU**|8–12 cores|
|**CPU Type**|`host`|
|**Memory**|24–28 GB|
|**Ballooning**|Disabled|
|**Storage**|250–500 GB on the 1 TB external SSD|
|**Management NIC**|`vmbr0` / VLAN `99` / Firewall enabled|
|**Capture NIC**|`vmbr1` / No VLAN tag / Firewall disabled|

### CPU Configuration

Allocate **8–12 CPU cores** to the Security Onion VM.

In the Proxmox **Advanced CPU** settings, change the CPU type from:

```
kvm64
```

to:

```
host
```

This exposes the host CPU's available features to the virtual machine and can improve processing performance for workloads such as Suricata packet inspection.

### Memory Configuration

Allocate:

```
24–28 GB RAM
```

Equivalent values:

```
24576 MB – 28672 MB
```

Disable **Memory Ballooning** so the assigned memory remains dedicated to the Security Onion VM.

### Storage Configuration

Allocate approximately:

```
250–500 GB
```

Provision the Security Onion storage on the **1 TB external SSD**.

This provides additional space for:

* Suricata alerts
* Zeek logs
* Network metadata
* Security Onion application data
* Search and analysis data

### Network Device 1 — Management

```
Bridge:    vmbr0
VLAN Tag:  99
Firewall:  Enabled
Purpose:   Security Onion management and SOC access
```

### Network Device 2 — Capture

```
Bridge:    vmbr1
VLAN Tag:  <Leave Blank>
Firewall:  Disabled
Purpose:   Mirrored network traffic capture
```

> \*\*Important:\*\* The capture interface should remain dedicated to monitoring traffic. Do not assign a management IP address to this interface.

\---

## 2\. Base OS Installation

### Step 1 — Boot the Installation ISO

Boot the Security Onion VM using the **Security Onion 3.2.0 ISO**.

From the GRUB menu, select:

```
Install Security Onion
```

### Step 2 — Create the Administrative OS Account

The operating-system installer will prompt you to create an administrative OS user and password.

> \*\*Note:\*\* Store these credentials securely. They are required for administrative tasks and for running the Security Onion setup process.

### Step 3 — Complete the Installation

Allow the base OS installation to complete.

When prompted, press:

```
Enter
```

The VM will reboot.

\---

## 3\. The `so-setup` Wizard

After the VM reboots, log back in at the terminal using the administrative OS credentials created during the base installation.

### 3.1 Network Configuration

Run the Security Onion network configuration utility:

```
sudo so-setup-network
```

### Select the Management Interface

Select the **Management Interface**, which should be the first virtual network interface.

Depending on the VM's interface naming, it may appear as:

```
ens1
```

or:

```
eth0
```

> \*\*Important:\*\* Verify the actual interface name in the VM rather than assuming `ens18` or `eth0`.

### Configure a Static IP Address

Configure the management interface with the following settings:

|Setting|Value|
|-|-|
|**IP Address**|`172.16.99.30`|
|**Subnet Mask**|`255.255.255.0`|
|**Gateway**|`172.16.99.1`|
|**DNS**|`8.8.8.8` or local resolver|

The resulting management network is:

```
Network:         172.16.99.0/24
Security Onion:  172.16.99.30
Gateway:         172.16.99.1
```

After completing the network configuration, reboot the VM:

```
sudo reboot
```

\---

## 4\. Sensor Application Setup

After the VM reboots, log back in and launch the Security Onion setup wizard:

```
sudo so-setup
```

### Step 1 — Select the Installation Type

Select:

```
Install
```

Then select:

```
Standalone
```

A **Standalone** deployment installs the primary Security Onion components on the same system.

When prompted for the deployment configuration, select:

```
Standard
```

### Step 2 — Select the Monitoring Interface

Select the **Monitor/Capture Interface**, which should be the second virtual network interface.

Depending on the interface naming, it may appear as:

```
ens19
```

or:

```
eth1
```

> \*\*Important:\*\* Verify that this is the dedicated capture interface connected to `vmbr1`. It should not be used as the Security Onion management interface.

### Step 3 — Configure the SOC Administrator

Create the administrator credentials for the Security Onion web-based SOC interface.

Configure:

* **Administrator email address**
* **Administrator password**

Store these credentials securely.

### Step 4 — Deploy Security Onion Services

Allow the setup process to download and deploy the required Security Onion components.

The installation may take some time while the required container images and services are initialized.

Do not interrupt the process while deployment is in progress.

\---

## 5\. Access the Security Onion SOC

Once the setup process has completed, access the Security Onion web interface from the Windows workstation.

Open:

```
https://172.16.99.30
```

Authenticate using the administrator credentials created during the Security Onion setup.

The management interface should provide access to the Security Onion SOC, while the dedicated capture interface receives the mirrored network traffic for inspection.

\---

## 6\. Expected Network Architecture

The completed configuration should follow this basic architecture:

```
Windows Management Station
          |
          | VLAN 99
          |
          v
   172.16.99.30
    Security Onion
          |
    +-----+-----+
    |           |
  NIC 1       NIC 2
```

Management    Capture
|           |
vmbr0       vmbr1
|           |
VLAN 99     VLAN 10
|
Mirrored Traffic
|
+------+------+
|             |
Suricata         Zeek
|             |
+------+------+
|
Security Onion SOC

The intended separation is:

* **VLAN 99:** Security Onion management traffic
* **VLAN 10:** Mirrored traffic sent to the dedicated monitoring interface
* **NIC 1:** Management and SOC access
* **NIC 2:** Packet capture and network monitoring

