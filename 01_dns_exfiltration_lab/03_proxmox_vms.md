# 03. Proxmox Virtual Machines

## Purpose

This document explains how the virtual machines for the DNS Exfiltration Detection Lab are planned, created, connected, and validated in Proxmox.

A virtual machine, usually shortened to VM, is a software-based computer that runs inside the physical Proxmox server. Each VM has virtual processors, memory, disks, and network adapters.

All changes documented here are specific to `01_dns_exfiltration_lab/`. The known-good files in `BASELINE_CONFIGURATION/` were not modified.

---

## Simple Proxmox Terms

| Term             | Explanation                            			      |
| ---------------- | ---------------------------------------------------------------- |
| Proxmox          | The virtualization platform that runs the lab VMs                |
| VM               | A software-based computer running inside Proxmox                 |
| VMID             | The unique number Proxmox assigns to a VM                        |
| ISO              | A file that acts like a virtual installation DVD                 |
| Virtual disk     | A file or storage volume used as the VM's hard drive             |
| Storage pool     | A location where Proxmox stores disks, ISOs, or backups          |
| Network bridge   | A virtual network switch used by VMs                             |
| VLAN tag         | A number that places VM traffic into a specific network          |
| VirtIO           | A high-performance virtual device type                           |
| QEMU Guest Agent | Software that improves communication between Proxmox and a VM    |
| Boot order       | The order in which the VM checks devices for an operating system |

---

# Proxmox Resource Check

## Why Resources Were Checked

Before creating a VM, the available processor, memory, and storage capacity should be reviewed.

Creating a VM without checking resources could:

* Use too much host memory.
* Fill the Proxmox system disk.
* Place a VM disk on the wrong storage pool.
* Reduce performance for existing virtual machines.
* Prevent an existing VM from starting.

---

## List Existing Virtual Machines

The following command was used on the Proxmox host:

```bash
qm list
```

### Command Explanation

* `qm` is the Proxmox command-line tool for managing QEMU/KVM virtual machines.
* `list` displays the existing VMs.
* The output includes each VM's ID, name, status, memory allocation, and disk usage.

This command was used to confirm that VMID `901` was available before the DNS-server VM was created.

A VMID must be unique. Two VMs cannot use the same VMID on the same Proxmox cluster.

---

## Display Proxmox Storage

The following command displayed the configured storage pools:

```bash
pvesm status
```

### Command Explanation

* `pvesm` is the Proxmox VE storage-management command.
* `status` displays each storage pool and its current availability.
* The output includes the storage name, type, status, total size, used space, and available space.

This command helped determine where to store the DNS-server virtual disk.

---

## Display Host Memory

The following command displayed the Proxmox host's memory:

```bash
free -h
```

### Command Explanation

* `free` displays memory and swap usage.
* `-h` means human-readable.
* Human-readable output uses units such as MB and GB instead of displaying only bytes.

The `available` column is more useful than the `free` column because Linux uses unused memory for caching and can release that cached memory when applications need it.

---

## Resource Check Results

| Resource                                     | Available capacity             |
| -------------------------------------------- | ------------------------------ |
| Total host memory                            | Approximately 46 GB            |
| Available memory during the check            | Approximately 44 GB            |
| `ext-ssd` storage                            | Approximately 872 GB available |
| `local-lvm` storage                          | Approximately 141 GB available |
| Proxmox `local` storage after the ISO upload | Approximately 6.7 GB available |

The `local` storage pool was already heavily used and is located on the Proxmox operating-system disk.

For that reason:

* Installation ISOs are stored on `local`.
* New VM disks are stored on `ext-ssd`.
* Large VM disks must not be placed on `local`.

---

# Lab VM Plan

| VMID | Name              | Purpose                   |     CPU | Memory |   Disk | Current state           |
| ---: | ----------------- | ------------------------- | ------: | -----: | -----: | ----------------------- |
|  900 | `SecOnion`        | Security Onion monitoring | 8 cores |  24 GB | 250 GB | Existing                |
|  901 | `DNS-SRV-01`      | Ubuntu BIND9 DNS server   | 2 cores |   2 GB |  32 GB | Created and operational |
|  902 | `SPLUNK-SRV-01`   | Splunk detection platform | 4 cores |   8 GB | 100 GB | Planned                 |
|  903 | `WIN11-VICTIM-01` | Windows victim computer   | 4 cores |   6 GB | 100 GB | Planned                 |

If all listed VMs are running with their full planned memory, they use approximately 40 GB.

That leaves approximately 6 GB for Proxmox and its supporting services. This is suitable for a small learning lab, but memory usage must still be monitored.

These allocations are not production sizing recommendations.

---

# VM Network Plan

| Virtual machine interface | Proxmox bridge |                         VLAN | IP address      |
| ------------------------- | -------------- | ---------------------------: | --------------- |
| Security Onion management | `vmbr0`        | Native or management VLAN 99 | `172.16.99.30`  |
| Security Onion monitoring | `vmbr1`        |           Passive monitoring | No IP address   |
| Ubuntu DNS server         | `vmbr0`        |                           66 | `192.168.66.53` |
| Splunk server             | `vmbr0`        | Native or management VLAN 99 | `172.16.99.40`  |
| Windows 11 victim         | `vmbr0`        |                           10 | `172.16.10.50`  |

The DNS server and Windows victim use different VLANs.

Traffic between VLAN 10 and VLAN 66 must pass through the Juniper SRX. This routed path allows the Cisco switch to copy the traffic to the Security Onion monitoring interface.

The VLAN 66 network path and its physical-cable troubleshooting are documented in `02_network_changes.md`.

---

# Existing Security Onion VM

Security Onion VM 900 existed before the DNS-server VM was created.

## Verified Settings

| Setting            | Value                            |
| ------------------ | -------------------------------- |
| VMID               | `900`                            |
| VM name            | `SecOnion`                       |
| Purpose            | Network monitoring and detection |
| CPU                | 8 cores                          |
| Memory             | 24,576 MB                        |
| Disk               | 250 GB on `ext-ssd`              |
| Management adapter | `net0` on `vmbr0`                |
| Monitoring adapter | `net1` on `vmbr1`                |
| Monitoring MTU     | 9000                             |
| Management IP      | `172.16.99.30`                   |

### Why Security Onion Has Two Adapters

Security Onion separates management traffic from monitored traffic:

* The management adapter provides access to the Security Onion console and services.
* The monitoring adapter receives copied traffic from the Cisco SPAN destination.
* The monitoring adapter does not need an IP address because it listens passively.

This prevents monitoring traffic from being mixed with ordinary management communication.

Security Onion will be validated again before controlled DNS test traffic is generated.

---

# Ubuntu Server ISO

## ISO Information

The Ubuntu Server installer was downloaded on the Windows management computer and transferred locally to Proxmox.

| Setting             | Value                                  |
| ------------------- | -------------------------------------- |
| Ubuntu version      | Ubuntu Server 24.04.4 LTS              |
| ISO type            | Live Server AMD64                      |
| Filename            | `ubuntu-24.04.4-live-server-amd64.iso` |
| Proxmox ISO storage | `local`                                |
| File size           | 3,405,469,696 bytes                    |

---

## Transfer the ISO from Windows

The following command was run in Windows PowerShell:

```powershell
scp `
"$env:USERPROFILE\Downloads\ubuntu-24.04.4-live-server-amd64.iso" `
root@172.16.99.20:/var/lib/vz/template/iso/
```

### Command Explanation

* `scp` means Secure Copy.
* Secure Copy transfers a file through an encrypted SSH connection.
* The backtick at the end of a PowerShell line continues the command onto the next line.
* `$env:USERPROFILE` represents the current Windows user's home directory.
* `\Downloads\ubuntu-24.04.4-live-server-amd64.iso` identifies the local ISO.
* `root@172.16.99.20` connects to the Proxmox server using the `root` account.
* `/var/lib/vz/template/iso/` is the standard ISO directory for Proxmox `local` storage.

The command asks for the Proxmox root password unless SSH-key authentication is configured.

The password is used for authentication but is not written into the Git repository.

---

## Confirm That Proxmox Can See the ISO

The following command was run on Proxmox:

```bash
pvesm list local --content iso
```

### Command Explanation

* `pvesm list` lists content in a Proxmox storage pool.
* `local` identifies the storage pool being checked.
* `--content iso` limits the output to ISO files.

### Verified Result

The output listed:

```text
ubuntu-24.04.4-live-server-amd64.iso
```

This confirmed that the ISO was stored in the correct Proxmox directory and was available to attach to a VM.

---

## Verify the ISO Checksum

The following command calculated the ISO's SHA-256 checksum:

```bash
sha256sum /var/lib/vz/template/iso/ubuntu-24.04.4-live-server-amd64.iso
```

### Command Explanation

* `sha256sum` calculates a SHA-256 cryptographic hash.
* The long file path identifies the uploaded Ubuntu ISO.
* A hash acts like a digital fingerprint for a file.
* If even a small part of the file changes, the resulting hash will normally be different.

### Calculated SHA-256 Value

```text
e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433
```

The calculated ISO hash matched the expected Ubuntu checksum used during the installation process.

This ISO checksum validation is separate from the later BIND9 package-transfer process. The BIND9 package files were not independently verified against a separate trusted checksum list, and that limitation is documented in `05_dns_server.md`.

---

# Creating DNS Server VM 901

## Purpose of VM 901

VM 901 is a dedicated authoritative BIND9 DNS server for the internal `exfil.test` lab zone.

It provides a controlled destination for normal DNS requests and the later safe DNS-exfiltration simulation.

The server is isolated from public DNS recursion and is used only inside the lab.

---

## VM Creation Command

The following command was run on the Proxmox host:

```bash
qm create 901 \
  --name DNS-SRV-01 \
  --description "Dedicated BIND9 DNS server for the DNS exfiltration lab" \
  --ostype l26 \
  --cpu host \
  --sockets 1 \
  --cores 2 \
  --memory 2048 \
  --balloon 0 \
  --scsihw virtio-scsi-single \
  --scsi0 ext-ssd:32,iothread=1,discard=on,ssd=1 \
  --ide2 local:iso/ubuntu-24.04.4-live-server-amd64.iso,media=cdrom \
  --net0 virtio,bridge=vmbr0,tag=66,firewall=0 \
  --boot "order=ide2;scsi0;net0" \
  --agent enabled=1 \
  --onboot 0
```

The backslash at the end of each Linux shell line continues the same command on the next line. This makes a long command easier to read.

---

## Explanation of Every Creation Option

| Command or option             | Explanation                                       		             |
| ----------------------------- | -------------------------------------------------------------------------- |
| `qm create 901`               | Creates a new Proxmox VM with VMID 901                                     |
| `--name DNS-SRV-01`           | Assigns the name shown in the Proxmox interface                            |
| `--description "..."`         | Adds a short explanation of the VM's purpose                               |
| `--ostype l26`                | Identifies the guest as a modern Linux operating system                    |
| `--cpu host`                  | Exposes the host processor's features to the VM                            |
| `--sockets 1`                 | Creates one virtual CPU socket                                             |
| `--cores 2`                   | Assigns two processor cores to that socket                                 |
| `--memory 2048`               | Assigns 2,048 MB, or 2 GB, of RAM                                          |
| `--balloon 0`                 | Disables dynamic memory ballooning                                         |
| `--scsihw virtio-scsi-single` | Uses the optimized VirtIO SCSI storage controller                          |
| `--scsi0`                     | Creates the VM's first SCSI virtual disk                                   |
| `ext-ssd:32`                  | Creates a 32 GB disk on the `ext-ssd` storage pool                         |
| `iothread=1`                  | Gives the virtual disk a dedicated I/O thread                              |
| `discard=on`                  | Allows unused blocks to be released when supported by the storage          |
| `ssd=1`                       | Presents the virtual disk to Ubuntu as SSD-backed storage                  |
| `--ide2`                      | Adds the ISO as a virtual CD/DVD drive                                     |
| `local:iso/...`               | Identifies the ISO stored in Proxmox `local` storage                       |
| `media=cdrom`                 | Tells Proxmox to treat the ISO as a virtual optical disc                   |
| `--net0`                      | Creates the VM's first virtual network adapter                             |
| `virtio`                      | Uses the high-performance VirtIO network-device type                       |
| `bridge=vmbr0`                | Connects the virtual adapter to the production VM bridge                   |
| `tag=66`                      | Places the VM's traffic into VLAN 66                                       |
| `firewall=0`                  | Disables the Proxmox firewall on this individual virtual adapter           |
| `--boot`                      | Defines the VM's initial device boot order                                 |
| `ide2;scsi0;net0`             | Initially tries the installer ISO, then the virtual disk, then the network |
| `--agent enabled=1`           | Enables Proxmox support for the QEMU Guest Agent                           |
| `--onboot 0`                  | Prevents the VM from starting automatically with Proxmox                   |

### CPU Allocation

One socket with two cores gives the VM two virtual CPUs:

```text
1 socket x 2 cores = 2 virtual CPUs
```

This is sufficient for a small internal BIND9 server.

### Memory Allocation

The VM receives a fixed 2 GB of memory.

Memory ballooning was disabled so that the DNS server has a predictable amount of RAM during testing.

### Proxmox Firewall Setting

`firewall=0` disables the Proxmox firewall on this virtual network adapter.

It does not mean the DNS server has no firewall protection.

The lab also uses:

* Ubuntu UFW rules.
* Juniper SRX security policies.
* VLAN separation.
* BIND9 access controls.

The Ubuntu firewall configuration is documented in `05_dns_server.md`.

---

# Initial VM Configuration Verification

## Display the VM Configuration

The following command was used:

```bash
qm config 901
```

### Command Explanation

* `qm` manages Proxmox virtual machines.
* `config` displays a VM's saved hardware and settings.
* `901` identifies the DNS-server VM.

### Verified Settings

The output confirmed that:

* VMID 901 existed.
* The VM name was `DNS-SRV-01`.
* Two CPU cores were assigned.
* Memory was set to 2,048 MB.
* The 32 GB disk was stored on `ext-ssd`.
* The Ubuntu Server ISO was attached.
* The network adapter used `vmbr0`.
* VLAN tag 66 was assigned.
* The network adapter used VirtIO.
* QEMU Guest Agent support was enabled.
* Automatic startup was disabled.

---

## Display the VM in the Proxmox List

The following command was also used:

```bash
qm list
```

### Command Explanation

* `qm list` displays all QEMU virtual machines.
* It confirms the VMID, VM name, current status, and memory allocation.

Immediately after creation, VM 901 appeared in the list with a stopped status. This was expected because `qm create` creates the VM but does not automatically start it.

---

# Starting the Ubuntu Installer

## Start VM 901

The following command started the VM:

```bash
qm start 901
```

### Command Explanation

* `qm start` powers on a Proxmox virtual machine.
* `901` is the VMID being started.

Because the Ubuntu ISO was first in the initial boot order, the VM started from the virtual installation disc.

---

## Check the VM Status

The following command checked whether the VM was running:

```bash
qm status 901
```

### Command Explanation

* `qm status` displays the current power state of a VM.
* `901` identifies the DNS-server VM.

### Expected Result

```text
status: running
```

If the result is `status: stopped`, the VM is not currently powered on.

---

## Open the Installer Console

The Ubuntu installer was accessed through the Proxmox web interface:

1. Sign in to Proxmox.
2. Select VM `901`.
3. Select **Console**.
4. Choose **Try or Install Ubuntu Server**.
5. Complete the Ubuntu Server installation.

The detailed Ubuntu operating-system and BIND9 configuration is documented in `05_dns_server.md`.

---

# Completed Ubuntu Installation

## Installed Server Settings

| Setting                | Final value               |
| ---------------------- | ------------------------- |
| Operating system       | Ubuntu Server 24.04.4 LTS |
| Hostname               | `dns-srv-01`              |
| Administrative account | `dnsadmin`                |
| IP address             | `192.168.66.53/24`        |
| Default gateway        | `192.168.66.1`            |
| VLAN                   | 66                        |
| DNS software           | BIND9                     |
| Local DNS zone         | `exfil.test`              |

The account password is not recorded in Git.

---

## Detach the Installation ISO

After Ubuntu was installed, the Ubuntu ISO was detached from VM 901.

### Why the ISO Was Detached

The ISO is needed only while installing Ubuntu.

Leaving it attached can cause the VM to reopen the installer if the boot order changes or if the virtual disk temporarily fails to boot.

The ISO was removed from the virtual CD/DVD drive using the Proxmox interface:

1. Select VM `901`.
2. Open **Hardware**.
3. Select the CD/DVD drive.
4. Select **Edit**.
5. Choose **Do not use any media**.
6. Save the change.

Detaching an ISO does not delete it from Proxmox storage. The ISO remains available for future installations.

---

## Final Boot Order

After installation, the VM was configured to boot from its virtual disk.

The final primary boot device is:

```text
scsi0
```

### What `scsi0` Means

* `scsi0` is the 32 GB virtual disk on `ext-ssd`.
* Ubuntu was installed on this disk.
* The VM no longer needs to start from the installer ISO.

The final state was verified with:

```bash
qm config 901
```

The configuration confirmed that the VM boots from its installed virtual disk and that the Ubuntu installation ISO is no longer mounted.

---

# Final DNS Server VM Settings

| Setting                   | Final value                 |
| ------------------------- | --------------------------- |
| VMID                      | `901`                       |
| Proxmox name              | `DNS-SRV-01`                |
| Ubuntu hostname           | `dns-srv-01`                |
| Purpose                   | Dedicated BIND9 DNS server  |
| Operating system          | Ubuntu Server 24.04.4 LTS   |
| CPU type                  | Host                        |
| CPU sockets               | 1                           |
| CPU cores                 | 2                           |
| Total virtual CPUs        | 2                           |
| Memory                    | 2,048 MB                    |
| Memory ballooning         | Disabled                    |
| Disk                      | 32 GB                       |
| Disk storage              | `ext-ssd`                   |
| Disk controller           | VirtIO SCSI Single          |
| Primary boot disk         | `scsi0`                     |
| Installation ISO          | Detached after installation |
| Network adapter           | VirtIO                      |
| Proxmox bridge            | `vmbr0`                     |
| VLAN tag                  | 66                          |
| Proxmox adapter firewall  | Disabled                    |
| MAC address               | `BC:24:11:EA:70:0A`         |
| IP address                | `192.168.66.53/24`          |
| Gateway                   | `192.168.66.1`              |
| QEMU Guest Agent support  | Enabled in Proxmox          |
| Start automatically       | No                          |
| Current operational state | Installed and working       |

---

# Network Validation

## VLAN 66 Connectivity

After the physical network path was corrected, the DNS server successfully reached its VLAN 66 gateway:

```bash
ping -c 4 192.168.66.1
```

### Command Explanation

* `ping` tests basic IP connectivity.
* `-c 4` sends four packets and stops.
* `192.168.66.1` is the VLAN 66 gateway.

A successful reply confirmed that:

* The VM network adapter was active.
* The adapter used the correct VLAN tag.
* Proxmox `vmbr0` permitted VLAN 66.
* The Cisco and downstream physical path worked.
* The Juniper gateway was reachable.

The interface mismatch issue and its resolution are documented in `02_network_changes.md`.

---

## SSH Validation

The server was reached from the management network using:

```powershell
ssh dnsadmin@192.168.66.53
```

### Command Explanation

* `ssh` opens an encrypted remote terminal.
* `dnsadmin` is the Ubuntu administrative account.
* `192.168.66.53` is the DNS server's address.

A new SSH session connected successfully after the Ubuntu firewall was enabled.

---

## DNS Validation

The following command was run from the Windows management workstation:

```powershell
Resolve-DnsName -Name normal.exfil.test -Server 192.168.66.53 -Type A
```

### Command Explanation

* `Resolve-DnsName` performs a DNS lookup.
* `-Name normal.exfil.test` identifies the internal test hostname.
* `-Server 192.168.66.53` sends the request directly to VM 901.
* `-Type A` requests an IPv4 address.

### Verified Result

The DNS server returned:

```text
normal.exfil.test    A    300    192.168.66.53
```

This proved that the VM's operating system, network connection, Ubuntu firewall, and BIND9 service were all functioning.

---

# Important Storage Rule

Do not place the DNS, Splunk, or Windows VM disks on the Proxmox `local` storage pool.

Use:

```text
ext-ssd
```

The `local` storage pool should primarily hold installation ISO files.

This prevents the Proxmox operating-system disk from filling up, which could cause:

* Failed uploads.
* Failed package operations.
* VM-management problems.
* Logging failures.
* Proxmox web-interface problems.
* General host instability.

---

# Troubleshooting Commands

## VM Does Not Appear

Run:

```bash
qm list
```

If VMID 901 is not listed, confirm that the creation command completed successfully.

---

## VM Does Not Start

Run:

```bash
qm start 901
```

Then check:

```bash
qm status 901
```

If it remains stopped, review the Proxmox task log for an error involving storage, memory, or configuration.

---

## VM Starts the Installer Again

Run:

```bash
qm config 901
```

Check whether the ISO is still attached and whether `ide2` appears before `scsi0` in the boot order.

Detach the ISO and make `scsi0` the first boot device.

---

## VM Has No Network Connectivity

Run:

```bash
qm config 901
```

Confirm that the network setting includes:

```text
bridge=vmbr0
tag=66
```

Then verify the Proxmox bridge:

```bash
bridge -c vlan show
```

Confirm that VLAN 66 is permitted.

The complete end-to-end network troubleshooting process is recorded in `02_network_changes.md`.

---

## VM Disk Is on the Wrong Storage

Run:

```bash
qm config 901
```

Find the `scsi0` line.

The correct disk location begins with:

```text
ext-ssd:
```

Do not create a replacement disk until the existing VM data has been backed up and a safe migration plan has been prepared.

---

# Security and Documentation Notes

* No passwords are stored in this document.
* No private SSH keys are stored in the repository.
* VM 901 is used only inside the air-gapped lab.
* The DNS server does not provide recursive public DNS service.
* Proxmox adapter firewalling is disabled for this VM, but Ubuntu UFW and Juniper policies still restrict traffic.
* All VM-specific configuration is stored under `01_dns_exfiltration_lab/`.
* `BASELINE_CONFIGURATION/` remains unchanged.
* The original BIND9 configuration backup contains `rndc.key` and must not be committed to Git.
* Only sanitized configuration copies and small evidence files should be stored in the repository.

---

# Final Result

VM 901, named `DNS-SRV-01`, was successfully created and installed.

The VM uses:

* Two virtual CPU cores.
* 2 GB of fixed memory.
* A 32 GB disk on `ext-ssd`.
* A VirtIO network adapter on `vmbr0`.
* VLAN tag 66.
* Ubuntu Server 24.04.4 LTS.
* Static IP address `192.168.66.53/24`.
* BIND9 for the internal `exfil.test` zone.

The Ubuntu installer ISO has been detached, the VM boots from its virtual disk, VLAN 66 connectivity works, SSH access works, and the BIND9 server answers remote lab DNS requests.
