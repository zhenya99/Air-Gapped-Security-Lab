### Step 1: Verifying the ISO and Storage Pool

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