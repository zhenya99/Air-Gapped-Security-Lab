# Step 2: Provision the Security Onion 3.2.x Virtual Machine

With the Proxmox network backbone, storage, and Security Onion ISO validated in **Step 1**, the next stage is to provision the Security Onion virtual machine.

This lab uses **VM ID `900`** and deploys Security Onion as a dual-interface **Standalone** sensor.

The VM is configured with:

| Component          | Configuration            |
| ------------------ | ------------------------ |
| VM ID              | `900`                    |
| Name               | `SecurityOnion-3.2`      |
| CPU Type           | `host`                   |
| CPU Cores          | `8`                      |
| Memory             | `24 GB`                  |
| Memory Ballooning  | Disabled                 |
| System Disk        | `250 GB`                 |
| Disk Controller    | VirtIO SCSI              |
| Management NIC     | `net0` → `vmbr0`         |
| Capture NIC        | `net1` → `vmbr1`         |
| Installation Media | Security Onion 3.2.x ISO |
| QEMU Guest Agent   | Enabled                  |
| Start on Boot      | Enabled                  |

> **Important:** Security Onion `net0` does **not** use Proxmox VLAN tag `99` in this topology. Cisco Gi1/0/27 carries VLAN 99 as the native/untagged management VLAN.
>
> Security Onion `net1` also has **no VLAN tag**. It receives raw mirrored traffic from the dedicated Cisco SPAN destination through `vmbr1`.

---

## 2.1 Verify Whether VM 900 Already Exists

Before creating the virtual machine, check whether VM ID `900` is already present:

```bash id="xrpg7d"
qm status 900
```

If VM `900` already exists, inspect its configuration:

```bash id="f3pymv"
qm config 900
```

For a clean operating-system reinstall inside the existing VM, **do not run `qm create 900` again**.

Instead, preserve the existing VM hardware configuration and proceed to the ISO attachment and verification sections below.

If VM `900` does not exist, continue with the new VM creation procedure.

---

## 2.2 Verify the Target Storage Name

Before creating the virtual disk, verify the exact Proxmox storage identifier:

```bash id="7nuxla"
pvesm status
```

Identify the storage reserved for Security Onion.

For example:

```text id="onrvt3"
Name       Type      Status
ext-ssd    lvmthin   active
```

If your storage has a different name, substitute that storage identifier throughout the commands below.

> **Important:** Do not assume the storage name is `ext-ssd`. Use the exact storage identifier shown by `pvesm status`.

---

## 2.3 Verify the Security Onion ISO Name

List the ISO images available in Proxmox:

```bash id="obdkwj"
pvesm list local --content iso
```

Alternatively:

```bash id="6haik7"
ls -lh /var/lib/vz/template/iso/
```

Confirm the exact ISO filename.

For this deployment:

```text id="e9ngev"
securityonion-3.2.0.iso
```

The ISO path used by Proxmox is:

```text id="cpt1js"
local:iso/securityonion-3.2.0.iso
```

---

# 2.4 Create the Virtual Machine

If VM `900` does **not** already exist, create it from the Proxmox shell:

```bash id="js1igo"
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

> Replace `ext-ssd` with the actual Security Onion storage identifier if your Proxmox storage uses a different name.

### Why `--cpu host` Is Used

The VM uses:

```text id="2exkyg"
--cpu host
```

This exposes the physical host CPU capabilities directly to the Security Onion guest instead of relying on Proxmox's generic virtual CPU model.

This is especially useful for Suricata, Zeek, Elasticsearch, and other CPU-intensive Security Onion services.

---

# 2.5 Management NIC — `net0`

The management interface is configured as:

```text id="pke1j4"
net0
  ↓
vmbr0
  ↓
nic0
  ↓
Cisco Gi1/0/27
  ↓
Native VLAN 99
  ↓
172.16.99.0/24
```

The Proxmox configuration is:

```text id="naxz0c"
virtio,bridge=vmbr0
```

There is deliberately **no**:

```text id="6n25jf"
tag=99
```

because VLAN 99 is transported as the native/untagged management VLAN on Cisco Gi1/0/27.

After installation, Security Onion will use:

```text id="pnqbsh"
Guest Interface: ens18
IP Address:      172.16.99.30/24
Gateway:         172.16.99.1
```

### Correct

```text id="alnoq4"
net0: virtio=...,bridge=vmbr0
```

### Incorrect for This Topology

```text id="2rhkuk"
net0: virtio=...,bridge=vmbr0,tag=99
```

Adding `tag=99` would cause Proxmox to explicitly tag the VM traffic even though the physical switch connection is already using VLAN 99 as its native VLAN.

---

# 2.6 Passive Capture NIC — `net1`

The Security Onion monitoring interface is configured as:

```text id="r09fja"
net1
  ↓
vmbr1
  ↓
nic1
  ↓
Cisco Gi1/0/28
  ↓
SPAN Destination
```

The Proxmox configuration is:

```text id="x251r0"
virtio,bridge=vmbr1,firewall=0
```

The capture NIC must have:

```text id="j4yc1s"
VLAN Tag:        Blank
Proxmox Firewall: Disabled
Guest IP:         None
Gateway:          None
```

After installation, this interface is expected to appear inside Security Onion as:

```text id="z79i3z"
ens19
```

and will be dedicated exclusively to passive packet acquisition.

The complete capture path is:

```text id="bpogqp"
VLAN 10 Traffic
      │
      ▼
Cisco Catalyst 2960-X
      │
SPAN Source: VLAN 10
      │
      ▼
Gi1/0/28
      │
      ▼
Proxmox nic1
      │
      ▼
vmbr1
      │
      ▼
VM 900 net1
      │
      ▼
Security Onion ens19
      │
      ├── Suricata
      └── Zeek
```

---

# 2.7 Verify the VM Configuration

After creating the VM, inspect the complete configuration:

```bash id="8fgugc"
qm config 900
```

Pay particular attention to:

```text id="k1rk8p"
cpu
cores
memory
balloon
scsi0
scsihw
ide2
boot
net0
net1
agent
onboot
```

For a newly created VM, the configuration should conceptually contain:

```text id="uyrm5m"
agent: 1
balloon: 0
boot: order=ide2;scsi0
cores: 8
cpu: host
memory: 24576
name: SecurityOnion-3.2
ostype: l26
scsihw: virtio-scsi-pci

net0: virtio=<MAC>,bridge=vmbr0
net1: virtio=<MAC>,bridge=vmbr1,firewall=0

scsi0: ext-ssd:vm-900-disk-0,size=250G
ide2: local:iso/securityonion-3.2.0.iso,media=cdrom
```

The exact disk syntax and automatically generated MAC addresses may differ.

---

## 2.8 Verify the Network Bindings

Display only the VM network devices:

```bash id="d67v6h"
qm config 900 | grep '^net'
```

For this lab, the existing validated configuration is:

```text id="svgepq"
net0: virtio=BC:24:11:90:67:75,bridge=vmbr0
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,firewall=0
```

This is the desired configuration.

### Network Mapping

| VM NIC | Bridge  | VLAN Tag  | Firewall         | Purpose              |
| ------ | ------- | --------- | ---------------- | -------------------- |
| `net0` | `vmbr0` | **Blank** | Optional/Enabled | Management           |
| `net1` | `vmbr1` | **Blank** | **Disabled**     | Passive SPAN capture |

> **Do not add VLAN tag `99` to `net0`.**
>
> **Do not add VLAN tag `10` to `net1`.**
>
> The SPAN interface must receive the mirrored traffic exactly as delivered through `vmbr1`.

---

# 2.9 Verify the VM Disk

Check the virtual disk:

```bash id="vk43ce"
qm config 900 | grep -E '^scsi|^virtio'
```

The primary Security Onion disk should be attached as `scsi0`.

Example:

```text id="uzc0dd"
scsihw: virtio-scsi-pci
scsi0: ext-ssd:vm-900-disk-0,size=250G
```

Verify the underlying storage:

```bash id="sz7vk6"
pvesm status
```

The storage containing the Security Onion virtual disk must report:

```text id="64cuxk"
active
```

---

# 2.10 Verify the Installation ISO

Check:

```bash id="vsz9es"
qm config 900 | grep ide2
```

Expected:

```text id="bhku36"
ide2: local:iso/securityonion-3.2.0.iso,media=cdrom
```

If the ISO is not attached, attach it:

```bash id="y31nn1"
qm set 900 \
  --ide2 local:iso/securityonion-3.2.0.iso,media=cdrom
```

---

# 2.11 Configure the Installation Boot Order

During installation, the VM must attempt to boot from the Security Onion ISO before the virtual disk.

Set:

```bash id="k96wb8"
qm set 900 --boot "order=ide2;scsi0"
```

Verify:

```bash id="66z2oy"
qm config 900 | grep '^boot'
```

Expected:

```text id="g58sh9"
boot: order=ide2;scsi0
```

> **Important:** The semicolon in `order=ide2;scsi0` has special meaning to the Linux shell. Keep the entire boot-order value inside quotation marks.

### Installation Boot Order

```text id="u2ezcz"
1. ide2  → Security Onion ISO
2. scsi0 → Security Onion system disk
```

---

# 2.12 Existing VM 900 — Clean Reinstallation Path

If VM `900` already exists and you are reinstalling Security Onion inside the existing VM, preserve the validated virtual hardware instead of recreating it.

First shut down the VM:

```bash id="7x5rip"
qm shutdown 900
```

Check its status:

```bash id="4ukc7x"
qm status 900
```

Expected:

```text id="a85iab"
status: stopped
```

If the guest does not shut down cleanly, use:

```bash id="g8bf68"
qm stop 900
```

Then verify the existing NICs:

```bash id="60h8hs"
qm config 900 | grep '^net'
```

Expected:

```text id="ljdyht"
net0: virtio=BC:24:11:90:67:75,bridge=vmbr0
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,firewall=0
```

Attach the Security Onion ISO:

```bash id="vdw66g"
qm set 900 \
  --ide2 local:iso/securityonion-3.2.0.iso,media=cdrom
```

Set the installation boot order:

```bash id="pjs3g1"
qm set 900 --boot "order=ide2;scsi0"
```

Verify:

```bash id="amsw1p"
qm config 900
```

> **Important:** A clean Security Onion installation will erase the operating system and data contained inside the selected VM disk. It does **not** require destroying or reformatting the underlying Proxmox storage pool.

---

# 2.13 QEMU Guest Agent

Enable QEMU Guest Agent support:

```bash id="m89twm"
qm set 900 --agent 1
```

This allows Proxmox to communicate with the guest agent once the corresponding software is installed and running inside the Security Onion VM.

Potential benefits include:

* Graceful guest shutdown requests
* Guest IP visibility in Proxmox
* Improved guest status reporting
* Filesystem freeze/thaw integration for compatible backup workflows

Verify:

```bash id="hq1yr5"
qm config 900 | grep '^agent'
```

Expected:

```text id="5icbhm"
agent: 1
```

---

# 2.14 Configure Automatic Startup

Security Onion provides the monitoring and detection layer for the lab.

Configure the VM to start automatically when the Proxmox host boots:

```bash id="dnqoub"
qm set 900 --onboot 1
```

Verify:

```bash id="srqh9i"
qm config 900 | grep '^onboot'
```

Expected:

```text id="j2mde6"
onboot: 1
```

---

# 2.15 Start the VM

After verifying the VM configuration, start Security Onion:

```bash id="byn5q2"
qm start 900
```

Verify:

```bash id="61sk8b"
qm status 900
```

Expected:

```text id="5t8irz"
status: running
```

---

# 2.16 Open the Proxmox Console

Open the Proxmox Web GUI:

```text id="f02i5d"
https://172.16.99.20:8006
```

Navigate to:

```text id="an5msv"
Datacenter
└── lab
    └── VM 900 — SecurityOnion-3.2
        └── Console
```

The VM should boot from the Security Onion ISO.

At this stage, **do not begin modifying Security Onion networking manually**.

The ISO installer will first install the base operating system. Security Onion Setup will configure the management and monitoring interfaces after the initial OS installation and reboot.

---

# 2.17 Post-Installation Boot Order

After the Security Onion operating system has been successfully installed, the VM should boot from its virtual disk rather than returning to the installation ISO.

Shut down the VM if necessary:

```bash id="yz1093"
qm shutdown 900
```

Then change the boot order:

```bash id="1b0pgm"
qm set 900 --boot "order=scsi0;ide2"
```

Verify:

```bash id="1fkivw"
qm config 900 | grep '^boot'
```

Expected:

```text id="z6lbci"
boot: order=scsi0;ide2
```

Alternatively, remove the ISO from the virtual CD/DVD drive after installation and configure:

```bash id="v4aubc"
qm set 900 --boot "order=scsi0"
```

### Boot Order Summary

During installation:

```text id="5fxysc"
ide2 → scsi0
```

After installation:

```text id="z729fc"
scsi0 → ide2
```

or:

```text id="84mapf"
scsi0 only
```

This prevents the VM from repeatedly booting into the Security Onion installer.

---

# 2.18 Final VM Hardware Matrix

| Component        | Required Configuration |
| ---------------- | ---------------------- |
| VM ID            | `900`                  |
| Name             | `SecurityOnion-3.2`    |
| OS Type          | Linux (`l26`)          |
| CPU              | `host`                 |
| vCPU             | `8`                    |
| RAM              | `24576 MB`             |
| Ballooning       | Disabled               |
| SCSI Controller  | `virtio-scsi-pci`      |
| Primary Disk     | `250 GB`               |
| Installation ISO | Security Onion 3.2.x   |
| `net0`           | VirtIO → `vmbr0`       |
| `net0` VLAN Tag  | **Blank**              |
| `net1`           | VirtIO → `vmbr1`       |
| `net1` VLAN Tag  | **Blank**              |
| `net1` Firewall  | **Disabled**           |
| Guest Agent      | Enabled                |
| Start on Boot    | Enabled                |

---

# 2.19 Final Network Architecture

```text id="laoc25"
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

The two Security Onion interfaces have intentionally separate responsibilities:

```text id="w0d7tw"
ens18 = Management
ens19 = Passive Monitoring
```

Only `ens18` will receive an IP address.

`ens19` must remain a passive sniffing interface.

---

# 2.20 Pre-Installation Verification Checklist

Before proceeding to **Step 3**, confirm:

* [ ] VM `900` exists
* [ ] CPU type is `host`
* [ ] 8 CPU cores are assigned
* [ ] 24 GB RAM is assigned
* [ ] Ballooning is disabled
* [ ] Security Onion disk is at least 200 GB
* [ ] `scsi0` is stored on the intended Security Onion storage
* [ ] VirtIO SCSI controller is configured
* [ ] Security Onion ISO is attached
* [ ] Installation boot order is `ide2;scsi0`
* [ ] `net0` is attached to `vmbr0`
* [ ] `net0` has **no Proxmox VLAN tag**
* [ ] `net1` is attached to `vmbr1`
* [ ] `net1` has **no Proxmox VLAN tag**
* [ ] Proxmox firewall is disabled on `net1`
* [ ] QEMU Guest Agent is enabled
* [ ] Start on Boot is enabled
* [ ] Proxmox console opens successfully
* [ ] VM boots from the Security Onion installation ISO

Once these checks pass, continue to:

**Step 3: Install the Security Onion 3.2.x Base Operating System**
