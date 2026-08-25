# Step 2: Provision and Validate the Security Onion Virtual Machine

With the Proxmox host, storage, ISO, and network backbone validated in **Step 1**, the next stage is to prepare the Security Onion virtual machine.

This lab uses:

```text
VM ID:       900
VM Name:     SecurityOnion-3.2
CPU:         8 vCPU
CPU Type:    host
Memory:      24 GB
Disk:        250 GB target
Management:  net0 → vmbr0
Capture:     net1 → vmbr1
```

The intended network architecture is:

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
           Native VLAN 99                  SPAN mirror feed
                  │                               │
           172.16.99.0/24                 Passive Traffic / MTU 9000
                  │                               │
                  ▼                               ▼
               ens18                            ens19
          172.16.99.30/24                     NO IP
```

> **Important**
>
> Do not assume that:
>
> * VM `900` does not already exist.
> * The Security Onion storage is named `ext-ssd`.
> * The existing system disk is attached as `scsi0`.
> * The ISO filename is exactly `securityonion-3.2.0.iso`.
>
> Verify each of these values before creating or modifying the VM.

---

## 2.1 Determine Whether VM 900 Already Exists

List all Proxmox virtual machines:

```bash
qm list
```

To search specifically for VM `900`:

```bash
qm list | grep -E '^[[:space:]]*900[[:space:]]'
```

You can also query it directly:

```bash
qm status 900
```

If the VM exists, Proxmox will return something similar to:

```text
status: stopped
```

or:

```text
status: running
```

If VM `900` does not exist, Proxmox will report that the configuration file cannot be found.

Use the following decision path:

```text
Does VM 900 exist?
        │
        ├── NO  → Create a new VM
        │
        └── YES → Inspect and update the existing VM
```

Do **not** run:

```bash
qm create 900
```

if VM `900` already exists.

---

# 2.2 Verify the Exact Proxmox Storage Name

Before creating, resizing, or reusing a disk, determine the exact Proxmox storage identifier.

Run:

```bash
pvesm status
```

Example:

```text
Name               Type      Status
local              dir       active
local-lvm          lvmthin   active
ext-ssd            lvmthin   active
```

The storage intended for Security Onion must report:

```text
active
```

Record its exact name.

For example:

```text
Security Onion Storage: ext-ssd
```

or:

```text
Security Onion Storage: SecOnion-Storage
```

> The remainder of this guide may use `ext-ssd` as an example. Replace it with the exact storage identifier returned by your Proxmox host.

---

## 2.3 Inspect Available Storage Capacity

Check storage usage:

```bash
pvesm status
```

Also inspect the physical and logical storage layout:

```bash
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
```

The Security Onion VM should have at least enough space for the intended system disk.

For this lab:

```text
Target VM Disk Size: 250 GB
```

Do not reformat or wipe the underlying Proxmox storage simply because Security Onion is being reinstalled.

A clean reinstall erases the **virtual machine disk**, not the Proxmox storage pool that contains it.

---

# 2.4 Verify the Security Onion ISO

List ISO images registered in Proxmox local storage:

```bash
pvesm list local --content iso
```

You can also inspect the ISO directory:

```bash
ls -lh /var/lib/vz/template/iso/
```

Identify the exact ISO filename.

Example:

```text
securityonion-3.2.0.iso
```

Its corresponding Proxmox volume identifier would be:

```text
local:iso/securityonion-3.2.0.iso
```

Do not copy an example filename into the VM configuration until the actual filename has been verified.

---

# 2.5 VM Does Not Exist — Create a New VM

If VM `900` does **not** already exist, create it using the verified storage and ISO names.

For example, if the storage is named `ext-ssd` and the ISO is named `securityonion-3.2.0.iso`:

```bash
qm create 900 \
  --name SecurityOnion-3.2 \
  --ostype l26 \
  --cpu host \
  --cores 8 \
  --memory 24576 \
  --balloon 0 \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio,bridge=vmbr1,firewall=0,mtu=9000 \
  --scsihw virtio-scsi-pci \
  --scsi0 ext-ssd:250,discard=on,ssd=1 \
  --ide2 local:iso/securityonion-3.2.0.iso,media=cdrom \
  --boot "order=ide2;scsi0" \
  --agent 1 \
  --onboot 1
```

If the storage is instead named:

```text
SecOnion-Storage
```

then the disk portion would become:

```bash
--scsi0 SecOnion-Storage:250,discard=on,ssd=1
```

Do not change the storage name blindly. Use the value returned by:

```bash
pvesm status
```

---

## 2.6 Verify the Newly Created VM

After creating VM `900`, inspect the complete configuration:

```bash
qm config 900
```

Verify CPU and memory:

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

Verify the disk:

```bash
qm config 900 | grep -E '^scsihw:|^scsi0:'
```

Example:

```text
scsihw: virtio-scsi-pci
scsi0: ext-ssd:vm-900-disk-0,discard=on,size=250G,ssd=1
```

The exact automatically generated volume name may differ.

The important values are:

```text
Disk Bus:    scsi0
Storage:     verified Security Onion storage
Disk Size:   250G
Controller:  VirtIO SCSI
```

If this is a newly created VM using the command above, the system disk used throughout this guide is:

```text
scsi0
```

---

# 2.7 VM Already Exists — Preserve and Inspect It

If VM `900` already exists, **do not recreate it**.

First inspect its complete configuration:

```bash
qm config 900
```

Before changing anything, save the configuration:

```bash
qm config 900 > /root/securityonion-vm900-before-reinstall.txt
```

Verify the backup:

```bash
cat /root/securityonion-vm900-before-reinstall.txt
```

This backup records the current:

* VM hardware
* Disk configuration
* MAC addresses
* Network bridges
* Boot order
* CPU
* Memory
* ISO configuration

---

# 2.8 Stop an Existing VM Before Hardware Changes

Check the VM state:

```bash
qm status 900
```

If it is running, request a clean shutdown:

```bash
qm shutdown 900
```

Check again:

```bash
qm status 900
```

Expected:

```text
status: stopped
```

If the guest does not shut down successfully:

```bash
qm stop 900
```

> Use `qm stop` only when a normal shutdown does not work, because it is equivalent to abruptly powering off the VM.

---

# 2.9 Identify the Existing System Disk

Do **not** assume that an existing VM uses `scsi0`.

Display all attached virtual disks:

```bash
qm config 900 | grep -E '^(scsi|sata|virtio)[0-9]+:'
```

Possible examples include:

```text
scsi0: ext-ssd:vm-900-disk-0,size=250G
```

or:

```text
sata0: SecOnion-Storage:900/vm-900-disk-0.raw,size=250G
```

or:

```text
virtio0: local-lvm:vm-900-disk-0,size=250G
```

Record four pieces of information:

```text
System Disk Bus:
Storage Name:
Volume Name:
Disk Size:
```

For example:

```text
System Disk Bus: scsi0
Storage Name:    ext-ssd
Volume Name:     vm-900-disk-0
Disk Size:       250G
```

This disk identifier becomes important when configuring the boot order later.

---

# 2.10 Distinguish Attached Disks from Unused Disks

Also check for detached volumes:

```bash
qm config 900 | grep '^unused'
```

For example:

```text
unused0: ext-ssd:vm-900-disk-1
```

An `unused0`, `unused1`, or similar entry represents a volume known to the VM configuration but **not currently attached as an active disk device**.

Do not accidentally select an `unused` volume as the Security Onion system disk.

The system disk should appear under an active bus such as:

```text
scsi0
sata0
virtio0
```

---

# 2.11 Verify the Existing Disk in Proxmox Storage

Suppose the existing VM configuration contains:

```text
scsi0: ext-ssd:vm-900-disk-0,discard=on,size=250G,ssd=1
```

Verify that the corresponding storage is active:

```bash
pvesm status | grep '^ext-ssd'
```

Then list volumes belonging to VM `900` on that storage:

```bash
pvesm list ext-ssd --vmid 900
```

This verifies that the referenced virtual disk exists on the expected storage.

If the actual storage name is different, substitute it:

```bash
pvesm list <STORAGE-NAME> --vmid 900
```

---

# 2.12 Verify the Existing Disk Size

If the system disk is `scsi0`:

```bash
qm config 900 | grep '^scsi0:'
```

Example:

```text
scsi0: ext-ssd:vm-900-disk-0,discard=on,size=250G,ssd=1
```

For this lab, the desired allocation is:

```text
250 GB
```

If the existing disk is already `250G`, leave it unchanged.

If it is at least large enough for the intended Security Onion deployment, there is no reason to create another system disk merely because the guest OS is being reinstalled.

> A clean Security Onion reinstall can reuse the existing virtual disk. The installer will erase and repartition that virtual disk.

---

# 2.13 Increase the Existing Disk Only If Required

If the existing system disk is smaller than the desired size, it can be enlarged.

For example, if `scsi0` is `200G` and needs to become `250G`:

```bash
qm resize 900 scsi0 +50G
```

Verify:

```bash
qm config 900 | grep '^scsi0:'
```

If the existing disk uses another bus, use that verified disk identifier instead.

For example:

```bash
qm resize 900 virtio0 +50G
```

> **Important:** Expansion is straightforward, but virtual disks should not be casually reduced in size.
>
> Do not resize the disk if it already meets the lab requirement.

---

# 2.14 Do Not Change the Existing Disk Bus Blindly

If the existing system disk is:

```text
scsi0
```

and the controller is:

```text
scsihw: virtio-scsi-pci
```

leave it configured that way.

Verify:

```bash
qm config 900 | grep -E '^scsihw:|^scsi0:'
```

For a newly created VM in this guide, the preferred configuration is:

```text
scsihw: virtio-scsi-pci
scsi0: <STORAGE>:<VOLUME>
```

However, if an existing VM currently boots from:

```text
sata0
```

or:

```text
virtio0
```

do **not** simply change the controller or disk bus as part of the reinstall.

Changing a disk from one virtual bus to another is a separate operation and is unnecessary if the existing configuration is functioning correctly.

---

# 2.15 Update CPU and Memory on an Existing VM

For VM `900`, configure:

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

# 2.16 Verify the Management NIC

Display the VM network interfaces:

```bash
qm config 900 | grep '^net'
```

For this lab, the validated management NIC is:

```text
net0: virtio=BC:24:11:65:9F:86,bridge=vmbr0
```

Its path is:

```text
Security Onion net0
        │
        ▼
      vmbr0
        │
        ▼
      nic0
        │
        ▼
Cisco Gi1/0/27
        │
        ▼
Native/Untagged VLAN 99
```

The Security Onion guest will later configure this interface as:

```text
Expected Guest NIC: ens18
Address:            172.16.99.30/24
Gateway:            172.16.99.1
```

There should be **no Proxmox `tag=99`** on `net0` in this topology.

Correct:

```text
net0: virtio=BC:24:11:65:9F:86,bridge=vmbr0
```

Incorrect:

```text
net0: virtio=BC:24:11:65:9F:86,bridge=vmbr0,tag=99
```

This is because Cisco Gi1/0/27 carries VLAN 99 as the native/untagged VLAN.

---

# 2.17 Correct the Management NIC Only If Necessary

If the existing configuration contains `tag=99`, correct it while preserving the existing MAC address:

```bash
qm set 900 \
  --net0 virtio=BC:24:11:65:9F:86,bridge=vmbr0
```

Verify:

```bash
qm config 900 | grep '^net0:'
```

Expected:

```text
net0: virtio=BC:24:11:65:9F:86,bridge=vmbr0
```

If the existing management NIC already matches this configuration, **do not recreate it**.

---

# 2.18 Verify the Passive Capture NIC

For this lab, the validated monitoring NIC is:

The passive capture path must use MTU 9000 end-to-end so that Security Onion `ens19` can join the `bond0` monitoring interface used by Suricata.

```text
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

Its physical path is:

```text
Security Onion net1
        │
        ▼
      vmbr1
        │
        ▼
      nic1
        │
        ▼
Cisco Gi1/0/28
        │
        ▼
SPAN Destination
```

The capture NIC must have:

```text
Bridge:           vmbr1
VLAN Tag:         NONE
Proxmox Firewall: Disabled
MTU:              9000
Guest IP:         NONE
Guest Gateway:    NONE
```

After Security Onion Setup, this interface is expected to appear as:

```text
ens19
```

and will be used strictly for passive packet capture.

---

# 2.19 Correct the Capture NIC Only If Necessary

If required, restore the validated configuration:

```bash
qm set 900 \
  --net1 virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

Verify:

```bash
qm config 900 | grep '^net1:'
```

Expected:

```text
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

Do not add:

```text
tag=10
```

to this interface.

The SPAN destination traffic should be passed transparently through `vmbr1` to Security Onion.

---

# 2.20 Preserve Existing NIC MAC Addresses

When reinstalling an existing Security Onion VM, preserve the known-good MAC addresses whenever possible:

```text
net0 MAC: BC:24:11:65:9F:86
net1 MAC: BC:24:11:EE:90:F1
```

This helps maintain predictable guest interface identification:

```text
net0 → ens18
net1 → ens19
```

After installation, always verify the actual guest interface/MAC mapping rather than relying solely on the interface names.

---

# 2.21 Verify or Attach the Security Onion ISO

Check the existing virtual CD/DVD configuration:

```bash
qm config 900 | grep '^ide2:'
```

If the verified Security Onion ISO is already attached:

```text
ide2: local:iso/securityonion-3.2.0.iso,media=cdrom
```

no change is required.

If it is missing or another ISO is attached, configure the verified ISO:

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

# 2.22 Configure the Installation Boot Order

During installation, Security Onion must boot from the ISO before the existing virtual system disk.

### New VM Created by This Guide

For a newly created VM, the system disk is `scsi0`.

Configure:

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

This means:

```text
1. ide2  → Security Onion installation ISO
2. scsi0 → Virtual system disk
```

---

## Existing VM: Use the Verified System Disk Identifier

If the existing system disk was identified as `scsi0`, use:

```bash
qm set 900 --boot "order=ide2;scsi0"
```

If it was identified as `virtio0`, use:

```bash
qm set 900 --boot "order=ide2;virtio0"
```

If it was identified as `sata0`, use:

```bash
qm set 900 --boot "order=ide2;sata0"
```

Therefore:

```text
Installation boot order:

ide2 → VERIFIED SYSTEM DISK
```

> **Do not blindly use `scsi0` for an existing VM.**
>
> The second boot device must match the actual system-disk bus previously identified from `qm config 900`.

Also keep the boot-order argument inside quotation marks:

```bash
"order=ide2;scsi0"
```

because the semicolon has special meaning to the Linux shell.

---

# 2.23 Enable QEMU Guest Agent Support

Enable QEMU Guest Agent support in Proxmox:

```bash
qm set 900 --agent 1
```

Verify:

```bash
qm config 900 | grep '^agent:'
```

Expected:

```text
agent: 1
```

This enables Proxmox guest-agent integration when the corresponding agent is available and running inside the guest.

---

# 2.24 Enable Automatic Startup

Configure Security Onion to start automatically with the Proxmox host:

```bash
qm set 900 --onboot 1
```

Verify:

```bash
qm config 900 | grep '^onboot:'
```

Expected:

```text
onboot: 1
```

---

# 2.25 Perform the Final Pre-Installation Audit

Before starting VM `900`, perform one complete validation.

Run:

```bash
echo "=== VM STATUS ==="
qm status 900

echo
echo "=== CPU / MEMORY ==="
qm config 900 | grep -E '^cpu:|^cores:|^memory:|^balloon:'

echo
echo "=== PROXMOX STORAGE ==="
pvesm status

echo
echo "=== VM DISKS ==="
qm config 900 | grep -E '^(scsi|sata|virtio)[0-9]+:|^scsihw:|^unused'

echo
echo "=== INSTALLATION ISO ==="
qm config 900 | grep '^ide2:'

echo
echo "=== NETWORK INTERFACES ==="
qm config 900 | grep '^net'

echo
echo "=== BOOT ORDER ==="
qm config 900 | grep '^boot:'

echo
echo "=== GUEST AGENT / STARTUP ==="
qm config 900 | grep -E '^agent:|^onboot:'
```

Review the results carefully.

For the VM configuration used in this lab, the important values should resemble:

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

net0: virtio=BC:24:11:65:9F:86,bridge=vmbr0
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000

scsi0: <VERIFIED-STORAGE>:<VERIFIED-VOLUME>,...,size=250G
ide2: local:iso/securityonion-3.2.0.iso,media=cdrom
```

The exact storage and volume names must match the actual values returned by Proxmox.

---

# 2.26 Pre-Installation Checklist

Before booting the Security Onion installer, confirm:

* [ ] VM `900` exists.
* [ ] Existing VM configuration was backed up if applicable.
* [ ] Exact Proxmox storage name was verified.
* [ ] Intended storage reports `active`.
* [ ] Existing system-disk bus was identified.
* [ ] Existing disk volume name was identified.
* [ ] Existing disk size was verified.
* [ ] No unnecessary second system disk was created.
* [ ] Security Onion ISO filename was verified.
* [ ] Correct ISO is attached to `ide2`.
* [ ] CPU type is `host`.
* [ ] VM has 8 vCPU.
* [ ] VM has 24 GB RAM.
* [ ] Memory ballooning is disabled.
* [ ] `net0` connects to `vmbr0`.
* [ ] `net0` has no Proxmox VLAN tag.
* [ ] `net1` connects to `vmbr1`.
* [ ] `net1` has no Proxmox VLAN tag.
* [ ] Proxmox firewall is disabled on `net1`.
* [ ] Existing validated NIC MAC addresses were preserved.
* [ ] ISO is first in the installation boot order.
* [ ] The actual system disk is second in the installation boot order.
* [ ] QEMU Guest Agent support is enabled.
* [ ] Start on Boot is enabled.

---

# 2.27 Start the Security Onion Installer

Once all checks pass:

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
    │
    ▼
VM 900
    │
    ▼
Console
```

The virtual machine should boot from the Security Onion ISO.

Proceed with the Security Onion operating-system installation described in **Step 3**.

> **Existing VM Warning**
>
> During the clean reinstall, select the verified VM system disk as the Security Onion installation target.
>
> The installer will erase the data on that **virtual disk**.
>
> It does not require:
>
> * Deleting VM `900`
> * Recreating `vmbr0`
> * Recreating `vmbr1`
> * Recreating the virtual NICs
> * Changing the validated MAC addresses
> * Wiping the underlying Proxmox storage pool

---

# 2.28 Post-Installation Boot Order — Required

After the Security Onion base operating system has finished installing, the VM must stop booting from the ISO first.

This is a **required post-installation step**.

The installation boot order:

```text
ide2 → system disk
```

must be changed to:

```text
system disk → ide2
```

or preferably:

```text
system disk only
```

---

## 2.28.1 Stop the VM If Necessary

After installation completes and the installer requests a reboot, ensure the VM is stopped before modifying its virtual hardware if necessary.

Check:

```bash
qm status 900
```

If required:

```bash
qm shutdown 900
```

Verify:

```bash
qm status 900
```

Expected:

```text
status: stopped
```

---

# 2.29 Change the Boot Order After Installation

Use the **actual verified system-disk identifier**.

### If the System Disk Is `scsi0`

Run:

```bash
qm set 900 --boot "order=scsi0;ide2"
```

Verify:

```bash
qm config 900 | grep '^boot:'
```

Expected:

```text
boot: order=scsi0;ide2
```

### If the System Disk Is `virtio0`

Use:

```bash
qm set 900 --boot "order=virtio0;ide2"
```

### If the System Disk Is `sata0`

Use:

```bash
qm set 900 --boot "order=sata0;ide2"
```

The principle is:

```text
POST-INSTALL:

1. VERIFIED SYSTEM DISK
2. ide2
```

This causes the installed Security Onion operating system to boot before the installation media.

---

# 2.30 Recommended — Eject the Installation ISO

After confirming that Security Onion has installed successfully, the installation ISO is no longer required for normal operation.

Detach the ISO:

```bash
qm set 900 --ide2 none,media=cdrom
```

Verify:

```bash
qm config 900 | grep '^ide2:'
```

Then configure the verified system disk as the only boot device.

For `scsi0`:

```bash
qm set 900 --boot "order=scsi0"
```

For `virtio0`:

```bash
qm set 900 --boot "order=virtio0"
```

For `sata0`:

```bash
qm set 900 --boot "order=sata0"
```

Verify:

```bash
qm config 900 | grep '^boot:'
```

For this lab's expected `scsi0` configuration:

```text
boot: order=scsi0
```

---

# 2.31 Boot Order Summary

For the expected VM configuration in this lab:

| Phase                          | Boot Order   | Purpose                                     |
| ------------------------------ | ------------ | ------------------------------------------- |
| Installation                   | `ide2;scsi0` | Boot Security Onion ISO first               |
| Immediately after installation | `scsi0;ide2` | Boot installed Security Onion first         |
| Final configuration            | `scsi0`      | Boot exclusively from installed system disk |

The transition is:

```text
BEFORE INSTALLATION
───────────────────

ide2
  │
  ▼
Security Onion ISO
  │
  ▼
scsi0


AFTER INSTALLATION
──────────────────

scsi0
  │
  ▼
Installed Security Onion
```

> **Do not leave `ide2` first in the boot order after installation.**
>
> Doing so may cause the VM to return to the installation environment instead of booting the installed Security Onion system.

---

# 2.32 Final Post-Installation Proxmox Verification

After changing the boot order and removing the ISO, perform one final Proxmox-side check:

```bash
qm config 900
```

For this lab, the final configuration should conceptually resemble:

```text
agent: 1
balloon: 0
boot: order=scsi0
cores: 8
cpu: host
memory: 24576
name: SecurityOnion-3.2
onboot: 1

net0: virtio=BC:24:11:65:9F:86,bridge=vmbr0
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000

scsihw: virtio-scsi-pci
scsi0: <VERIFIED-STORAGE>:<VERIFIED-VOLUME>,...,size=250G
ide2: none,media=cdrom
```

Verify specifically:

```bash
qm config 900 | grep -E \
'^boot:|^cpu:|^cores:|^memory:|^balloon:|^scsihw:|^scsi0:|^ide2:|^net0:|^net1:|^agent:|^onboot:'
```

---

## 2.32A Verify the Capture MTU

Before booting Security Onion, verify that Proxmox presents the complete capture path at MTU 9000:

```bash
ip link show nic1 | head -1
ip link show vmbr1 | head -1
qm config 900 | grep '^net1:'
```

Expected:

```text
nic1  ... mtu 9000
vmbr1 ... mtu 9000
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

The management path (`nic0`, `vmbr0`, and `net0`) remains MTU 1500.

---

# 2.33 Final VM Hardware Matrix

| Component                 | Configuration                               |
| ------------------------- | ------------------------------------------- |
| VM ID                     | `900`                                       |
| Name                      | `SecurityOnion-3.2`                         |
| OS Type                   | Linux (`l26`)                               |
| CPU Type                  | `host`                                      |
| vCPU                      | `8`                                         |
| RAM                       | `24576 MB`                                  |
| Ballooning                | Disabled                                    |
| System Disk               | Verified existing disk or new `250 GB` disk |
| Preferred New-VM Disk Bus | `scsi0`                                     |
| SCSI Controller           | `virtio-scsi-pci`                           |
| Management NIC            | `net0` → `vmbr0`                            |
| Management VLAN Tag       | **None**                                    |
| Capture NIC               | `net1` → `vmbr1`                            |
| Capture VLAN Tag          | **None**                                    |
| Capture NIC Firewall      | **Disabled**                                |
| Installation Media        | Verified Security Onion 3.2.x ISO           |
| Installation Boot Order   | `ide2` → system disk                        |
| Final Boot Order          | system disk only                            |
| Guest Agent               | Enabled                                     |
| Start on Boot             | Enabled                                     |

---

# 2.34 Decision Summary

```text
START
  │
  ▼
Check VM 900
  │
  ├────────────── VM DOES NOT EXIST ──────────────┐
  │                                               │
  │                                      Verify storage name
  │                                               │
  │                                      Verify ISO filename
  │                                               │
  │                                        Create VM 900
  │                                               │
  │                                     Create 250 GB scsi0
  │                                               │
  │                                      Verify configuration
  │                                               │
  └───────────────────────────────────────────────┤
                                                  │
  ┌────────────── VM ALREADY EXISTS ──────────────┤
  │                                               │
  │                                      Back up qm config
  │                                               │
  │                                      Stop existing VM
  │                                               │
  │                                      Identify disk bus
  │                                               │
  │                                      Identify storage
  │                                               │
  │                                      Verify volume
  │                                               │
  │                                      Verify disk size
  │                                               │
  │                                  Preserve disk if correct
  │                                               │
  │                                  Preserve validated MACs
  │                                               │
  │                                  Update CPU/RAM if needed
  │                                               │
  └───────────────────────────────────────────────┤
                                                  │
                                                  ▼
                                         Attach verified ISO
                                                  │
                                                  ▼
                                 Set ISO-first boot order
                                                  │
                                                  ▼
                                     Install Security Onion
                                                  │
                                                  ▼
                                Change to disk-first boot order
                                                  │
                                                  ▼
                                      Detach installation ISO
                                                  │
                                                  ▼
                                   Set system disk only to boot
                                                  │
                                                  ▼
                                                DONE
```

---

# 2.35 Final Rule

Before modifying VM `900`, always verify:

```bash
qm config 900
pvesm status
```

For an existing VM, also verify its actual disk:

```bash
qm config 900 | grep -E '^(scsi|sata|virtio)[0-9]+:'
```

and verify the corresponding storage:

```bash
pvesm list <VERIFIED-STORAGE> --vmid 900
```

The rules for this deployment are:

```text
VM does not exist
    → qm create

VM already exists
    → inspect and use qm set

Disk already exists and is correctly sized
    → reuse it

Storage already exists and is healthy
    → do not recreate or wipe it

Validated NICs already exist
    → preserve them and their MAC addresses

During installation
    → ISO first, system disk second

After installation
    → system disk first

Final configuration
    → eject ISO and boot from system disk only
```

Once this step is complete, continue to:

# Step 3: Install the Security Onion 3.2.x Base Operating System
