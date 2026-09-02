# Cisco and Juniper setup for Splunk detection engineering

Prepared 2026-09-02 against the saved baseline. These are configuration overlays for the existing lab, not factory-reset configurations. Nothing has been applied to the devices.

Security Onion is the only current VM. The Windows victim, BIND server and Splunk will be deployed later. The analyst and Kali retain Internet access through their separate adapters. The unplugged Fios router has no role in these changes.

## Files to use

| File | When to apply |
|---|---|
| [Juniper core](configs/juniper/dns-lab-changes.txt) | First, after preflight and backup |
| [Cisco core](configs/cisco/dns-lab-changes.txt) | After validating SRX management and existing traffic |
| [Proxmox bridge extension](configs/proxmox/dns-lab-changes.txt) | After both network devices are validated |
| [DNS capture profile](configs/cisco/dns-capture-profile.txt) | Optional, during a controlled victim-side DNS measurement |
| [Splunk collection plan](configs/telemetry/README.md) | Later, once a collector has been deployed |
| [Rollback](12_rollback.md) | Recovery and return-to-baseline instructions |

The core files contain no automatic save or commit. Existing device credentials, SSH keys, management addresses and native VLAN assignments are retained.

## 1. Preflight and pre-change backups

Use the analyst's wired address 172.16.99.10 or a console. Keep console access available when changing the Cisco SSH access list. Use fresh backup names for each change window; the names below assume the first application.

On Cisco:

```text
show version
show interfaces trunk
show interfaces status
show monitor session 1
show ip interface brief
show running-config
show line
show access-lists
copy running-config flash:pre-dns-lab.cfg
copy startup-config flash:pre-dns-lab-startup.cfg
```

Confirm Gi1/0/1 is the SRX trunk, Gi1/0/27 is Proxmox nic0, Gi1/0/28 is the capture connection and Gi1/0/47 is the analyst. Confirm the named ACL LAB_ANALYST_ONLY is unused. If the release does not support the documented commands, adapt them before making changes.

On SRX, in operational mode:

```text
show version
show interfaces terse
show configuration interfaces | display set
show configuration security zones | display set
show configuration security policies | display set
show configuration security log | display set
show configuration system syslog | display set
show configuration security nat | display set
show route
show configuration | save /var/tmp/pre-dns-lab.conf
```

The overlay expects the saved ATTACKER, VICTIMS and MGMT zones, ge-0/0/0 VLAN tagging, ge-0/0/5.0 for Kali, and the existing ATTACK-TRAFFIC, WIN-TO-KALI, LOG-FORWARDING, BLOCK-KALI and ALLOW-KALI-PING-PROXMOX policies. DNS-LAB and the LAB-* names must be unused on first application.

Compare actual policies with the baseline before applying. Additional earlier permits, global policies, address-book layouts or logging settings need review. In particular, record an existing stream logging configuration before switching to the proposed low-rate event mode. Do not replace a working remote logging pipeline blindly.

These overlays do not add WAN routes, NAT or an Internet connection. Existing unrelated configuration is not cleared. Device configuration backups may contain authentication material; retain them privately.

## 2. Apply the Juniper overlay

Start an exclusive configuration session so another change does not mix with this one:

```text
configure exclusive
load set terminal
```

Paste the command lines from configs/juniper/dns-lab-changes.txt. Omit comment lines if pasting individual commands rather than loading a set file. Press Ctrl+D to finish terminal input.

```text
show | compare
commit check
commit confirmed 10
```

If loading reports errors or commit check fails, correct the candidate before committing. In configuration mode, rollback 0 discards the current uncommitted candidate changes.

Within the confirmation window, open a NEW SSH session from the analyst. Verify the existing management path and the new connected network:

```text
show interfaces terse
show route 172.16.20.0/24 exact
show security policies from-zone VICTIMS to-zone DNS-LAB
show security policies from-zone VICTIMS to-zone MGMT
show security policies from-zone ATTACKER to-zone MGMT
show system commit
```

Expected:

- ge-0/0/0.20 has 172.16.20.1/24.
- VICTIM-DNS precedes LAB-DENY-V-D.
- LOG-FORWARDING is inactive; LAB-DENY-V-M is active.
- The specific Kali-to-Proxmox ICMP permit precedes BLOCK-KALI.
- Analyst SSH to the SRX still works.
- Kali can still ping 172.16.99.20 and the existing Security Onion test remains usable.

After those checks, return to the configuration session and run:

```text
commit
exit
```

Do not run commit or commit check during the rollback window until you intend to confirm: both can confirm the pending commit. If access fails, let the timer expire or recover from console as described in the rollback guide.

Do not wait for absent VMs to respond before confirming this infrastructure stage. DNS service validation happens after they exist.

## 3. Apply the Cisco overlay

Apply configs/cisco/dns-lab-changes.txt from the privileged CLI. It adds VLAN 20 to the existing trunk lists without replacing those lists, recreates the known SPAN session, and limits VTY access to the analyst.

Before saving, open a NEW SSH session from 172.16.99.10 and check:

```text
show interfaces trunk
show vlan brief
show monitor session 1
show access-lists LAB_ANALYST_ONLY
show running-config | section line vty
show clock detail
show logging
```

Expected trunk state:

```text
Gi1/0/1:  allowed 10,20,99,999; native 999
Gi1/0/27: allowed 10,20,99;     native 99
SPAN:     source Gi1/0/27 both; destination Gi1/0/28; replicate
```

Verify access to Proxmox 172.16.99.20 and Security Onion 172.16.99.30. Then save:

```text
copy running-config startup-config
```

The switch remains layer 2. VLAN 20 gets its gateway from the SRX, not from a Cisco SVI. Existing shutdown ports remain shutdown.

## 4. Extend Proxmox and preserve Internet routes

Follow configs/proxmox/dns-lab-changes.txt to add VLAN 20 to vmbr0. Keep all capture MTUs and VM 900 NIC assignments unchanged.

On the analyst, the saved persistent routes already cover the lab:

```text
172.16.0.0/16 via 172.16.99.1
192.168.66.0/24 via 172.16.99.1
```

Keep the Ethernet interface without a default gateway. Wi-Fi supplies the Internet default route. Verify existing routes with Get-NetRoute rather than adding duplicates.

On Kali, keep the lab address 192.168.66.50/24 and route 172.16.0.0/16 through 192.168.66.1. Its Internet adapter should own the default route. The old Kali baseline sets an SRX default gateway, so that connection profile needs adjustment.

Find the LAB connection name with nmcli connection show, then substitute that name in these commands. These are host commands, not Cisco/SRX configuration:

```bash
sudo nmcli connection modify "<KALI-LAB-CONNECTION>" ipv4.never-default yes ipv4.ignore-auto-dns yes
sudo nmcli connection modify "<KALI-LAB-CONNECTION>" +ipv4.routes "172.16.0.0/16 192.168.66.1"
sudo nmcli connection up "<KALI-LAB-CONNECTION>"
ip route get 172.16.99.20
ip route get 1.1.1.1
```

Add the persistent route only if it is not already present. Bringing up the connection may interrupt a lab SSH session; use Kali's local terminal. Expected: lab destinations via the lab adapter/SRX, Internet destinations via the Internet adapter. Use a different subnet for the Internet adapter if it overlaps any lab subnet.

Do not enable connection sharing, NAT or bridging between either host's Internet and lab adapters; the hosts can use both networks directly. Their Internet traffic is outside this SPAN observation point.

## 5. Create the DNS endpoints later

| VM | NIC | IPv4 | Gateway | DNS |
|---|---|---|---|---|
| Windows 910 | vmbr0, tag 10 | 172.16.10.50/24 | 172.16.10.1 | 172.16.20.53 |
| Ubuntu/BIND 920 | vmbr0, tag 20 | 172.16.20.53/24 | 172.16.20.1 | Local service as configured |

Check VMIDs first. Set VLAN tags at Proxmox; do not also tag guest NICs. There is no antiX dependency.

Configure BIND to listen on its lab address for UDP/TCP 53, serve exfil.test locally, log queries, and answer a known baseline.exfil.test test record. Keep the exercise independent of Internet recursion. Guest firewall rules must admit those DNS requests and intended analyst administration. Do not add public DNS as a Windows fallback for this exercise.

## 6. Validate the policy and packet paths

Perform these checks after the required guests/services exist. A timeout by itself does not prove a firewall denial: correlate the attempt with SRX policy/session logs.

| Source | Test | Expected |
|---|---|---|
| Analyst .99.10 | SRX and Cisco SSH | Allowed |
| Analyst .99.10 | Guest administration | Allowed by SRX; requires guest service/firewall |
| Kali .66.50 | ICMP to Proxmox .99.20 | Allowed; existing SID 1000001 should fire in general capture mode |
| Kali .66.50 | TCP 8006 to Proxmox .99.20 | Denied by BLOCK-KALI |
| Kali .66.50 | DNS to BIND .20.53 | Allowed over UDP and TCP |
| Windows .10.50 | DNS to BIND .20.53 | Allowed over UDP and TCP |
| Windows .10.50 | SSH to BIND .20.53 | Denied by LAB-DENY-V-D |
| Windows .10.50 | TCP 8006 to Proxmox .99.20 | Denied by LAB-DENY-V-M |
| DNS .20.53 | New connection to victim | Denied by LAB-DENY-D-V |
| Windows/DNS | TCP 9997 to future .99.40 | Denied before optional telemetry stage |

From Kali:

```bash
dig @172.16.20.53 baseline.exfil.test A
dig +tcp @172.16.20.53 baseline.exfil.test A
```

From Windows VM 910:

```powershell
Resolve-DnsName baseline.exfil.test -Type A -Server 172.16.20.53 -DnsOnly
Resolve-DnsName baseline.exfil.test -Type A -Server 172.16.20.53 -DnsOnly -TcpOnly
Test-NetConnection 172.16.20.53 -Port 22
Test-NetConnection 172.16.99.20 -Port 8006
```

Use a packet capture to confirm transport and actual requests; caches can prevent repeated lookups from reaching the wire.

On SRX:

```text
show security flow session source-prefix 172.16.10.50 destination-prefix 172.16.20.53
show log lab-traffic | last 30
show security policies hit-count
show system uptime
```

Permit logs use session-close; allow time for a DNS session to expire. Several UDP DNS queries can share one session, so firewall log counts are not query counts. Policy changes and existing sessions can also interact: use fresh connections for negative tests and inspect the matching policy.

On Security Onion:

```bash
sudo tcpdump -ni bond0 -e -c 30 'vlan 10 and host 172.16.10.50 and port 53'
```

Confirm both requests and responses and correlate one unique query across PCAP, Zeek and BIND. In the general capture profile, inspect VLANs 10 and 20 separately; do not treat their two observations as two user queries. Use the optional DNS capture profile for clean victim-side measurements.

## 7. Enable Splunk ingestion later

Follow configs/telemetry/README.md when the proposed collector exists. Apply the two future-splunk-telemetry.txt files only then. They send device syslog to UDP 514 and permit endpoint forwarders to TCP 9997 without enabling arbitrary victim-to-management TCP access.

The core network stage is complete when management, routing, SPAN and the expected policy decisions are validated. End-to-end detection readiness additionally requires the guests, telemetry configuration, Splunk and successful ingestion.

## References

- [Cisco VLAN trunks](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst2960x/software/15-2_3_e/consolidated_guide/b_1523e_consolidated_2960x_cg/b_consolidated_152ex_2960-X_cg_chapter_0111100.html): additive allowed-VLAN changes.
- [Cisco SPAN](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst2960x/software/15-2_3_e/consolidated_guide/b_1523e_consolidated_2960x_cg/b_consolidated_152ex_2960-X_cg_chapter_011010.html): both directions, VLAN filtering, replication and capture limits.
- [Juniper commit](https://www.juniper.net/documentation/us/en/software/junos/cli-reference/topics/ref/command/commit.html): confirmed commits and confirmation behavior.
- [Juniper security policy configuration](https://www.juniper.net/documentation/us/en/software/junos/security-policies/topics/topic-map/security-policy-configuration.html): applications and policy handling.
- [Juniper logging](https://www.juniper.net/documentation/us/en/software/junos/network-mgmt/topics/topic-map/system-logging-for-a-security-device.html): event/stream modes and local logging.
