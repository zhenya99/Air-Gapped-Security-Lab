# Deploying Security Onion v3.2.0

Deploying Security Onion 3.2.x requires precise interface alignment to ensure that mirrored VLAN 10 traffic successfully reaches the Suricata and Zeek sensors.


## 1. VM Provisioning in Proxmox

Download the Security Onion ISO image by following the official [Security Onion ISO Download and Verification Guide](https://github.com/Security-Onion-Solutions/securityonion/blob/3/main/DOWNLOAD_AND_VERIFY_ISO.md).

**Open PowerShell on your Windows 11 machine.**
Run the following command, replacing the Windows path with the exact location of the ISO file on your machine:

```bash

scp "C:\\Users\\YourUser\\Downloads\\securityonion-3.2.0.iso" root@172.16.99.20:/var/lib/vz/template/iso

```

Before booting the ISO, configure the virtual hardware to match the network segmentation and storage layout. Verify  host's capacity from the Proxmox shell from Windows:

```bash
ssh root@lab
lscpu
pvesh get /nodes/localhost/status
free -h
df -h
lsblk
```
I am running an **i7-12700K**, which features *12 physical cores (8 Performance, 4 Efficient) and hyper-threading*, meaning Proxmox actually has 20 logical threads to work with. The host also features **46GB** of memory, a **240GB** internal SSD, and a **1TB** external SSD.



**Step 1: Verify the ISO and Storage Pool**
Check the exact ISO name in local storage

```bash
pvesm list local --content iso
pvesm status
lsblk

```
![Disk](/images/Proxmox/disk_usage.png)

The 1TB external drive (`sda`) currently contains old partitions and needs to be formatted before Proxmox can use it for the Security Onion VM. To fix this, wipe the disk, initialize it as a Physical Volume, and create an LVM-Thin pool for optimized virtual machine storage.


**1.1 Wipe the existing partition table**
*Warning: This destroys all data currently on `sda`.*
Run the following commands to remove all filesystem signatures and destroy the GPT/MBR partition tables:

```bash
wipefs -a /dev/sda
sgdisk --zap-all /dev/sda
```
![Disk](/images/Proxmox/disk_wipe.png)


**1.2 Create a new full-disk partition**
```bash
sgdisk -N 1 /dev/sda
```
![Disk](/images/Proxmox/partition.png)


**1.3 Initialize the LVM structures and register with Proxmox**
```bash
pvcreate /dev/sda1
vgcreate ext-ssd-vg /dev/sda1
lvcreate -l 100%FREE --thinpool ext-ssd-thin ext-ssd-vg
pvesm add lvmthin ext-ssd --vgname ext-ssd-vg --thinpool ext-ssd-thin
```
![Disk](/images/Proxmox/LVM.png)

(A quick side note on those terminal warnings: Do not worry about the optimal_io_size or Pool zeroing warnings. Those are completely standard when formatting external SSDs over USB/SATA adapters in Linux. Proxmox handles them gracefully, and it won't impact Security Onion performance at all.)


### Step 2: Provision the Virtual Machine via CLI

With the external SSD fully initialized, we can provision the VM directly from the Proxmox shell. This `qm create` command maps our exact hardware blueprint—allocating the `host` CPU architecture, 24 GB of dedicated RAM, bridging the specific network interfaces, and assigning 250 GB of storage on the newly created `ext-ssd` pool.



**2.1 Create a VM**
*Run the following command to with ID `900` (adjust the ID as needed for your lab environment):*

```bash
qm create 900 \
  --name SecurityOnion-3.2 \
  --ostype l26 \
  --cpu host --cores 8 \
  --memory 24576 --balloon 0 \
  --net0 virtio,bridge=vmbr0,tag=99,firewall=1 \
  --net1 virtio,bridge=vmbr1,firewall=0 \
  --scsihw virtio-scsi-pci \
  --scsi0 ext-ssd:250,discard=on,ssd=1 \
  --ide2 local:iso/securityonion-3.2.0.iso,media=cdrom \
  --boot order=ide2;scsi0 \
  --agent 1 \
  --onboot 1
```

You can see the Proxmox backend doing exactly what it was supposed to do:

* Logical volume "vm-900-disk-0" created.
* scsi0: successfully created disk...

![Disk](/images/Proxmox/Provisioning.png)


