## 2.4 Create or Update the Security Onion Virtual Machine

Before creating VM `900`, verify whether the VM already exists and identify the **exact Proxmox storage name, existing virtual-disk identifier, disk size, and ISO filename**.

Do **not** assume that the storage is named `ext-ssd` or that the existing Security Onion disk is already attached as `scsi0`.

---

### 2.4.1 Verify Whether VM 900 Already Exists

List the virtual machines on the Proxmox host:

```bash
qm list
```

To check specifically for VM `900`:

```bash
qm list | grep -E '^[[:space:]]*900[[:space:]]'
```

If VM `900` exists, output similar to the following should appear:

```text
900  SecurityOnion-3.2  stopped  ...
```

You can also query its status directly:

```bash
qm status 900
```

If the VM exists, the result will resemble:

```text
status: stopped
```

or:

```text
status: running
```

If Proxmox reports that VM `900` does not exist, proceed to:

**Option A — Create a New VM**

If VM `900` already exists, proceed to:

**Option B — Update the Existing VM**

---

## 2.4.2 Verify the Available Proxmox Storage

Before creating or modifying the Security Onion disk, identify the exact Proxmox storage target:

```bash
pvesm status
```

Example:

```text
Name               Type     Status
local              dir      active
local-lvm          lvmthin  active
ext-ssd            lvmthin  active
```

The Security Onion storage must report:

```text
active
```

Record the exact storage name.

For example:

```text
Security Onion Storage: ext-ssd
```

> **Important:** The examples below use `ext-ssd`. If your actual storage has a different name, replace `ext-ssd` with the exact identifier returned by `pvesm status`.

---

## 2.4.3 Verify the Security Onion ISO

List the ISO images stored in Proxmox:

```bash
pvesm list local --content iso
```

You can also inspect the ISO directory directly:

```bash
ls -lh /var/lib/vz/template/iso/
```

Confirm the exact Security Onion ISO filename.

Example:

```text
securityonion-3.2.0.iso
```

The corresponding Proxmox volume identifier is:

```text
local:iso/securityonion-3.2.0.iso
```

Do not continue until both the storage name and ISO filename have been verified.

---

# Option A — VM 900 Does Not Already Exist

If VM `900` does not exist, create a new Security Onion VM.

### 2.4.4 Create the New VM

Using the verified storage name, run:

```bash
qm create 900 \
  --name SecurityOnion-3.2 \
  --ostype l26 \
  --cpu host \
  --cores 8 \
  --memory 24576 \
  --balloon 0 \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr1,firewall=0 \
  --scsihw virtio-scsi-pci \
  --scsi0 ext-ssd:250,discard=on,ssd=1 \
  --ide2 local:iso/securityonion-3.2.0.iso,media=cdrom \
  --boot "order=ide2;scsi0" \
  --agent 1 \
  --onboot 1
```

If your storage is not named `ext-ssd`, substitute the correct storage identifier.

For example:

```bash
--scsi0 SecOnion-Storage:250,discard=on,ssd=1
```

### Verify the Newly Created Disk

Run:

```bash
qm config 900 | grep -E '^scsihw|^scsi0'
```

Expected output should resemble:

```text
scsihw: virtio-scsi-pci
scsi0: ext-ssd:vm-900-disk-0,discard=on,size=250G,ssd=1
```

The automatically generated disk name may differ.

The important values are:

```text
Bus:       scsi0
Storage:   intended Security Onion storage
Size:      250 GB
Controller: VirtIO SCSI
```

---

# Option B — VM 900 Already Exists

If VM `900` already exists, **do not run `qm create 900`**.

The existing virtual machine should be inspected and updated in place.

---

## 2.4.5 Stop the Existing VM

Before modifying its hardware configuration:

```bash
qm shutdown 900
```

Check the status:

```bash
qm status 900
```

Expected:

```text
status: stopped
```

If the guest cannot shut down normally:

```bash
qm stop 900
```

---

## 2.4.6 Back Up the Existing VM Configuration

Before making changes:

```bash
qm config 900 > /root/securityonion-vm900-before-reinstall.txt
```

Verify the backup:

```bash
cat /root/securityonion-vm900-before-reinstall.txt
```

This preserves the known-good Proxmox hardware configuration independently of the Security Onion operating system.

---

## 2.4.7 Inspect the Complete Existing Configuration

Run:

```bash
qm config 900
```

Pay particular attention to:

```text
name
cpu
cores
memory
balloon
scsihw
scsi0
sata0
virtio0
ide2
net0
net1
boot
agent
onboot
```

---

## 2.4.8 Identify the Existing Security Onion Disk

Do not assume the system disk is already named `scsi0`.

List all disk devices attached to VM `900`:

```bash
qm config 900 | grep -E '^(scsi|sata|virtio)[0-9]+:'
```

Example:

```text
scsi0: ext-ssd:vm-900-disk-0,discard=on,size=250G,ssd=1
```

This tells you:

```text
Disk Bus:       scsi0
Storage:        ext-ssd
Volume:         vm-900-disk-0
Virtual Size:   250G
```

### Verify the Storage Containing the Existing Disk

If the configuration shows:

```text
scsi0: ext-ssd:vm-900-disk-0,...
```

verify that storage:

```bash
pvesm status | grep '^ext-ssd'
```

Then list VM `900` volumes on that storage:

```bash
pvesm list ext-ssd --vmid 900
```

This confirms that the virtual disk actually exists on the expected storage.

---

## 2.4.9 Verify the Existing Disk Size

Check:

```bash
qm config 900 | grep '^scsi0:'
```

Example:

```text
scsi0: ext-ssd:vm-900-disk-0,discard=on,size=250G,ssd=1
```

For this deployment, the target is:

```text
250 GB
```

Security Onion should have at least:

```text
200 GB
```

for a Standalone deployment.

If the existing disk is already `250G`, no disk change is required.

> **Do not create another `scsi0` disk just because you are reinstalling Security Onion.** The existing virtual disk can be reused and erased by the Security Onion installer.

---

## 2.4.10 Increase an Existing Disk Only If Necessary

If the existing virtual disk is smaller than required, it can be expanded.

For example, if `scsi0` is currently `200G` and you want `250G`:

```bash
qm resize 900 scsi0 +50G
```

Verify:

```bash
qm config 900 | grep '^scsi0:'
```

> **Important:** Proxmox virtual disks can be expanded but should not be casually reduced in size.
>
> During a clean Security Onion reinstall, the installer can repartition the enlarged virtual disk.

If the existing disk is already sufficiently large, **do not resize it**.

---

## 2.4.11 Verify the Disk Is on the Intended Storage

If the existing configuration shows:

```text
scsi0: ext-ssd:vm-900-disk-0,...
```

and `ext-ssd` is the intended Security Onion storage, leave the disk where it is.

If it is stored somewhere unexpected, such as:

```text
scsi0: local-lvm:vm-900-disk-0,...
```

do not immediately delete it.

First verify:

```bash
pvesm status
```

Then decide whether the existing disk should remain in place or be moved to the dedicated Security Onion storage.

The clean operating-system reinstall does **not** require recreating the Proxmox storage pool.

---

## 2.4.12 Update the Existing VM CPU and Memory

Set the CPU type:

```bash
qm set 900 --cpu host
```

Set eight virtual CPU cores:

```bash
qm set 900 --cores 8
```

Set 24 GB RAM:

```bash
qm set 900 --memory 24576
```

Disable memory ballooning:

```bash
qm set 900 --balloon 0
```

Verify:

```bash
qm config 900 | grep -E '^cpu:|^cores:|^memory:|^balloon:'
```

Expected:

```text
balloon: 0
cores: 8
cpu: host
memory: 24576
```

---

## 2.4.13 Verify the Disk Controller

Check:

```bash
qm config 900 | grep '^scsihw:'
```

The desired controller is:

```text
scsihw: virtio-scsi-pci
```

If necessary:

```bash
qm set 900 --scsihw virtio-scsi-pci
```

> Do not change an existing disk from SATA/VirtIO to SCSI blindly. Verify how the current disk is attached before changing its bus.

For a newly created Security Onion VM, `scsi0` with VirtIO SCSI is the preferred configuration used in this guide.

---

# 2.4.14 Verify the Existing Network Interfaces

Display the existing virtual NIC configuration:

```bash
qm config 900 | grep '^net'
```

For this lab, the validated configuration is:

```text
net0: virtio=BC:24:11:90:67:75,bridge=vmbr0
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,firewall=0
```

These MAC addresses and bridge mappings have already been validated through the Proxmox packet path.

### Management NIC

```text
net0
Bridge:     vmbr0
VLAN Tag:   Blank
Purpose:    Management
```

### Capture NIC

```text
net1
Bridge:     vmbr1
VLAN Tag:   Blank
Firewall:   Disabled
Purpose:    Passive SPAN capture
```

If the existing NICs already match these settings, **do not recreate them**.

Preserving the MAC addresses helps preserve the expected guest mapping:

```text
net0 → ens18
net1 → ens19
```

---

## 2.4.15 Correct `net0` Only If Necessary

If `net0` contains the obsolete configuration:

```text
tag=99
```

remove it by setting the validated configuration explicitly:

```bash
qm set 900 \
  --net0 virtio=BC:24:11:90:67:75,bridge=vmbr0
```

Verify:

```bash
qm config 900 | grep '^net0'
```

Expected:

```text
net0: virtio=BC:24:11:90:67:75,bridge=vmbr0
```

There should be **no `tag=99`**.

---

## 2.4.16 Correct `net1` Only If Necessary

The passive monitoring NIC should be:

```bash
qm set 900 \
  --net1 virtio=BC:24:11:EE:90:F1,bridge=vmbr1,firewall=0
```

Verify:

```bash
qm config 900 | grep '^net1'
```

Expected:

```text
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,firewall=0
```

There must be:

* No VLAN tag
* No Proxmox firewall
* No management IP configured at the Proxmox layer

---

# 2.4.17 Attach the Verified Security Onion ISO

Check whether an ISO is already attached:

```bash
qm config 900 | grep '^ide2:'
```

If the correct ISO is already attached:

```text
ide2: local:iso/securityonion-3.2.0.iso,media=cdrom
```

no change is required.

Otherwise attach it:

```bash
qm set 900 \
  --ide2 local:iso/securityonion-3.2.0.iso,media=cdrom
```

Verify:

```bash
qm config 900 | grep '^ide2:'
```

Expected:

```text
ide2: local:iso/securityonion-3.2.0.iso,media=cdrom
```

---

# 2.4.18 Configure the Installation Boot Order

During the clean installation, the ISO must boot before the existing system disk.

Set:

```bash
qm set 900 --boot "order=ide2;scsi0"
```

Verify:

```bash
qm config 900 | grep '^boot:'
```

Expected:

```text
boot: order=ide2;scsi0
```

> Keep the boot-order argument inside quotation marks because the semicolon has special meaning to the shell.

During installation:

```text
1. ide2  → Security Onion ISO
2. scsi0 → Virtual system disk
```

After installation, this order will be reversed.

---

## 2.4.19 Enable Guest Agent and Automatic Startup

Enable the QEMU Guest Agent:

```bash
qm set 900 --agent 1
```

Enable automatic startup:

```bash
qm set 900 --onboot 1
```

Verify:

```bash
qm config 900 | grep -E '^agent:|^onboot:'
```

Expected:

```text
agent: 1
onboot: 1
```

---

# 2.4.20 Final Existing-VM Verification

Before starting the installer, run:

```bash
qm config 900
```

For this lab, verify that the important settings resemble:

```text
agent: 1
balloon: 0
boot: order=ide2;scsi0
cores: 8
cpu: host
memory: 24576
name: SecurityOnion-3.2
onboot: 1
scsihw: virtio-scsi-pci

net0: virtio=BC:24:11:90:67:75,bridge=vmbr0
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,firewall=0

scsi0: <VERIFIED-STORAGE>:vm-900-disk-0,...,size=250G
ide2: local:iso/securityonion-3.2.0.iso,media=cdrom
```

The exact storage and disk volume names must match the values previously verified with:

```bash
pvesm status
```

and:

```bash
qm config 900
```

---

## 2.4.21 Pre-Boot Validation Commands

For a concise final check, run:

```bash
echo "=== VM STATUS ==="
qm status 900

echo "=== CPU / MEMORY ==="
qm config 900 | grep -E '^cpu:|^cores:|^memory:|^balloon:'

echo "=== STORAGE ==="
pvesm status

echo "=== VM DISKS ==="
qm config 900 | grep -E '^(scsi|sata|virtio)[0-9]+:|^scsihw:'

echo "=== ISO ==="
qm config 900 | grep '^ide2:'

echo "=== NETWORK ==="
qm config 900 | grep '^net'

echo "=== BOOT ORDER ==="
qm config 900 | grep '^boot:'
```

Do not proceed until the results confirm the intended configuration.

---

## 2.4.22 Expected Network Architecture

```text
                       SECURITY ONION VM 900
                              │
              ┌───────────────┴───────────────┐
              │                               │
             net0                            net1
           Management                     Monitoring
              │                               │
            vmbr0                           vmbr1
              │                               │
             nic0                            nic1
              │                               │
       Cisco Gi1/0/27                  Cisco Gi1/0/28
              │                         SPAN Destination
              │                               │
       Native VLAN 99                  Mirrored VLAN 10
              │                               │
      172.16.99.0/24                  Passive Traffic
              │                               │
              ▼                               ▼
           ens18                            ens19
      172.16.99.30/24                     NO IP
```

---

## 2.4.23 Start the Installation

Once all hardware, disk, storage, ISO, and network settings have been verified:

```bash
qm start 900
```

Verify:

```bash
qm status 900
```

Expected:

```text
status: running
```

Open:

```text
Proxmox Web GUI
    ↓
VM 900
    ↓
Console
```

The virtual machine should boot from the Security Onion ISO.

> **For an existing VM:** the Security Onion installer will erase and reinstall the operating system on the selected virtual disk. It does **not** require deleting VM `900`, recreating its virtual NICs, or reformatting the underlying Proxmox storage pool.

---

## 2.4.24 Decision Summary

```text
Does VM 900 exist?
        │
        ├── NO
        │    │
        │    ├── Verify storage name
        │    ├── Verify ISO filename
        │    ├── qm create 900
        │    ├── Create 250 GB scsi0
        │    └── Verify configuration
        │
        └── YES
             │
             ├── Shut down VM
             ├── Back up qm config
             ├── Identify existing disk
             ├── Verify exact storage
             ├── Verify disk size
             ├── Preserve existing disk if valid
             ├── Preserve validated NIC MACs
             ├── Update CPU / RAM if necessary
             ├── Attach verified ISO
             ├── Set ISO-first boot order
             └── Reinstall Security Onion
```

### Final Rule

**Never assume the VM disk or storage name. Verify them first:**

```bash
pvesm status
qm config 900
```

If VM `900` already exists, **update it with `qm set`; do not recreate it with `qm create`**.

If its existing Security Onion disk is correctly sized and stored on the intended storage, **reuse that virtual disk and allow the Security Onion installer to erase it during the clean installation**.
