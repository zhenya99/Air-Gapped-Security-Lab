# 03 — Proxmox Virtual Machines

## What Is This Document?

This document explains how the virtual machines for the DNS Exfiltration Detection Lab are created in Proxmox.

A virtual machine, or VM, is a computer that runs inside the Proxmox server.

---

## Simple Proxmox Terms

| Term           | Explanation			            |
| -------------- | ---------------------------------------- |
| VMID           | The unique number Proxmox gives each VM  |
| ISO            | A virtual installation DVD               |
| Virtual disk   | Storage used by the VM                   |
| Network bridge | A virtual network switch                 |
| VLAN tag       | Places the VM in a specific network      |
| VirtIO         | A fast virtual network or storage device |

---

## Proxmox Resource Check

Before creating any VMs, the Proxmox resources were checked with:

```bash
qm list

pvesm status

free -h
```

### Results

| Resource                               | Available capacity             |
| -------------------------------------- | ------------------------------ |
| Total host memory                      | 46 GB                          |
| Available memory during the check      | 44 GB                          |
| `ext-ssd` storage                      | Approximately 872 GB available |
| `local-lvm` storage                    | Approximately 141 GB available |
| Proxmox local storage after ISO upload | Approximately 6.7 GB available |

All new VM disks will use `ext-ssd`.

The `local` storage is reserved mainly for ISO installation files because the Proxmox system disk is already 90% full.

---

## Lab VM Plan

| VMID | Name              | Purpose                   |     CPU | Memory |   Disk | Status   |
| ---: | ----------------- | ------------------------- | ------: | -----: | -----: | -------- |
|  900 | `SecOnion`        | Security Onion monitoring | 8 cores |  24 GB | 250 GB | Existing |
|  901 | `DNS-SRV-01`      | Ubuntu BIND9 DNS server   | 2 cores |   2 GB |  32 GB | Created  |
|  902 | `SPLUNK-SRV-01`   | Splunk detection platform | 4 cores |   8 GB | 100 GB | Planned  |
|  903 | `WIN11-VICTIM-01` | Windows victim computer   | 4 cores |   6 GB | 100 GB | Planned  |

The planned VMs use approximately 40 GB of memory when all are running. This leaves approximately 6 GB for the Proxmox host.

These resources are intended for a small learning lab, not a production environment.

---

## VM Network Plan

| Virtual machine           | Proxmox bridge |               VLAN | Planned IP address |
| ------------------------- | -------------- | -----------------: | ------------------ |
| Security Onion management | `vmbr0`        |     Native VLAN 99 | `172.16.99.30`     |
| Security Onion monitoring | `vmbr1`        | Passive monitoring | No IP address      |
| Ubuntu DNS server         | `vmbr0`        |                 66 | `192.168.66.53`    |
| Splunk server             | `vmbr0`        |     Native VLAN 99 | `172.16.99.40`     |
| Windows 11 victim         | `vmbr0`        |                 10 | `172.16.10.50`     |

The DNS server and Windows victim use different VLANs. Their traffic must therefore pass through the Juniper SRX, allowing the Cisco switch to copy it to Security Onion.

---

## Existing Security Onion VM

Security Onion already existed before starting this lab.

### Verified Settings

| Setting                     | Value               |
| --------------------------- | ------------------- |
| VMID                        | `900`               |
| Name                        | `SecOnion`          |
| CPU                         | 8 cores             |
| Memory                      | 24,576 MB           |
| Disk                        | 250 GB on `ext-ssd` |
| Management adapter          | `net0` on `vmbr0`   |
| Monitoring adapter          | `net1` on `vmbr1`   |
| Monitoring MTU              | 9000                |
| Status during initial check | Stopped             |

Security Onion will be started and tested before DNS traffic is generated.

---

## Ubuntu Server ISO

The Ubuntu Server ISO was downloaded on a Windows computer and transferred locally to Proxmox.

### ISO Information

| Setting         | Value                                  |
| --------------- | -------------------------------------- |
| Version         | Ubuntu Server 24.04.4 LTS              |
| Type            | Live Server AMD64                      |
| Filename        | `ubuntu-24.04.4-live-server-amd64.iso` |
| Proxmox storage | `local`                                |
| File size       | 3,405,469,696 bytes                    |

### Windows Transfer Command

The ISO was transferred from Windows PowerShell with:

```powershell
scp `
"$env:USERPROFILE\Downloads\ubuntu-24.04.4-live-server-amd64.iso" `
root@172.16.99.20:/var/lib/vz/template/iso/
```

### Proxmox Verification

The uploaded ISO was listed with:

```bash
pvesm list local --content iso
```

The file integrity was checked with:

```bash
sha256sum \
/var/lib/vz/template/iso/ubuntu-24.04.4-live-server-amd64.iso
```

Verified SHA256:

```text
e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433
```

The calculated hash matched Ubuntu’s official checksum.

---

## Creating DNS Server VM 901

VM 901 was created for the dedicated BIND9 DNS server.

### Creation Command

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

---

## DNS Server VM Settings

| Setting             | Value                      |
| ------------------- | -------------------------- |
| VMID                | `901`                      |
| Name                | `DNS-SRV-01`               |
| Purpose             | Dedicated BIND9 DNS server |
| CPU type            | Host                       |
| CPU cores           | 2                          |
| Memory              | 2,048 MB                   |
| Memory ballooning   | Disabled                   |
| Disk                | 32 GB                      |
| Disk storage        | `ext-ssd`                  |
| Disk controller     | VirtIO SCSI Single         |
| ISO                 | Ubuntu Server 24.04.4      |
| Network adapter     | VirtIO                     |
| Proxmox bridge      | `vmbr0`                    |
| VLAN tag            | 66                         |
| Proxmox firewall    | Disabled                   |
| MAC address         | `BC:24:11:EA:70:0A`        |
| Start automatically | No                         |

---

## VM Creation Verification

The new VM was checked with:

```bash
qm config 901

qm list
```

The results confirmed:

* VM 901 exists.
* The VM name is `DNS-SRV-01`.
* The VM is currently stopped.
* The 32 GB disk is stored on `ext-ssd`.
* The Ubuntu Server ISO is attached.
* The network adapter uses `vmbr0`.
* VLAN 66 is assigned.
* The boot order starts with the Ubuntu ISO.

---

## Starting the Ubuntu Installer

Start VM 901 with:

```bash
qm start 901
```

Verify that it is running:

```bash
qm status 901
```

In the Proxmox web interface:

1. Select VM `901`.
2. Select **Console**.
3. Choose **Try or Install Ubuntu Server**.
4. Follow the Ubuntu Server installation steps recorded in `05_dns_server.md`.

---

## Important Storage Rule

Do not place the DNS, Splunk, or Windows VM disks on `local`.

Use:

```text
ext-ssd
```

This prevents the Proxmox operating-system disk from becoming full.
