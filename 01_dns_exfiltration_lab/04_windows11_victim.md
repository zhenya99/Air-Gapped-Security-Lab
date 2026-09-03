# 04. Windows 11 Victim

## Purpose

The Windows 11 system acts as the victim workstation in the DNS exfiltration lab.

It generates normal and controlled DNS activity that can be observed by the lab's DNS, logging, and monitoring systems.

---

## Network Configuration

| Setting | Value |
|---|---|
| Operating system | Windows 11 Home |
| IPv4 address | `172.16.10.50` |
| Subnet | `172.16.10.0/24` |
| Subnet mask | `255.255.255.0` |
| Default gateway | `172.16.10.1` |
| DNS server | `192.168.66.53` |
| VLAN | `10` |
| DNS test zone | `exfil.test` |

Traffic follows this path:

```text
Windows 11 Victim
172.16.10.50
VLAN 10
      |
      v
Juniper SRX
172.16.10.1
      |
      | Inter-VLAN Routing
      v
VLAN 66
      |
      v
BIND9 DNS Server
192.168.66.53
```

---

## Verify Windows Networking

Open PowerShell and run:

```powershell
ipconfig /all
```

Confirm:

```text
IPv4 Address = 172.16.10.50
Subnet Mask  = 255.255.255.0
Gateway      = 172.16.10.1
DNS Server   = 192.168.66.53
```

Verify the gateway:

```powershell
ping 172.16.10.1
```

---

## Verify DNS Resolution

Run:

```powershell
nslookup normal.exfil.test 192.168.66.53
```

Validated result:

```text
Name:    normal.exfil.test
Address: 192.168.66.53
```

The following test names were also successfully used:

```text
confirmation001.exfil.test
testdata001.exfil.test
sysmon22test.exfil.test
```

Example:

```powershell
nslookup confirmation001.exfil.test 192.168.66.53
```

---

## `Server: Unknown`

`nslookup` may display:

```text
Server:  Unknown
Address: 192.168.66.53
```

This does not indicate a failed DNS lookup.

Windows performs a reverse lookup for:

```text
53.66.168.192.in-addr.arpa
```

The lab does not currently have a reverse PTR zone for `192.168.66.53`, so BIND9 may return:

```text
REFUSED
```

Forward resolution of `exfil.test` continues to work normally.

---

## Packet-Level DNS Validation

On the DNS server:

```bash
sudo tcpdump -ni any 'host 172.16.10.50 and port 53'
```

A validated query showed:

```text
172.16.10.50.64309 > 192.168.66.53.53:
A? confirmation001.exfil.test.
```

The DNS server replied:

```text
192.168.66.53.53 > 172.16.10.50.64309:
A 192.168.66.53
```

Windows also generated an AAAA request:

```text
AAAA? confirmation001.exfil.test.
```

This is normal. The lab currently uses IPv4, so the successful `A` response is the important result.

---

## PowerShell Remote Administration

Because the victim uses **Windows 11 Home**, it cannot normally act as a Microsoft Remote Desktop host.

PowerShell Remoting using WinRM was configured instead.

The administration path is:

```text
Admin Workstation
172.16.99.10
VLAN 99 / MGMT
      |
      | WinRM TCP/5985
      v
Juniper SRX
      |
      v
Windows Victim
172.16.10.50
VLAN 10 / VICTIMS
```

### Victim WinRM Validation

WinRM was confirmed with:

```powershell
winrm quickconfig
```

TCP/5985 was confirmed listening:

```powershell
Get-NetTCPConnection -LocalPort 5985 -State Listen
```

The network profile was verified:

```powershell
Get-NetConnectionProfile
```

Result:

```text
NetworkCategory = Private
```

The WinRM firewall rule was verified:

```powershell
Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP-NoScope" |
Select-Object Name,Enabled,Profile
```

The allowed source scope was checked with:

```powershell
Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP-NoScope" |
Get-NetFirewallAddressFilter
```

---

## Administrative Workstation Route

The administrative workstation uses:

```text
172.16.99.10
```

A persistent route exists for VLAN 10:

```text
172.16.10.0/24 -> 172.16.99.1
```

Verify with:

```powershell
Get-NetRoute -DestinationPrefix "172.16.10.0/24"
```

The Juniper SRX gateway was successfully reached:

```powershell
Test-NetConnection 172.16.99.1
```

---

## Juniper Security Zones

The SRX configuration confirmed:

```text
ge-0/0/0.99 = MGMT
ge-0/0/0.10 = VICTIMS
```

Commands used:

```text
show configuration security zones | display set | match ge-0/0/0.99
```

```text
show configuration security zones | display set | match ge-0/0/0.10
```

A restricted management path was required for:

```text
172.16.99.10 -> 172.16.10.50 TCP/5985
```

---

## Connect to the Victim

From the administrative Windows workstation:

```powershell
Enter-PSSession -ComputerName 172.16.10.50 -Credential victim
```

A successful session produces a prompt similar to:

```text
[172.16.10.50]: PS C:\Users\Victim\Documents>
```

This remote session is now used to administer the victim and run lab commands without relying on the Proxmox console.

---

## Confirmed State

```text
System:          Windows 11 Home
Role:            Victim / DNS Test Source
IP:              172.16.10.50
Subnet:          /24
Gateway:         172.16.10.1
DNS:             192.168.66.53
VLAN:            10
DNS Zone:        exfil.test
Remote Admin:    PowerShell Remoting / WinRM
WinRM Port:      TCP/5985
```

---

## Conclusion

The Windows 11 victim is fully operational.

DNS communication between `172.16.10.50` and `192.168.66.53` has been validated, and PowerShell Remoting provides remote command-line administration from the management workstation.

The victim is ready for endpoint telemetry collection using Sysmon.