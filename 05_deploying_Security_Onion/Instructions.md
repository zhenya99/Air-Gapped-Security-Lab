\# Deploying Security Onion v3.2.0



Deploying Security Onion 3.2.x requires precise interface alignment to ensure that mirrored VLAN 10 traffic successfully reaches the Suricata and Zeek sensors.



\## 1. VM Provisioning in Proxmox



Download the Security Onion ISO image by following the official \[Security Onion ISO Download and Verification Guide](https://github.com/Security-Onion-Solutions/securityonion/blob/3/main/DOWNLOAD\_AND\_VERIFY\_ISO.md).



Open PowerShell on your Windows 11 machine.

Run the following command, replacing the Windows path with the exact location of the ISO file on your machine:



```bash

scp "C:\\\\Users\\\\YourUser\\\\Downloads\\\\securityonion-3.2.0.iso" root@172.16.99.20:/var/lib/vz/template/iso

```



Step 1: Verify the ISO and Storage Pool

Check the exact ISO name in local storage



```bash
pvesm list local --content iso
pvesm status

```

!\[Disk](https://github.com/zhenya99/Air-Gapped-Security-Lab/blob/main/images/Proxmox/disk\_usage.jpg?raw=true)







