# 07. Splunk Server

## Purpose

Splunk Enterprise collects, stores, and searches security events from the Windows 11 victim.

The Windows victim already has Sysmon installed and validated for:

| Event ID | Event type |
|---:|---|
| `1` | Process creation |
| `3` | Network connection |
| `22` | DNS query |

The next phase will install the Splunk Universal Forwarder on Windows and send these events to this server.

---

## Current Status

**Stage:** Splunk Enterprise server installed and operational

Splunk Enterprise `10.4.3` is installed on Ubuntu Server `24.04.4 LTS` in Proxmox VM `902`.

The Splunk service is managed by `systemd`, runs under the dedicated Linux account `splunk`, and starts automatically with Ubuntu. Splunk Web is reachable from the Windows analyst workstation at:

```text
http://172.16.99.40:8000
```

TCP port `9997`, the Windows Universal Forwarder, and Sysmon ingestion are still pending.

---

## Verified Splunk VM

| Setting | Verified value |
|---|---|
| Proxmox VMID | `902` |
| Proxmox VM name | `SPLUNK-SRV-01` |
| Ubuntu hostname | `splunk-srv-01` |
| Operating system | Ubuntu Server `24.04.4 LTS`, AMD64 |
| CPU | 1 socket, 4 virtual CPU cores, host CPU type |
| Memory | 12 GB (`12288` MiB), ballooning disabled |
| Disk | 150 GB on `ext-ssd` |
| Disk controller | VirtIO SCSI single |
| Proxmox bridge | `vmbr0` |
| VLAN | `99` |
| Network adapter | VirtIO, MAC `BC:24:11:6A:31:E8` |
| Ubuntu interface | `enp6s18` |
| IP address | `172.16.99.40/24` |
| Default gateway | `172.16.99.1` |
| DNS server | `192.168.66.53` |
| Splunk Enterprise | `10.4.3` |
| Splunk installation path | `/opt/splunk` |
| Splunk Web | TCP `8000` |
| Splunk management port | TCP `8089` |
| Forwarder receiving port | TCP `9997` — pending |

This is a small proof-of-concept deployment and is not intended to represent production Splunk sizing.

---

## Account Separation

Three separate accounts are used. Even when two accounts have the same name, they belong to different authentication systems.

| Account | Purpose |
|---|---|
| Ubuntu `splunkadmin` | Interactive SSH login and Ubuntu administration |
| Linux `splunk` | Non-root service account that runs Splunk |
| Splunk Web `splunkadmin` | Administrator account inside Splunk Enterprise |

Passwords are intentionally excluded from this repository.

---

## How the Data Will Travel

1. The Windows 11 victim generates process, network, and DNS activity.
2. Sysmon records the activity in the Windows event log.
3. Splunk Universal Forwarder reads the selected Sysmon events.
4. The forwarder sends the events to Splunk over TCP port `9997`.
5. Splunk stores the events and makes them searchable in Splunk Web.

```text
Windows 11 Victim (172.16.10.50)
        |
        | Sysmon Event IDs 1, 3, and 22
        v
Splunk Universal Forwarder
        |
        | TCP 9997
        v
Splunk Enterprise (172.16.99.40)
        |
        | Splunk Web TCP 8000
        v
Windows Analyst (172.16.99.10)
```

---

## 1. Verify the Proxmox VM

From the Proxmox shell, verify VM `902`:

```bash
qm config 902
```

The verified configuration included:

```text
name: SPLUNK-SRV-01
cores: 4
cpu: host
memory: 12288
balloon: 0
machine: q35
scsi0: ext-ssd:vm-902-disk-0,size=150G
net0: virtio=BC:24:11:6A:31:E8,bridge=vmbr0,firewall=0,tag=99
onboot: 1
```

Proxmox provides VLAN 99 to the virtual adapter. Ubuntu therefore uses a normal untagged interface and does not create a VLAN subinterface inside the guest.

---

## 2. Upload and Attach the Ubuntu ISO

The required ISO was not initially present on Proxmox. Ubuntu Server `24.04.4` was downloaded to the Windows analyst workstation and copied into Proxmox ISO storage:

```powershell
scp "$env:USERPROFILE\Downloads\ubuntu-24.04.4-live-server-amd64.iso" root@172.16.99.20:/var/lib/vz/template/iso/
```

Verify the uploaded ISO from Proxmox:

```bash
pvesm list local --content iso
```

Attach it to VM `902`:

```bash
qm set 902 --ide2 local:iso/ubuntu-24.04.4-live-server-amd64.iso,media=cdrom
```

Boot from the ISO first and the virtual disk second:

```bash
qm set 902 --boot order='ide2;scsi0'
```

Start the VM:

```bash
qm start 902
```

---

## 3. Install Ubuntu Server

During the Ubuntu installer, the network interface was shown as `enp6s18`. DHCP autoconfiguration failed because this management network uses static addressing.

The final manual IPv4 values are:

| Installer field | Value |
|---|---|
| Subnet | `172.16.99.0/24` |
| Address | `172.16.99.40` |
| Gateway | `172.16.99.1` |
| Name servers | `192.168.66.53` |
| Search domains | Blank |

The server profile uses:

| Field | Value |
|---|---|
| Server name | `splunk-srv-01` |
| Ubuntu administrator | `splunkadmin` |

The password is private and must not be placed in the repository.

After Ubuntu installation, make the virtual disk the only boot device:

```bash
qm set 902 --boot order=scsi0
```

Eject the installer ISO:

```bash
qm set 902 --ide2 none,media=cdrom
```

Verify:

```bash
qm config 902
```

---

## 4. Correct the IP-Address Conflict

The address `172.16.99.30` was initially considered for Splunk, but SSH displayed an existing unauthorized-access banner and the new Ubuntu VM recorded no matching SSH log entries.

Windows showed that `.30` resolved to:

```text
BC-24-11-65-9F-86
```

VM `902` should have resolved to:

```text
BC-24-11-6A-31-E8
```

The existing MAC address was identified from Proxmox:

```bash
grep -Rni "BC:24:11:65:9F:86" /etc/pve/qemu-server/
```

Result:

```text
/etc/pve/qemu-server/900.conf
```

This proved that `172.16.99.30` already belonged to Security Onion VM `900`. Splunk was reassigned to `172.16.99.40`.

The final Netplan file is `/etc/netplan/50-cloud-init.yaml`:

```yaml
network:
  version: 2
  ethernets:
    enp6s18:
      addresses:
        - 172.16.99.40/24
      nameservers:
        addresses:
          - 192.168.66.53
        search: []
      routes:
        - to: default
          via: 172.16.99.1
```

Secure and apply the configuration:

```bash
sudo chmod 600 /etc/netplan/50-cloud-init.yaml
sudo netplan generate
sudo netplan apply
```

Verify the address and route:

```bash
ip -4 -br address show enp6s18
ip route
```

Expected values:

```text
enp6s18    UP    172.16.99.40/24
default via 172.16.99.1 dev enp6s18
```

---

## 5. Verify Ubuntu and SSH

Connect from Windows PowerShell:

```powershell
ssh splunkadmin@172.16.99.40
```

Verify the server:

```bash
hostnamectl --static
ip -4 -br address show enp6s18
ip route
ping -c 3 172.16.99.1
ping -c 3 192.168.66.53
timedatectl
free -h
df -h /
```

Set UTC so timestamps remain consistent across Ubuntu, Splunk, Sysmon, and the DNS server:

```bash
sudo timedatectl set-timezone UTC
```

---

## 6. Download and Transfer Splunk Enterprise

Splunk Enterprise `10.4.3` for AMD64 Linux was downloaded on Windows as a Debian package.

From Windows PowerShell:

```powershell
cd $env:USERPROFILE\Downloads

curl.exe -L "https://download.splunk.com/products/splunk/releases/10.4.3/linux/splunk-10.4.3-4174a2deda5d-linux-amd64.deb" -o "splunk-10.4.3-4174a2deda5d-linux-amd64.deb"
```

Confirm the file:

```powershell
Get-Item ".\splunk-10.4.3-4174a2deda5d-linux-amd64.deb" |
Select-Object Name,Length
```

Transfer it to VM `902`:

```powershell
scp ".\splunk-10.4.3-4174a2deda5d-linux-amd64.deb" splunkadmin@172.16.99.40:/home/splunkadmin/
```

Verify it from Ubuntu:

```bash
ls -lh ~/splunk-*.deb
```

---

## 7. Install and Start Splunk

Install the local Debian package:

```bash
sudo dpkg -i ~/splunk-10.4.3-4174a2deda5d-linux-amd64.deb
```

Verify the package:

```bash
dpkg --status splunk | grep -E '^(Package|Status|Version):'
```

The installer created the dedicated service account:

```bash
getent passwd splunk
```

Verified result:

```text
splunk:x:1001:1001:Splunk Server:/opt/splunk:/bin/bash
```

Start Splunk for the first time as the service account and accept the license:

```bash
sudo -H -u splunk /opt/splunk/bin/splunk start --accept-license
```

Create the Splunk Web administrator when prompted. The verified Splunk Web username is `splunkadmin`; its password is private.

Verify the process and listening ports:

```bash
sudo -H -u splunk /opt/splunk/bin/splunk status
sudo ss -lntp | grep -E ':(8000|8089)\b'
```

Open Splunk Web using the IP address:

```text
http://172.16.99.40:8000
```

`http://splunk-srv-01:8000` will not work until a DNS record or Windows hosts-file entry is added for that hostname.

---

## 8. Configure Automatic Startup

Splunk must run as the non-root Linux account `splunk`.

Stop the manually started process:

```bash
sudo -H -u splunk /opt/splunk/bin/splunk stop
```

Create the `systemd` service:

```bash
sudo /opt/splunk/bin/splunk enable boot-start -user splunk -systemd-managed 1
```

Reload `systemd`, enable the service, and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now Splunkd.service
```

Verify the configured operating-system account:

```bash
sudo grep -E '^(User|Group)=' /etc/systemd/system/Splunkd.service
```

Expected:

```text
User=splunk
Group=splunk
```

Verify the final service state:

```bash
sudo systemctl is-enabled Splunkd.service
sudo systemctl is-active Splunkd.service
sudo systemctl status Splunkd.service --no-pager
```

Verified final state:

```text
enabled
active
```

---

## Troubleshooting: Incorrect Boot-Start User

The boot-start command was initially entered with `-user splunkadmin`. This caused permission warnings because `splunkadmin` does not own `/opt/splunk`:

```text
Warning: cannot create "/opt/splunk/var/log/splunk"
Warning: cannot create "/opt/splunk/var/log/introspection"
Warning: cannot create "/opt/splunk/var/log/watchdog"
Warning: cannot create "/opt/splunk/var/log/client_events"
```

The incorrect unit was removed and regenerated with the correct service account:

```bash
sudo systemctl stop Splunkd.service
sudo /opt/splunk/bin/splunk disable boot-start
sudo chown -R splunk:splunk /opt/splunk
sudo /opt/splunk/bin/splunk enable boot-start -user splunk -systemd-managed 1
sudo systemctl daemon-reload
sudo systemctl enable --now Splunkd.service
```

The important distinction is:

- `splunkadmin` administers Ubuntu and signs in to Splunk Web.
- `splunk` owns the Splunk files and runs `Splunkd.service`.

---

## Installation Checklist

- [x] Create Proxmox VM `902`.
- [x] Upload and attach the Ubuntu Server ISO.
- [x] Install Ubuntu Server 24.04.4 LTS.
- [x] Set hostname `splunk-srv-01`.
- [x] Identify the conflict with Security Onion at `172.16.99.30`.
- [x] Assign the final Splunk address `172.16.99.40/24`.
- [x] Verify the gateway and DNS-server path.
- [x] Verify SSH access from the Windows analyst workstation.
- [x] Set the Ubuntu time zone to UTC.
- [x] Download and transfer Splunk Enterprise `10.4.3`.
- [x] Install Splunk under `/opt/splunk`.
- [x] Start Splunk with the dedicated `splunk` account.
- [x] Verify access to Splunk Web on TCP `8000`.
- [x] Configure and verify `Splunkd.service`.
- [ ] Install and verify the QEMU Guest Agent inside Ubuntu.
- [ ] Add a DNS record for `splunk-srv-01` if hostname-based access is required.
- [ ] Create the Sysmon index.
- [ ] Enable the Splunk receiver on TCP `9997`.
- [ ] Install Splunk Universal Forwarder on Windows 11.
- [ ] Configure collection of the Sysmon Operational event log.
- [ ] Verify that Sysmon Event IDs `1`, `3`, and `22` reach Splunk.
- [ ] Save final screenshots and command output in the `evidence/` folder.

---

## Reference Documentation

- [Splunk Enterprise download](https://www.splunk.com/en_us/download/splunk-enterprise.html)
- [Install Splunk Enterprise on Linux](https://help.splunk.com/en/splunk-enterprise/administer/install-and-upgrade/9.1/install-splunk-enterprise-on-linux-or-macos/install-on-linux)
- [Run Splunk Enterprise as a systemd service](https://help.splunk.com/en/data-management/splunk-enterprise-admin-manual/9.3/start-splunk-enterprise-and-perform-initial-tasks/run-splunk-enterprise-as-a-systemd-service)

---

## Documentation Log

| Date | Update |
|---|---|
| 2026-09-03 | Created the initial beginner-friendly Splunk server plan. |
| 2026-09-04 | Created Proxmox VM `902` with 4 cores, 12 GB RAM, and a 150 GB disk. |
| 2026-09-04 | Installed Ubuntu Server and corrected the IP conflict with Security Onion by changing Splunk from `172.16.99.30` to `172.16.99.40`. |
| 2026-09-04 | Installed Splunk Enterprise `10.4.3`, verified Splunk Web on TCP `8000`, corrected the boot-start service account, and confirmed `Splunkd.service` is active and enabled. |
