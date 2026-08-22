# Step 1: Environment Staging and Pre-Installation Validation

Before creating or reinstalling the Security Onion virtual machine, verify that the Proxmox VE host has sufficient resources, the Security Onion ISO has been validated and transferred successfully, the dedicated storage is available, and the previously configured network backbone is operational.

This lab deploys **Security Onion 3.2.x** as a **Standalone** node using two separate network interfaces:

* **Management:** `vmbr0` → Cisco Gi1/0/27
* **Passive SPAN capture:** `vmbr1` → Cisco Gi1/0/28

> **Important:** This step assumes the Proxmox host, external Security Onion storage, `vmbr0`, and `vmbr1` have already been configured. Do not wipe or reformat an existing storage device during a Security Onion reinstall unless you intentionally want to destroy the underlying Proxmox storage pool.

---

## 1.1 Connect to the Proxmox Host

From the Windows 11 administrative workstation, open PowerShell and connect to the Proxmox host:

```bash
ssh root@172.16.99.20
```

If local hostname resolution is configured, the shorter hostname may also be used:

```bash
ssh root@lab
```

The Proxmox management interface should be reachable at:

```text
172.16.99.20/24
```

with the default gateway:

```text
172.16.99.1
```

---

## 1.2 Verify Proxmox Host Resources

From the Proxmox shell, verify CPU, memory, filesystem, block-device, and node status:

```bash
lscpu
```

```bash
pvesh get /nodes/localhost/status
```

```bash
free -h
```

```bash
df -h
```

```bash
lsblk
```

Also verify the available Proxmox storage pools:

```bash
pvesm status
```

### Security Onion Standalone Requirements

Security Onion Standalone requires, at minimum:

| Resource           | Minimum | Lab Allocation |
| ------------------ | ------: | -------------: |
| CPU                | 4 cores |    **8 cores** |
| RAM                |   24 GB |      **24 GB** |
| Storage            |  200 GB |     **250 GB** |
| Network Interfaces |       2 |          **2** |

> **Resource Note:** 24 GB of RAM is the bare minimum for a Standalone installation. If additional host memory is available, 32 GB or more is preferable when monitoring live network traffic.

The lab VM is therefore provisioned with:

```text
CPU:       8 vCPU
RAM:       24 GB
Disk:      250 GB
NICs:      2
CPU Type:  host
```

---

## 1.3 Verify the Existing Security Onion Storage

Before creating or reinstalling the VM, confirm that the dedicated Security Onion storage is available:

```bash
pvesm status
```

Also inspect the underlying disks:

```bash
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINTS
```

The dedicated Security Onion storage should appear as an active Proxmox storage target.

For this lab, the dedicated external SSD is reserved for the Security Onion VM and its high-volume workloads, including:

* Elasticsearch data
* Suricata telemetry
* Zeek telemetry
* Full packet capture
* Alert data
* Case data
* Log retention

### Do Not Reformat Existing Storage During a Reinstall

If the Security Onion storage already appears as **Active** in:

```bash
pvesm status
```

do **not** run destructive commands such as:

```bash
wipefs
sgdisk --zap-all
pvcreate
vgcreate
mkfs
```

A clean Security Onion reinstall only requires wiping/replacing the **virtual machine disk**, not destroying the underlying Proxmox storage pool.

> **Warning:** Commands such as `wipefs` and `sgdisk --zap-all` permanently destroy partition and filesystem information. They should only be used when intentionally preparing a new, empty storage device.

---

## 1.4 Download and Verify the Security Onion ISO

Download the required **Security Onion 3.2.x ISO** from the official Security Onion project.

Before transferring or booting the image, verify its SHA-256 checksum against the checksum published by Security Onion.

From Windows PowerShell:

```powershell
Get-FileHash "C:\Users\YourUser\Downloads\securityonion-3.2.0.iso" -Algorithm SHA256
```

Compare the resulting SHA-256 value with the official Security Onion checksum.

> **Security Requirement:** Never boot an ISO that fails checksum verification. A checksum mismatch may indicate an incomplete, corrupted, or modified installation image.

---

## 1.5 Transfer the ISO to Proxmox

From the Windows 11 workstation, transfer the verified ISO to the Proxmox ISO directory:

```powershell
scp "C:\Users\YourUser\Downloads\securityonion-3.2.0.iso" root@172.16.99.20:/var/lib/vz/template/iso/
```

Replace:

```text
YourUser
```

with the actual Windows username, and confirm that the filename exactly matches the downloaded Security Onion ISO.

---

## 1.6 Verify the ISO on Proxmox

After the transfer completes, reconnect to the Proxmox host if necessary:

```bash
ssh root@172.16.99.20
```

List the ISO images available in local Proxmox storage:

```bash
pvesm list local --content iso
```

The Security Onion ISO should appear in the output.

You can also verify the file directly:

```bash
ls -lh /var/lib/vz/template/iso/
```

For additional integrity verification, calculate the checksum again on the Proxmox host:

```bash
sha256sum /var/lib/vz/template/iso/securityonion-3.2.0.iso
```

The hash must match the value verified on the Windows workstation and the checksum published by Security Onion.

---

## 1.7 Verify the Proxmox Network Backbone

Before installing Security Onion, verify the management and passive-capture bridges.

Run:

```bash
ip -br addr
```

The expected topology is:

```text
nic0     UP
nic1     UP
vmbr0    UP    172.16.99.20/24
vmbr1    UP    no IPv4 address
```

An automatically generated IPv6 link-local address on `vmbr1`, such as `fe80::/64`, is not an IPv4 management address and does not change the intended passive Layer 2 role of the bridge.

---

## 1.8 Verify the Routing Table

Run:

```bash
ip route
```

The management network should contain the only default route:

```text
default via 172.16.99.1 dev vmbr0
172.16.99.0/24 dev vmbr0
```

`vmbr1` must not have a default gateway.

---

## 1.9 Verify Physical Bridge Membership

Run:

```bash
bridge link
```

The physical interfaces should map as follows:

```text
nic0 → vmbr0
nic1 → vmbr1
```

The architecture is:

```text
                    CISCO CATALYST 2960-X
                           │
              ┌────────────┴────────────┐
              │                         │
          Gi1/0/27                  Gi1/0/28
              │                         │
   Management + VM VLANs          SPAN Destination
              │                         │
             nic0                      nic1
              │                         │
             vmbr0                    vmbr1
```

### Interface Responsibilities

| Interface | Bridge  | Cisco Port | Purpose                         |
| --------- | ------- | ---------- | ------------------------------- |
| `nic0`    | `vmbr0` | Gi1/0/27   | Proxmox management + VM traffic |
| `nic1`    | `vmbr1` | Gi1/0/28   | Passive SPAN capture            |

---

## 1.10 Verify the Physical Interfaces

Check the management interface:

```bash
ip link show nic0
```

Check the SPAN interface:

```bash
ip link show nic1
```

Both should report:

```text
UP
LOWER_UP
```

The physical interface mapping for this lab is:

| Interface | MAC Address         | Function                     |
| --------- | ------------------- | ---------------------------- |
| `nic0`    | `fc:9d:05:05:87:6c` | Management + live VM traffic |
| `nic1`    | `6c:6e:07:50:e9:18` | Security Onion SPAN capture  |

---

## 1.11 Verify Cisco SPAN Traffic Reaches Proxmox

Before installing Security Onion, verify that VLAN 10 traffic is already arriving at the physical capture NIC.

Run:

```bash
tcpdump -eni nic1 -c 10
```

Expected traffic may include ARP frames such as:

```text
ARP, Request who-has 172.16.10.15 tell 172.16.10.1
```

This confirms:

```text
VLAN 10
   │
   ▼
Cisco SPAN
   │
   ▼
Gi1/0/28
   │
   ▼
Proxmox nic1
```

---

## 1.12 Verify Traffic Reaches the Capture Bridge

Next, verify the same mirrored traffic on `vmbr1`:

```bash
tcpdump -eni vmbr1 -c 10
```

The traffic observed on `vmbr1` should correspond to the traffic observed on `nic1`.

The validated path is now:

```text
Cisco VLAN 10
      │
      ▼
Cisco SPAN
      │
      ▼
Gi1/0/28
      │
      ▼
nic1
      │
      ▼
vmbr1
```

> **Important:** Do not assign an IPv4 address, gateway, or VLAN tag to `vmbr1`. It is used exclusively as a Layer 2 transport path for passive monitoring traffic.

---

## 1.13 Verify Existing VM Bindings Before Reinstallation

If VM `900` already exists and will be reused for the clean Security Onion installation, inspect its current configuration:

```bash
qm config 900
```

To display only its network interfaces:

```bash
qm config 900 | grep '^net'
```

For this lab, the expected bindings are:

```text
net0: virtio=BC:24:11:90:67:75,bridge=vmbr0
net1: virtio=BC:24:11:EE:90:F1,bridge=vmbr1,firewall=0
```

This maps the VM as follows:

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
Management
```

and:

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
SPAN Capture
```

### Management NIC Requirements

```text
Bridge:       vmbr0
VLAN Tag:     Blank
Purpose:      Management
Guest IP:     172.16.99.30/24
Gateway:      172.16.99.1
```

### Capture NIC Requirements

```text
Bridge:       vmbr1
VLAN Tag:     Blank
Firewall:     Disabled
Purpose:      Passive packet capture
Guest IP:     None
Gateway:      None
```

---

## 1.14 Optional: Back Up the Existing VM Configuration

Before reinstalling Security Onion, save the current Proxmox VM configuration:

```bash
qm config 900 > /root/securityonion-vm900-before-reinstall.txt
```

Verify the backup:

```bash
cat /root/securityonion-vm900-before-reinstall.txt
```

This preserves the known-good VM hardware and network mappings before the guest operating system is replaced.

---

## 1.15 Final Pre-Installation Validation

Before continuing to Step 2, verify all of the following:

* [ ] Proxmox management is reachable at `172.16.99.20`
* [ ] Proxmox has sufficient CPU and RAM
* [ ] Security Onion has at least 200 GB of VM storage available
* [ ] Dedicated Security Onion storage reports **Active**
* [ ] Security Onion ISO has been downloaded
* [ ] ISO SHA-256 checksum has been verified
* [ ] ISO is present in Proxmox local ISO storage
* [ ] `nic0` is attached to `vmbr0`
* [ ] `nic1` is attached to `vmbr1`
* [ ] `vmbr0` holds `172.16.99.20/24`
* [ ] `vmbr1` has no IPv4 address
* [ ] Default route uses `172.16.99.1` through `vmbr0`
* [ ] Cisco Gi1/0/27 connects to Proxmox `nic0`
* [ ] Cisco Gi1/0/28 connects to Proxmox `nic1`
* [ ] SPAN traffic is visible on `nic1`
* [ ] SPAN traffic is visible on `vmbr1`
* [ ] Security Onion `net0` is attached to `vmbr0`
* [ ] Security Onion `net1` is attached to `vmbr1`
* [ ] No VLAN tag is configured on Security Onion `net1`
* [ ] Proxmox firewall is disabled on the capture NIC

Once these checks pass, the Proxmox host is ready for:

**Step 2: Provisioning the Security Onion 3.2.x Virtual Machine**
