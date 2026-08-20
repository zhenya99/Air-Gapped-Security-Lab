# Step 1: Environment Staging

**Before continuing with the installation, verify the minimum requirements:**

Verify the host's capacity from the Proxmox shell via Windows:

```bash
ssh root@lab
lscpu
pvesh get /nodes/localhost/status
free -h
df -h
lsblk
```

*For a standalone or evaluation deployment of Security Onion on Proxmox VE, allocate at least 4 CPU cores, 32GB of RAM, and 200GB+ of fast local SSD storage. Production or higher-traffic setups require scaling up resources significantly based on packet capture and Elasticsearch indexing loads.*


**1.1 Download ISO and Move to Proxmox**

Download the Security Onion ISO image by following the official [Security Onion ISO Download and Verification Guide](https://github.com/Security-Onion-Solutions/securityonion/blob/3/main/DOWNLOAD_AND_VERIFY_ISO.md).

**Open PowerShell on your Windows 11 machine**. Run the following command, replacing the Windows path with the exact location of the ISO file on your machine:

Run the following command, replacing the Windows path with the exact location of the ISO file on your machine:

```bash
scp "C:\\Users\\YourUser\\Downloads\\securityonion-3.2.0.iso" root@172.16.99.20:/var/lib/vz/template/iso
```

**Check the exact ISO name in local storage:**

```bash
pvesm list local --content iso
pvesm status
lsblk

```
![Disk](/images/Proxmox/disk_usage.png)

The 1TB external drive (sda) currently contains old partitions and needs to be formatted before Proxmox can use it for the Security Onion VM. To fix this, wipe the disk, initialize it as a Physical Volume, and create an LVM-Thin pool for optimized virtual machine storage.


**1.2 Wipe the Existing Partition Table**
*Warning: This destroys all data currently on `sda`.*
Run the following commands to remove all filesystem signatures and destroy the GPT/MBR partition tables:

```bash
wipefs -a /dev/sda
sgdisk --zap-all /dev/sda
```
![Disk](/images/Proxmox/disk_wipe.png)

**1.3 Create a New Full-Disk Partition**
```bash
sgdisk -N 1 /dev/sda
```
![Disk](/images/Proxmox/partition.png)


**1.4 Initialize LVM Structures and Register with Proxmox**
```bash
pvcreate /dev/sda1
vgcreate ext-ssd-vg /dev/sda1
lvcreate -l 100%FREE --thinpool ext-ssd-thin ext-ssd-vg
pvesm add lvmthin ext-ssd --vgname ext-ssd-vg --thinpool ext-ssd-thin
```
![Disk](/images/Proxmox/LVM.png)

*(A quick side note on those terminal warnings: Do not worry about the optimal_io_size or Pool zeroing warnings. Those are completely standard when formatting external SSDs over USB/SATA adapters in Linux. Proxmox handles them gracefully, and it won't impact Security Onion performance at all.)*