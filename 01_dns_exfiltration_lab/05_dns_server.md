# 05. Ubuntu BIND9 DNS Server

## Purpose

This dedicated Ubuntu server provides authoritative DNS for the private `exfil.test` lab zone.

It has four jobs:

1. Answer DNS requests for lab-only names.
2. Accept requests only from approved lab networks.
3. Record DNS queries for later analysis.
4. Prevent public recursive DNS lookups and unauthorized zone transfers.

The server uses only fake test records. It is not intended to provide general Internet DNS resolution.

---

## Final Server Settings

| Setting               | Value                      |
| --------------------- | -------------------------- |
| Proxmox VMID          | `901`                      |
| VM name               | `DNS-SRV-01`               |
| Hostname              | `dns-srv-01`               |
| Operating system      | Ubuntu Server 24.04.4 LTS  |
| Administrator account | `dnsadmin`                 |
| Virtual CPUs          | 2                          |
| Memory                | 2 GB                       |
| Disk                  | 32 GB                      |
| Proxmox storage       | `ext-ssd`                  |
| Network bridge        | `vmbr0`                    |
| Proxmox VLAN tag      | `66`                       |
| MAC address           | `BC:24:11:EA:70:0A`        |
| IP address            | `192.168.66.53/24`         |
| Default gateway       | `192.168.66.1`             |
| DNS software          | BIND9                      |
| Lab DNS zone          | `exfil.test`               |
| Query log             | `/var/log/named/query.log` |

---

## Related Repository Files

### BIND Configuration

* [`configs/bind9/named.conf`](configs/bind9/named.conf)
* [`configs/bind9/named.conf.options`](configs/bind9/named.conf.options)
* [`configs/bind9/named.conf.local`](configs/bind9/named.conf.local)
* [`configs/bind9/named.conf.logging`](configs/bind9/named.conf.logging)
* [`configs/bind9/db.exfil.test`](configs/bind9/db.exfil.test)

### Ubuntu Configuration and Software Inventory

* [`configs/ubuntu/ufw-status.txt`](configs/ubuntu/ufw-status.txt)
* [`configs/ubuntu/bind9-package-versions.txt`](configs/ubuntu/bind9-package-versions.txt)

### Evidence

* [`evidence/dns-server/query-log-sample.txt`](evidence/dns-server/query-log-sample.txt)

Sensitive files such as `/etc/bind/rndc.key` are intentionally excluded from Git.

---

## 1. Create the Proxmox Virtual Machine

The DNS server was created as Proxmox VM `901`.

The final virtual hardware configuration includes:

* Two virtual CPU cores
* 2 GB of memory
* A 32 GB SCSI disk on `ext-ssd`
* A VirtIO network adapter connected to `vmbr0`
* VLAN tag `66`
* MAC address `BC:24:11:EA:70:0A`

After Ubuntu was installed, the ISO was detached and the boot order was changed to the virtual disk.

The Proxmox configuration was checked with:

```bash
qm config 901 | grep -E '^(boot|ide2|scsi0|bios|vga|serial)'
```

The important result was:

```text
boot: order=scsi0
ide2: none,media=cdrom
scsi0: ext-ssd:vm-901-disk-0,discard=on,iothread=1,size=32G,ssd=1
```

### What This Means

* `boot: order=scsi0` tells the VM to boot from its installed operating-system disk.
* `ide2: none,media=cdrom` confirms that no installation ISO remains attached.
* `size=32G` confirms the disk size.
* `ssd=1` tells the guest operating system to treat the virtual disk as SSD-backed storage.
* `discard=on` permits unused blocks to be returned to compatible storage.
* `iothread=1` gives the virtual disk a dedicated I/O thread.

More Proxmox details are recorded in [`03_proxmox_vms.md`](03_proxmox_vms.md).

---

## 2. Install Ubuntu Server

Ubuntu Server 24.04.4 LTS was installed with:

```text
Hostname: dns-srv-01
User:     dnsadmin
```

OpenSSH Server was also installed so the system could be managed from the analyst host.

The final static network configuration is:

```text
IP address:      192.168.66.53/24
Default gateway: 192.168.66.1
Interface:       ens18
VLAN:            66
```

The address and route were checked with:

```bash
ip -br address
```

```bash
ip route
```

The expected route is:

```text
default via 192.168.66.1 dev ens18
192.168.66.0/24 dev ens18 proto kernel scope link src 192.168.66.53
```

### Why Static Addressing Is Used

A DNS server should keep the same address. If its address changed, Windows, Kali, firewall rules, and detection documentation could point to the wrong system.

---

## 3. Troubleshoot the Initial VLAN 66 Connection

The Ubuntu server initially had the correct address and route but could not reach its gateway:

```bash
ping -c 4 192.168.66.1
```

The result was:

```text
Destination Host Unreachable
```

The Juniper SRX also could not reach `192.168.66.53` and did not learn an ARP entry for the server.

The Cisco switch showed the VM MAC address on the Proxmox trunk:

```text
VLAN 66
MAC bc24.11ea.700a
Port Gi1/0/27
```

This proved that:

* The VM network adapter was working.
* Proxmox was tagging the VM traffic with VLAN 66.
* The Cisco trunk was receiving the traffic.

However, Cisco interface `Gi1/0/2`, which connects VLAN 66 toward the Netgear and Juniper path, showed:

```text
notconnect
```

The physical cable was not connected.

After the cable was connected:

* The DNS server reached `192.168.66.1`.
* The Juniper learned the server.
* SSH from the analyst host worked.
* Remote DNS testing later succeeded.

This troubleshooting event is also recorded in [`02_network_changes.md`](02_network_changes.md).

---

## 4. Enable and Test SSH

SSH was installed but was initially inactive.

It was enabled and started with:

```bash
sudo systemctl enable --now ssh
```

### Command Explanation

* `sudo` runs the command with administrative permission.
* `systemctl` manages Ubuntu services.
* `enable` configures SSH to start during boot.
* `--now` starts it immediately.
* `ssh` is the service being managed.

SSH was checked with:

```bash
systemctl is-active ssh
```

Expected result:

```text
active
```

It was also checked with:

```bash
systemctl is-enabled ssh
```

Expected result:

```text
enabled
```

Port 22 was verified with:

```bash
sudo ss -lntp | grep ':22'
```

The analyst host connected with:

```powershell
ssh dnsadmin@192.168.66.53
```

---

## 5. Review the BIND9 Packages

Before installation, the planned packages were reviewed with:

```bash
sudo apt-get --simulate install bind9 bind9-utils dnsutils
```

A simulation shows what APT intends to install without changing the system.

The required package group was:

| Package          | Beginner-Friendly Purpose                         |
| ---------------- | ------------------------------------------------- |
| `bind9`          | Runs the actual DNS server service                |
| `bind9-libs`     | Provides shared libraries used by BIND programs   |
| `bind9-utils`    | Provides BIND administration and validation tools |
| `bind9-host`     | Provides the `host` DNS lookup utility            |
| `bind9-dnsutils` | Provides tools such as `dig` and `nslookup`       |
| `dnsutils`       | Ubuntu compatibility package for common DNS tools |
| `dns-root-data`  | Provides DNS root hints and DNSSEC reference data |

---

## 6. Stage the Packages for Installation

The DNS server was intended to remain isolated, so the packages were staged through the Windows analyst host.

Windows Subsystem for Linux was considered, but WSL was not installed. Windows PowerShell was therefore used to download and transfer the packages.

A staging directory was created on the analyst host:

```powershell
mkdir $HOME\bind9-offline
```

The final package set was:

```text
bind9_9.18.39-0ubuntu0.24.04.7_amd64.deb
bind9-dnsutils_9.18.39-0ubuntu0.24.04.7_amd64.deb
bind9-host_9.18.39-0ubuntu0.24.04.7_amd64.deb
bind9-libs_9.18.39-0ubuntu0.24.04.7_amd64.deb
bind9-utils_9.18.39-0ubuntu0.24.04.7_amd64.deb
dnsutils_9.18.39-0ubuntu0.24.04.7_all.deb
dns-root-data_2024071801-ubuntu0.24.04.1_all.deb
```

The files were transferred to the DNS server with SCP:

```powershell
scp *.deb dnsadmin@192.168.66.53:/home/dnsadmin/bind9-offline/
```

### Important Verification Note

Independent package-hash verification was skipped during this build.

The documentation must therefore state that the packages were transferred successfully, but it must not claim that their hashes were independently verified.

---

## 7. Install BIND9

The local packages were installed with:

```bash
sudo apt install /home/dnsadmin/bind9-offline/*.deb
```

### Command Explanation

* `apt install` installs Ubuntu packages and handles dependencies.
* The absolute path tells APT to use package files from the local staging directory.
* `*.deb` selects all Debian package files in that directory.

The installation completed with:

```text
3 upgraded, 4 newly installed, 0 to remove
```

BIND created:

* A system account named `bind`
* A system group named `bind`
* `/etc/bind/rndc.key`
* A systemd service named `named.service`
* A compatibility link named `bind9.service`

The following message was informational:

```text
Download is performed unsandboxed as root
```

It occurred because the restricted `_apt` account could not access files inside the user’s home directory. The packages still installed successfully.

### Important Air-Gap Observation

During installation, APT retrieved approximately 5,918 bytes for `dns-root-data` from the official Ubuntu archive.

This means the final installation was not completely offline, even though the main BIND packages came from the local staging directory.

This is documented transparently rather than described as a fully offline installation.

Afterward, UFW was configured with a default outbound-deny policy so the DNS server could no longer initiate connections to public destinations.

---

## 8. Record the Installed Versions

The installed versions were recorded with:

```bash
dpkg-query -W -f='${binary:Package}\t${Version}\n' bind9 bind9-libs bind9-utils bind9-host bind9-dnsutils dnsutils dns-root-data
```

### Command Explanation

* `dpkg-query` reads Ubuntu’s installed-package database.
* `-W` displays the requested packages.
* The format prints each package name beside its exact version.

The confirmed versions are:

```text
bind9                  1:9.18.39-0ubuntu0.24.04.7
bind9-dnsutils         1:9.18.39-0ubuntu0.24.04.7
bind9-host             1:9.18.39-0ubuntu0.24.04.7
bind9-libs:amd64       1:9.18.39-0ubuntu0.24.04.7
bind9-utils            1:9.18.39-0ubuntu0.24.04.7
dns-root-data          2024071801~ubuntu0.24.04.1
dnsutils               1:9.18.39-0ubuntu0.24.04.7
```

The saved inventory is available in [`configs/ubuntu/bind9-package-versions.txt`](configs/ubuntu/bind9-package-versions.txt).

---

## 9. Back Up the Original BIND Configuration

Before editing BIND, the original configuration directory was copied:

```bash
sudo cp -a /etc/bind /etc/bind.before-dns-lab-2026-09-02
```

### Command Explanation

* `cp` copies files and directories.
* `-a` preserves permissions, ownership, timestamps, and directory structure.
* `/etc/bind` is the live BIND configuration.
* `/etc/bind.before-dns-lab-2026-09-02` is the local rollback copy.

This backup remains on the DNS server. It should not be committed to Git because it contains `rndc.key`.

---

## 10. Configure BIND as a Lab-Only Authoritative Server

The options file was edited with:

```bash
sudo nano /etc/bind/named.conf.options
```

The final configuration is:

```conf
options {
        directory "/var/cache/bind";

        listen-on { 127.0.0.1; 192.168.66.53; };
        listen-on-v6 { none; };

        allow-query {
                localhost;
                172.16.10.0/24;
                192.168.66.0/24;
                172.16.99.0/24;
        };

        recursion no;
        allow-transfer { none; };
        dnssec-validation no;

        auth-nxdomain no;
};
```

### Option Explanations

#### `directory "/var/cache/bind";`

Defines BIND’s working directory.

#### `listen-on { 127.0.0.1; 192.168.66.53; };`

BIND listens only on:

* `127.0.0.1` for local tests
* `192.168.66.53` for lab clients

It does not listen on every IPv4 interface.

#### `listen-on-v6 { none; };`

Disables BIND’s IPv6 listeners for this IPv4-only lab.

#### `allow-query`

Permits DNS requests from:

| Network           | Purpose                                    |
| ----------------- | ------------------------------------------ |
| `localhost`       | Tests performed directly on the DNS server |
| `172.16.10.0/24`  | Windows victim network                     |
| `192.168.66.0/24` | Kali and DNS-server network                |
| `172.16.99.0/24`  | Management and analyst network             |

#### `recursion no;`

Prevents clients from using this server to resolve arbitrary public domains.

The server answers only for zones it owns, including `exfil.test`.

#### `allow-transfer { none; };`

Blocks AXFR and IXFR zone transfers.

Clients may request individual records, but they cannot download the complete zone database.

#### `dnssec-validation no;`

Disables DNSSEC validation for this isolated authoritative test zone.

This is a lab-specific setting and is not a general production recommendation.

#### `auth-nxdomain no;`

Uses modern standards-compliant handling for non-existent DNS names.

---

## 11. Define the `exfil.test` Zone

The local-zone file was edited with:

```bash
sudo nano /etc/bind/named.conf.local
```

The zone definition is:

```conf
zone "exfil.test" {
        type primary;
        file "/etc/bind/db.exfil.test";
        allow-transfer { none; };
};
```

### Zone Definition Explanations

* `zone "exfil.test"` creates the private lab zone.
* `.test` is intended for testing and avoids conflicts with real public domains.
* `type primary` means this server owns the editable copy of the zone.
* `file` points to the database containing the DNS records.
* `allow-transfer { none; };` repeats the zone-transfer restriction at the zone level.

---

## 12. Create the Zone Database

The zone database was created with:

```bash
sudo nano /etc/bind/db.exfil.test
```

The final file is:

```dns
$TTL 300
@       IN      SOA     dns-srv-01.exfil.test. admin.exfil.test. (
                        2026090201 ; Serial
                        300        ; Refresh
                        120        ; Retry
                        604800     ; Expire
                        300 )      ; Negative cache TTL

@           IN      NS      dns-srv-01.exfil.test.
dns-srv-01  IN      A       192.168.66.53
normal      IN      A       192.168.66.53
*           IN      A       192.168.66.53
```

### Zone Record Explanations

#### `$TTL 300`

Clients may cache answers for 300 seconds, or five minutes.

A short TTL is useful in a lab because record changes become visible quickly.

#### `SOA`

The Start of Authority record identifies the server responsible for the zone.

```text
dns-srv-01.exfil.test.
```

is the authoritative server.

```text
admin.exfil.test.
```

represents the administrator address `admin@exfil.test`. DNS uses a period in place of the `@` symbol inside an SOA record.

#### Serial Number

```text
2026090201
```

uses the format:

```text
YYYYMMDDNN
```

The serial must increase whenever the zone file changes.

#### Refresh, Retry, and Expire

These timers are mainly used by secondary DNS servers. No secondary server is currently configured, but valid SOA values are still required.

#### `NS` Record

The NS record identifies `dns-srv-01.exfil.test` as the zone’s DNS server.

#### `A` Records

The A records map names to IPv4 address `192.168.66.53`.

#### Wildcard Record

```dns
* IN A 192.168.66.53
```

allows controlled test names such as:

```text
fake-data.exfil.test
logging-test.exfil.test
firewall-test.exfil.test
```

to receive an answer without creating a separate record for every test label.

Only fake data should be placed in these names.

---

## 13. Validate and Correct the Zone File

The zone was checked with:

```bash
sudo named-checkzone exfil.test /etc/bind/db.exfil.test
```

### Command Explanation

* `named-checkzone` validates one DNS zone.
* `exfil.test` is the zone name.
* `/etc/bind/db.exfil.test` is the database file being checked.
* Validation should happen before BIND is restarted.

The first check found this error:

```text
near '192.168.66.531': bad dotted quad
```

The wildcard address contained an extra `1`:

```dns
192.168.66.531
```

The file was inspected with line numbers:

```bash
sudo nl -ba /etc/bind/db.exfil.test
```

### Command Explanation

* `nl` displays a text file with line numbers.
* `-ba` numbers every line, including blank lines.
* This made line 12 easy to locate.

The incorrect line was changed from:

```dns
* IN A 192.168.66.531
```

to:

```dns
* IN A 192.168.66.53
```

The corrected zone later loaded successfully, as confirmed by working DNS queries.

### Why This Troubleshooting Step Matters

A DNS address must contain four numeric sections, with each section between 0 and 255.

`192.168.66.531` is invalid because `531` is greater than 255.

The validation tool detected the problem before it could interrupt the DNS service.

---

## 14. Validate the Complete BIND Configuration

All BIND configuration files were checked with:

```bash
sudo named-checkconf
```

### Command Explanation

* `named-checkconf` checks the main BIND configuration.
* It also reads files included by `named.conf`.
* No output means the configuration passed.

The command returned no output, confirming valid syntax.

---

## 15. Start and Verify BIND

BIND was restarted with:

```bash
sudo systemctl restart named
```

The service state was checked with:

```bash
systemctl is-active named
```

Confirmed result:

```text
active
```

Automatic startup was checked with:

```bash
systemctl is-enabled named
```

Confirmed result:

```text
enabled
```

### Active Versus Enabled

* `active` means the service is running now.
* `enabled` means Ubuntu will start it during boot.

Both checks are important.

---

## 16. Configure DNS Query Logging

A protected log directory was created with:

```bash
sudo install -d -o bind -g bind -m 0750 /var/log/named
```

### Command Explanation

* `install -d` creates a directory.
* `-o bind` sets the owner to the BIND service account.
* `-g bind` sets the group to `bind`.
* `-m 0750` gives full access to the owner, read/traverse access to the group, and no access to everyone else.

The logging configuration was created with:

```bash
sudo nano /etc/bind/named.conf.logging
```

The file contains:

```conf
logging {
        channel query_log {
                file "/var/log/named/query.log" versions 5 size 10m;
                severity info;
                print-time yes;
                print-category yes;
                print-severity yes;
        };

        category queries {
                query_log;
        };
};
```

### Logging Explanations

* `channel query_log` creates a logging destination.
* `file` selects `/var/log/named/query.log`.
* `size 10m` rotates the log after it reaches 10 MB.
* `versions 5` keeps five rotated copies.
* `severity info` records normal query information.
* `print-time yes` adds a timestamp.
* `print-category yes` identifies the event category.
* `print-severity yes` identifies the severity.
* `category queries` sends incoming DNS-query events to the channel.

The main configuration was updated with:

```conf
include "/etc/bind/named.conf.logging";
```

The main include section is:

```conf
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.logging";
include "/etc/bind/named.conf.local";
include "/etc/bind/named.conf.default-zones";
```

Creating a separate logging file keeps the configuration organized and makes logging easier to disable or roll back.

After validation, BIND was restarted again:

```bash
sudo named-checkconf
```

```bash
sudo systemctl restart named
```

```bash
systemctl is-active named
```

The service remained active.

---

## 17. Validate the DNS Records

### Test the Normal Record

The normal record was tested directly against BIND:

```bash
dig @192.168.66.53 normal.exfil.test A +short
```

### Command Explanation

* `dig` sends a DNS query.
* `@192.168.66.53` chooses the DNS server.
* `normal.exfil.test` is the requested name.
* `A` requests an IPv4 address.
* `+short` displays only the answer.

Expected result:

```text
192.168.66.53
```

### Test the Wildcard Record

A name without its own explicit record was tested:

```bash
dig @192.168.66.53 fake-test-data.exfil.test A +short
```

Expected result:

```text
192.168.66.53
```

This confirms the wildcard record can support controlled DNS-exfiltration-style labels.

---

## 18. Validate DNS from the Analyst Host

The analyst host sent a remote query from PowerShell:

```powershell
Resolve-DnsName -Name normal.exfil.test -Server 192.168.66.53 -Type A
```

Confirmed result:

```text
Name                 Type TTL Section IPAddress
----                 ---- --- ------- ---------
normal.exfil.test    A    300 Answer  192.168.66.53
```

### Result Explanation

* `Type A` confirms an IPv4 lookup.
* `TTL 300` matches the zone’s five-minute TTL.
* `Answer` means the server returned a successful response.
* `192.168.66.53` is the expected address.

This test confirms:

* Routing from VLAN 99 to VLAN 66
* Juniper policy operation
* DNS port 53 reachability
* BIND listener operation
* Zone-record operation

The query log identified the analyst host as:

```text
172.16.99.10
```

---

## 19. Confirm Query Logging

A safe logging test was generated with:

```bash
dig @192.168.66.53 logging-test.exfil.test A +short
```

The log was read with:

```bash
sudo cat /var/log/named/query.log
```

A sample entry was:

```text
02-Sep-2026 17:50:22.089 queries: info: client ... 192.168.66.53#37306 (logging-test.exfil.test): query: logging-test.exfil.test IN A ... (192.168.66.53)
```

### Log Entry Explanation

* The first field is the request time.
* `queries` is the logging category.
* `info` is the event severity.
* The client address identifies the requesting system.
* The number after `#` is the client’s temporary source port.
* `logging-test.exfil.test` is the requested name.
* `IN A` means an IPv4 Internet-class query.
* The final address identifies the DNS server that received the request.

The saved sample includes:

* A local wildcard lookup
* A remote lookup from `172.16.99.10`
* A refused public recursive lookup
* A blocked AXFR request
* A successful post-firewall lookup

See [`evidence/dns-server/query-log-sample.txt`](evidence/dns-server/query-log-sample.txt).

---

## 20. Confirm Public Recursion Is Disabled

BIND was asked to resolve a domain it does not own:

```bash
dig @192.168.66.53 example.com A +noall +comments
```

`example.com` is reserved for documentation and testing.

The confirmed response included:

```text
status: REFUSED
ANSWER: 0
WARNING: recursion requested but not available
```

### Result Explanation

* `REFUSED` means BIND rejected the request.
* `ANSWER: 0` means no public address was returned.
* `rd` means the client requested recursion.
* The warning confirms recursion was unavailable.
* EDNS and cookie lines are normal DNS protocol metadata.

This confirms BIND is authoritative-only.

It does not, by itself, prove that the entire Ubuntu operating system lacks Internet access. Host-level outbound control is handled separately with UFW.

---

## 21. Confirm Zone Transfers Are Disabled

A complete zone transfer was requested with:

```bash
dig @192.168.66.53 exfil.test AXFR
```

Confirmed result:

```text
Transfer failed.
```

### Why This Matters

AXFR requests every record in a zone.

Blocking it prevents clients from downloading the entire zone database while still allowing normal individual DNS queries.

---

## 22. Confirm the Listening Addresses

DNS listeners were checked with:

```bash
sudo ss -lntup '( sport = :53 )'
```

### Command Explanation

* `ss` displays network sockets.
* `l` shows listeners.
* `n` shows numeric addresses.
* `t` includes TCP.
* `u` includes UDP.
* `p` shows process names.
* The filter limits the output to port 53.

The final result showed `named` listening on:

```text
192.168.66.53:53
127.0.0.1:53
```

for both TCP and UDP.

There were no `named` listeners on:

```text
0.0.0.0:53
[::]:53
```

Ubuntu’s `systemd-resolved` service also listens on:

```text
127.0.0.53:53
127.0.0.54:53
```

These are separate loopback addresses and do not conflict with BIND.

Multiple `named` rows are normal because BIND may create more than one internal listener socket.

---

## 23. Configure the Ubuntu Firewall

UFW was initially inactive:

```bash
sudo ufw status verbose
```

Result:

```text
Status: inactive
```

Firewall rules were prepared before enabling UFW to prevent SSH lockout.

### Allow SSH from the Management Network

```bash
sudo ufw allow from 172.16.99.0/24 to any port 22 proto tcp comment 'Allow SSH from management VLAN'
```

This permits SSH only from VLAN 99.

### Allow DNS from the Victim Network

```bash
sudo ufw allow from 172.16.10.0/24 to any port 53 comment 'Allow DNS from victim VLAN'
```

This permits Windows victims to send DNS requests.

### Allow DNS from VLAN 66

```bash
sudo ufw allow from 192.168.66.0/24 to any port 53 comment 'Allow DNS from VLAN 66'
```

This permits Kali and other approved VLAN 66 systems to send DNS requests.

### Allow DNS from the Management Network

```bash
sudo ufw allow from 172.16.99.0/24 to any port 53 comment 'Allow DNS from management VLAN'
```

This permits the analyst host to test the DNS service.

Because no protocol was specified for port 53, these DNS rules permit both UDP and TCP.

### Allow Approved Outbound Lab Traffic

```bash
sudo ufw allow out to 172.16.99.0/24 comment 'Allow outbound to management VLAN'
```

```bash
sudo ufw allow out to 192.168.66.0/24 comment 'Allow outbound to VLAN 66'
```

These rules allow the server to initiate connections only to approved internal networks.

### Set the Default Policies

```bash
sudo ufw default deny incoming
```

```bash
sudo ufw default deny outgoing
```

Unmatched inbound and outbound traffic is blocked.

Replies to permitted DNS and SSH requests remain allowed because UFW tracks connection state.

### Review the Prepared Rules

```bash
sudo ufw show added
```

This read-only safety check confirmed all required rules existed before activation.

### Enable UFW

```bash
sudo ufw enable
```

Confirmed result:

```text
Firewall is active and enabled on system startup
```

### Verify the Active Firewall

```bash
sudo ufw status verbose
```

Confirmed state:

```text
Status: active
Logging: on (low)
Default: deny (incoming), deny (outgoing), disabled (routed)
```

The complete saved output is available in [`configs/ubuntu/ufw-status.txt`](configs/ubuntu/ufw-status.txt).

---

## 24. Perform Post-Firewall Tests

The original SSH session was kept open while a second connection was tested:

```powershell
ssh dnsadmin@192.168.66.53
```

The new connection succeeded.

A remote DNS lookup was then performed:

```powershell
Resolve-DnsName -Name firewall-test.exfil.test -Server 192.168.66.53 -Type A
```

The lookup returned:

```text
192.168.66.53
```

This confirms that UFW permits the required SSH and DNS traffic.

### Test an Unapproved Destination

A reserved test address was used:

```bash
ping -c 3 -W 1 192.0.2.1
```

The ping failed as expected.

`192.0.2.1` belongs to the documentation-only `TEST-NET-1` range. This avoided testing against a real public system.

### Test an Approved Internal Destination

The VLAN 66 gateway was tested:

```bash
ping -c 3 -W 1 192.168.66.1
```

The ping succeeded.

Together, these tests show:

* Approved internal communication works.
* Unapproved outbound destinations are blocked.
* SSH remains available from management.
* DNS remains available from approved lab networks.

---

## 25. Export Configuration and Evidence for Git

A staging directory was created:

```bash
mkdir -p /home/dnsadmin/lab-config-export
```

### Export the BIND Configuration

```bash
sudo install -o dnsadmin -g dnsadmin -m 0644 \
/etc/bind/named.conf \
/etc/bind/named.conf.options \
/etc/bind/named.conf.local \
/etc/bind/named.conf.logging \
/etc/bind/db.exfil.test \
/home/dnsadmin/lab-config-export/
```

`install` copied the files while assigning transfer-friendly ownership and permissions.

The secret `rndc.key` file was not copied.

### Export the Firewall State

```bash
sudo ufw status verbose | tee /home/dnsadmin/lab-config-export/ufw-status.txt
```

The pipe sends the firewall output to `tee`, which displays it and saves it.

### Export the Package Versions

```bash
dpkg-query -W -f='${binary:Package}\t${Version}\n' bind9 bind9-libs bind9-utils bind9-host bind9-dnsutils dnsutils dns-root-data | tee /home/dnsadmin/lab-config-export/bind9-package-versions.txt
```

### Export a Small Query-Log Sample

```bash
sudo tail -n 50 /var/log/named/query.log | tee /home/dnsadmin/lab-config-export/query-log-sample.txt
```

Only the newest 50 lines were collected. The full live log was not copied.

### Verify the Export

```bash
ls -lh /home/dnsadmin/lab-config-export
```

Eight safe files were confirmed.

---

## 26. Copy the Exported Files into the Repository

The repository was located at:

```text
C:\Users\iefym\OneDrive\Documents\Air-Gapped-Security-Lab
```

A PowerShell shortcut variable was created:

```powershell
$Repo = "C:\Users\iefym\OneDrive\Documents\Air-Gapped-Security-Lab"
```

The destination folders were created with:

```powershell
New-Item -ItemType Directory -Force -Path "$Repo\01_dns_exfiltration_lab\configs\bind9","$Repo\01_dns_exfiltration_lab\configs\ubuntu","$Repo\01_dns_exfiltration_lab\evidence\dns-server"
```

### Copy the BIND Files

```powershell
scp "dnsadmin@192.168.66.53:/home/dnsadmin/lab-config-export/named.conf*" "dnsadmin@192.168.66.53:/home/dnsadmin/lab-config-export/db.exfil.test" "$Repo\01_dns_exfiltration_lab\configs\bind9"
```

### Copy the Ubuntu Files

```powershell
scp "dnsadmin@192.168.66.53:/home/dnsadmin/lab-config-export/ufw-status.txt" "dnsadmin@192.168.66.53:/home/dnsadmin/lab-config-export/bind9-package-versions.txt" "$Repo\01_dns_exfiltration_lab\configs\ubuntu"
```

### Copy the Evidence File

```powershell
scp "dnsadmin@192.168.66.53:/home/dnsadmin/lab-config-export/query-log-sample.txt" "$Repo\01_dns_exfiltration_lab\evidence\dns-server"
```

### Verify the Repository Copies

```powershell
Get-ChildItem -Path "$Repo\01_dns_exfiltration_lab\configs\bind9","$Repo\01_dns_exfiltration_lab\configs\ubuntu","$Repo\01_dns_exfiltration_lab\evidence\dns-server" -File | Select-Object FullName,Length
```

Eight files with non-zero sizes were confirmed.

---



## 28. Troubleshooting Notes

### BIND Configuration Check Produces No Output

This is normal:

```bash
sudo named-checkconf
```

No output means the syntax passed.

### DNS Service Name

Ubuntu runs BIND through:

```text
named.service
```

The `bind9.service` name is a compatibility link.

### `systemd-resolved` Also Uses Port 53

This is normal when it listens only on:

```text
127.0.0.53
127.0.0.54
```

BIND uses:

```text
127.0.0.1
192.168.66.53
```

The addresses do not conflict.

### SSH Stops Working After a Firewall Change

Use the Proxmox VM console and check:

```bash
sudo ufw status verbose
```

If emergency access is required:

```bash
sudo ufw disable
```

Then correct the SSH rule before enabling UFW again.

### BIND Does Not Start

Check the configuration first:

```bash
sudo named-checkconf
```

Check the zone:

```bash
sudo named-checkzone exfil.test /etc/bind/db.exfil.test
```

Then inspect recent service messages:

```bash
sudo journalctl -u named --no-pager -n 50
```

### DNS Query Does Not Appear in the Log

Check that the log exists:

```bash
sudo ls -l /var/log/named/query.log
```

Follow new entries in real time:

```bash
sudo tail -f /var/log/named/query.log
```

Press **Ctrl+C** to stop following the log.

---

## 29. Rollback Summary

The original local BIND configuration is stored at:

```text
/etc/bind.before-dns-lab-2026-09-02
```

Detailed rollback instructions are maintained in [`13_rollback.md`](13_rollback.md).

Do not copy the entire local backup into Git because it contains the private `rndc.key` file.

The exported files under `configs/` are documentation copies. Editing them does not automatically change the running DNS server.
