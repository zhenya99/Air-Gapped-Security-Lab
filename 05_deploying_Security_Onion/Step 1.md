# Step 1: Environment Staging

**Before continuing with the installation, verify that the Proxmox host meets the minimum resource requirements and that the required installation media is available.**

## 1.1 Verify Proxmox Host Resources

From your Windows 11 workstation, open PowerShell and connect to the Proxmox host using SSH:

```powershell
ssh root@lab
```

Once connected to the Proxmox shell, verify the host's CPU, memory, storage, and block-device configuration:

```bash
lscpu
pvesh get /nodes/localhost/status
free -h
df -h
lsblk
```

For a standalone or evaluation deployment of Security Onion on Proxmox VE, allocate **at least 4 CPU cores, 32 GB of RAM, and 200 GB or more of fast local SSD storage**. Production or higher-traffic deployments require additional resources based on network traffic volume, packet capture requirements, and Elasticsearch indexing workloads.

> **Lab Note:** The final VM configuration used in this lab allocates **8 CPU cores, 24 GB of RAM, and 250 GB of SSD storage**. Adjust the VM resources according to the available hardware and the expected monitoring workload.

---

## 1.2 Download the Security Onion ISO and Transfer It to Proxmox

Download the Security Onion ISO image by following the official [Security Onion ISO Download and Verification Guide](https://github.com/Security-Onion-Solutions/securityonion/blob/3/main/DOWNLOAD_AND_VERIFY_ISO.md).

Open **PowerShell** on your Windows 11 workstation.

Run the following command, replacing the Windows path and filename with the exact location and name of the Security Onion ISO on your machine:

```powershell
scp "C:\Users\YourUser\Downloads\securityonion-3.2.0.iso" root@172.16.99.20:/var/lib/vz/template/iso/
```
Verify the checksum of the file: 

```bash
cd /var/lib/vz/template/iso/
ls 
sha256sum securityonion-3.2.0.iso
 
```
![Checksum](/images/Proxmox/SecOnion/checksum.png)


> **Important:** Replace `YourUser` with your actual Windows username and verify the ISO filename before running the command.

After the transfer completes, connect to the Proxmox host and verify that the ISO is available in local storage:

```bash
pvesm list local --content iso
pvesm status
lsblk
```

![Proxmox Disk Usage](/images/Proxmox/disk_usage.png)


The `lsblk` output should also allow you to identify the external SSD that will be prepared for Security Onion VM storage.

> **Storage Note:** In this lab, the 1 TB external drive (`/dev/sda`) contains existing partitions and must be reformatted before Proxmox can use it for the Security Onion VM. The following steps remove the existing partition information, create a new partition, initialize it for LVM, and create an LVM-Thin storage pool.

---

## 1.3 Wipe the Existing Partition Table

> **⚠️ WARNING:** The following commands **destroy all data currently stored on `/dev/sda`**. Confirm that `/dev/sda` is the correct external SSD before proceeding.

Remove existing filesystem signatures and destroy the GPT/MBR partition information:

```bash
wipefs -a /dev/sda
sgdisk --zap-all /dev/sda
```

After completing this step, verify that the existing partition information has been removed:

```bash
lsblk
```
![Wipe External SSD](/images/Proxmox/disk_wipe.png)


---

## 1.4 Create a New Full-Disk Partition

Create a new partition using the available space on the external SSD:

```bash
sgdisk -N 1 /dev/sda
```

Verify that the new partition was created:

```bash
lsblk
```

The resulting partition should appear as:

```text
/dev/sda1
```

![Create SSD Partition](/images/Proxmox/partition.png)

---

## 1.5 Initialize LVM and Register the Storage with Proxmox

Initialize `/dev/sda1` as an LVM physical volume:

```bash
pvcreate /dev/sda1
```

Create the volume group:

```bash
vgcreate ext-ssd-vg /dev/sda1
```

Create an LVM-Thin pool using all available space:

```bash
lvcreate -l 100%FREE --thinpool ext-ssd-thin ext-ssd-vg
```

Register the LVM-Thin pool with Proxmox:

```bash
pvesm add lvmthin ext-ssd \
  --vgname ext-ssd-vg \
  --thinpool ext-ssd-thin
```

![LVM Storage Configuration](/images/Proxmox/LVM.png)

Verify that Proxmox recognizes the new storage:

```bash
pvesm status
```

You should see the newly created `ext-ssd` storage listed as an active LVM-Thin storage target.

### About the Terminal Warnings

You may encounter warnings related to values such as `optimal_io_size` or LVM pool zeroing during storage initialization.

These messages do not necessarily indicate a failure. Review the command output carefully and verify the resulting LVM and Proxmox storage configuration before continuing.

> **Important:** Do not ignore an actual error message. The expected result is that the physical volume, volume group, thin pool, and Proxmox storage registration complete successfully.

At this point, the external SSD is prepared and registered with Proxmox as the `ext-ssd` storage pool. The environment is now ready for **Step 2: Provision the Security Onion virtual machine**.
