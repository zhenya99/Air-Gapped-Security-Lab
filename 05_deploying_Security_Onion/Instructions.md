# Deploying Security Onion v3.2.0

Deploying Security Onion 3.2.x requires precise interface alignment to ensure that mirrored VLAN 10 traffic successfully reaches the Suricata and Zeek sensors.


## 1. VM Provisioning in Proxmox

Download the Security Onion ISO image by following the official [Security Onion ISO Download and Verification Guide](https://github.com/Security-Onion-Solutions/securityonion/blob/3/main/DOWNLOAD_AND_VERIFY_ISO.md).

Open PowerShell on your Windows 11 machine.
Run the following command, replacing the Windows path with the exact location of the ISO file on your machine:

```bash

scp "C:\\Users\\YourUser\\Downloads\\securityonion-3.2.0.iso" root@172.16.99.20:/var/lib/vz/template/iso

```
Before booting the ISO, configure the virtual hardware to match the network segmentation and storage layout. You can verify your host's capacity from the Proxmox shell:

```bash
ssh root@lab
lscpu
pvesh get /nodes/localhost/status
free -h
df -h
lsblk
```
I am running an i7-12700K, which features 12 physical cores (8 Performance, 4 Efficient) and hyper-threading, meaning Proxmox actually has 20 logical threads to work with. The host also features 46GB of memory, a 240GB internal SSD, and a 1TB external SSD.


**Step 1: Verify the ISO and Storage Pool**
Check the exact ISO name in local storage

```bash
pvesm list local --content iso
pvesm status
lsblk

```
![Disk](/images/Proxmox/disk_usage.png)

