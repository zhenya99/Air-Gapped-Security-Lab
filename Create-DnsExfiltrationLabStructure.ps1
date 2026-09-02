[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$LabRoot = Join-Path $RepositoryRoot "01_dns_exfiltration_lab"

if (-not (Test-Path -LiteralPath $RepositoryRoot -PathType Container)) {
    throw "Repository folder not found: $RepositoryRoot"
}

if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot ".git"))) {
    throw "This is not the Git repository root. Open PowerShell inside Air-Gapped-Security-Lab, or provide -RepositoryRoot with the correct path."
}

$Folders = @(
    $LabRoot,
    (Join-Path $LabRoot "configs"),
    (Join-Path $LabRoot "evidence"),
    (Join-Path $LabRoot "scripts")
)

foreach ($Folder in $Folders) {
    if (-not (Test-Path -LiteralPath $Folder)) {
        New-Item -ItemType Directory -Path $Folder | Out-Null
        Write-Host "Created folder: $Folder" -ForegroundColor Green
    }
}

function New-BeginnerLabFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $FullPath = Join-Path $LabRoot $RelativePath
    $ParentFolder = Split-Path -Parent $FullPath

    if (-not (Test-Path -LiteralPath $ParentFolder)) {
        New-Item -ItemType Directory -Path $ParentFolder | Out-Null
    }

    if (Test-Path -LiteralPath $FullPath) {
        Write-Host "Skipped existing file: $RelativePath" -ForegroundColor Yellow
        return
    }

    $Utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($FullPath, $Content.TrimStart(), $Utf8WithoutBom)
    Write-Host "Created file: $RelativePath" -ForegroundColor Green
}

$Files = [ordered]@{
    "README.md" = @'
# DNS Exfiltration Detection Lab

## What Is This Lab?

This is a safe, air-gapped lab for learning how information can be hidden inside DNS requests and how that activity can be detected.

Only fake test data is used. The lab does not communicate with the Internet.

---

## Systems in the Lab

| System | Purpose | IP address |
|---|---|---|
| Windows 11 | Victim computer | `172.16.10.50` |
| Ubuntu DNS server | Runs BIND9 | `192.168.66.53` |
| Kali Linux | Generates controlled test activity | `192.168.66.50` |
| Security Onion | Examines copied network traffic | `172.16.99.30` |
| Splunk Enterprise | Searches DNS and Sysmon logs | `172.16.99.40` |
| Proxmox | Runs the virtual machines | `172.16.99.20` |

---

## Lab Networks

| VLAN | Network | Purpose |
|---:|---|---|
| 10 | `172.16.10.0/24` | Windows victim network |
| 66 | `192.168.66.0/24` | Kali and DNS-server network |
| 99 | `172.16.99.0/24` | Management and Splunk network |

---

## How the Lab Works

| Step | What happens |
|---:|---|
| 1 | Windows sends a DNS request from VLAN 10. |
| 2 | The Juniper SRX routes it to the DNS server in VLAN 66. |
| 3 | The Ubuntu BIND9 server answers the request and records it. |
| 4 | The Cisco switch copies the network traffic to Security Onion. |
| 5 | Windows and DNS logs are sent to Splunk. |
| 6 | We investigate the activity with Security Onion and Splunk. |

---

## Build Order

1. Prepare the network.
2. Create the Ubuntu DNS server.
3. Install and configure BIND9.
4. Create the Splunk server.
5. Create the Windows 11 victim.
6. Install Sysmon and the Splunk Universal Forwarder.
7. Record normal DNS activity.
8. Run a safe DNS-exfiltration simulation.
9. Create and test detections.
10. Record results and test rollback.

---

## Safety Rules

- Use only fake test data.
- Keep all traffic inside the air-gapped lab.
- Do not send test traffic to public DNS servers.
- Never store passwords or private keys in Git.
- Keep `BASELINE_CONFIGURATION/` unchanged.
'@

    "01_architecture.md" = @'
# 01 — Lab Architecture

## What Is Architecture?

Architecture is a simple map of the systems, networks, and connections used by the lab.

---

## Systems and Roles

| System | Role |
|---|---|
| Windows 11 | Victim computer |
| Ubuntu Server | Dedicated BIND9 DNS server |
| Kali Linux | Controlled testing computer |
| Security Onion | Network monitoring platform |
| Splunk Enterprise | Log searching and detection platform |
| Proxmox | Virtual-machine host |
| Cisco switch | Network connection and traffic copying |
| Juniper SRX | Routing and firewall control |

---

## Networks

| VLAN | Network | Gateway | Main systems |
|---:|---|---|---|
| 10 | `172.16.10.0/24` | `172.16.10.1` | Windows 11 |
| 66 | `192.168.66.0/24` | `192.168.66.1` | Kali and Ubuntu DNS server |
| 99 | `172.16.99.0/24` | `172.16.99.1` | Proxmox, Security Onion, and Splunk |

---

## Important Connections

| Connection | Purpose |
|---|---|
| Juniper SRX to Cisco Gi1/0/1 | Routes traffic between VLANs |
| Proxmox `nic0` to Cisco Gi1/0/27 | Carries normal VM and management traffic |
| Proxmox `nic1` to Cisco Gi1/0/28 | Receives copied SPAN traffic |

---

## Proxmox Bridges

| Bridge | Purpose |
|---|---|
| `vmbr0` | Carries VLANs 10, 66, and 99 |
| `vmbr1` | Delivers copied traffic to Security Onion |

`vmbr1` is for passive monitoring. It must not have an IPv4 address, gateway, or DHCP configuration.

---

## DNS Traffic

| Step | Traffic movement |
|---:|---|
| 1 | Windows sends a DNS request from `172.16.10.50`. |
| 2 | The Juniper SRX routes it from VLAN 10 to VLAN 66. |
| 3 | The Ubuntu DNS server receives it at `192.168.66.53`. |
| 4 | The response returns to Windows through the same routed path. |

---

## Detection Data

| Platform | Data it examines |
|---|---|
| Security Onion | Copied DNS network traffic |
| Splunk | BIND9 logs, Sysmon events, and Windows DNS events |

The two platforms provide different views of the same lab activity.
'@

    "02_network_changes.md" = @'
# 02 — Network Changes

## What Is This File For?

This file records every network change made specifically for the DNS lab.

---

## Proxmox Change — September 2, 2026

### Why Was It Needed?

The Windows victim needs VLAN 10. Proxmox `vmbr0` therefore needs VLAN awareness.

### Change Made

The following lines were added to the `vmbr0` section of `/etc/network/interfaces`:

```text
bridge-vlan-aware yes
bridge-vids 10 99
```

### How It Was Tested

- `ifreload -a -n` completed without an error.
- `ifreload -a` completed successfully.
- Proxmox remained available at `172.16.99.20`.
- The gateway `172.16.99.1` replied with 0% packet loss.
- `bridge vlan show` confirmed VLANs 10 and 99 on `nic0`.

### Backup

The previous configuration was saved as:

```text
/root/interfaces.before-dns-lab-2026-09-02
```

---

## Cisco Validation

| Item | Verified setting |
|---|---|
| Gi1/0/27 | Proxmox trunk |
| Native VLAN | 99 |
| Gi1/0/28 | Security Onion SPAN destination |
| SPAN source | Gi1/0/27, both directions |
| SPAN encapsulation | Replicate |

---

## Next Network Change

VLAN 66 must be added to `vmbr0` before the Ubuntu DNS-server VM is connected.

Record the exact command and test result here after completing that change.
'@

    "03_proxmox_vms.md" = @'
# 03 — Proxmox Virtual Machines

## What Is This File For?

This file records the virtual machines used by the DNS lab.

| VMID | Name | Purpose | Memory | Disk | Status |
|---:|---|---|---:|---:|---|
| 900 | `SecOnion` | Network monitoring | 24 GB | 250 GB | Existing |
| 901 | `DNS-SRV-01` | Ubuntu BIND9 DNS server | 2 GB | 32 GB | Planned |
| 902 | `SPLUNK-SRV-01` | Splunk Enterprise | 8 GB | 100 GB | Planned |
| 903 | `WIN11-VICTIM-01` | Windows victim | 6 GB | To be selected | Planned |

All new VM disks should use `ext-ssd`.

For each VM, record:

1. The creation settings.
2. The network bridge and VLAN.
3. The operating-system installation.
4. The final IP address.
5. The validation result.
'@

    "04_windows11_victim.md" = @'
# 04 — Windows 11 Victim

## Purpose

Windows 11 acts as the victim computer that generates DNS activity.

## Planned Network Settings

| Setting | Value |
|---|---|
| IP address | `172.16.10.50` |
| Subnet | `/24` |
| Gateway | `172.16.10.1` |
| DNS server | `192.168.66.53` |
| VLAN | 10 |

## Installation Steps

Add each Windows installation step here as it is completed.

## Validation

Record the commands and results used to confirm Windows networking and DNS.
'@

    "05_dns_server.md" = @'
# 05 — Ubuntu BIND9 DNS Server

## Purpose

This dedicated server receives and records the lab DNS requests.

## Planned Server Settings

| Setting | Value |
|---|---|
| VMID | 901 |
| Name | `DNS-SRV-01` |
| Operating system | Ubuntu Server 24.04 LTS |
| DNS software | BIND9 |
| IP address | `192.168.66.53` |
| Gateway | `192.168.66.1` |
| VLAN | 66 |

## Installation

Add the Ubuntu and BIND9 installation steps here as they are completed.

## DNS Logging

Record how BIND9 query logging is enabled and where the log file is stored.

## Validation

Record the DNS test commands and results here.
'@

    "06_sysmon_telemetry.md" = @'
# 06 — Sysmon Telemetry

## Purpose

Sysmon records detailed Windows activity. These events help connect a DNS request to the program that created it.

## Installation

Record the Sysmon download, offline transfer, installation, and configuration steps here.

## Events to Collect

- Process creation events.
- Network connection events.
- DNS query events.

## Validation

Record how the Sysmon events were confirmed in Windows Event Viewer and Splunk.
'@

    "07_splunk_server.md" = @'
# 07 — Splunk Server

## Purpose

Splunk is used to search logs and practice DNS detection engineering with SPL.

## Planned Server Settings

| Setting | Value |
|---|---|
| VMID | 902 |
| Name | `SPLUNK-SRV-01` |
| Operating system | Ubuntu Server 24.04 LTS |
| IP address | `172.16.99.40` |
| Gateway | `172.16.99.1` |
| VLAN | 99 |
| Memory | 8 GB |
| Disk | 100 GB |

## Data Sources

- Windows Sysmon events.
- Windows DNS-client events.
- Ubuntu BIND9 query logs.

## Installation

Record the offline Splunk installation steps here.

## Validation

Record how Splunk Web, log ingestion, and searches were tested.
'@

    "08_dns_baseline.md" = @'
# 08 — Normal DNS Baseline

## Purpose

A baseline shows what normal DNS traffic looks like before suspicious traffic is generated.

## Normal Tests

Record each normal DNS test, the time it was run, and the expected result.

## What to Measure

- Number of DNS requests.
- Length of each requested name.
- Number of subdomains.
- DNS response type.
- Source and destination IP addresses.

## Results

Add a short summary of the normal behavior here.
'@

    "09_dns_exfiltration_simulation.md" = @'
# 09 — Safe DNS Exfiltration Simulation

## Purpose

This step creates unusual DNS requests using fake test data so they can be detected.

## Safety Rules

- Use only synthetic text created for this lab.
- Send requests only to `192.168.66.53`.
- Keep the lab disconnected from the Internet.
- Stop the test if traffic leaves the expected networks.

## Test Procedure

Record the exact simulation command, start time, stop time, and expected result here.

## Validation

Record where the traffic appeared in BIND9, Security Onion, and Splunk.
'@

    "10_security_onion_validation.md" = @'
# 10 — Security Onion Validation

## Purpose

This file proves that Security Onion received and analyzed the copied DNS traffic.

## Checks

- Security Onion services are running.
- The monitoring interface is receiving packets.
- Zeek records DNS activity.
- Suricata examines the traffic.
- Relevant events appear in the Security Onion interface.

## Evidence

Record commands, search results, timestamps, and screenshot names here.
'@

    "11_detection_engineering.md" = @'
# 11 — Detection Engineering

## Purpose

Detection engineering means creating and testing logic that finds suspicious behavior.

## DNS Behaviors to Detect

- Very long DNS names.
- Many subdomains in one request.
- Random-looking or encoded text.
- A large number of requests in a short time.
- Requests to an unusual DNS server.

## Splunk Searches

Add each SPL search here with a plain-language explanation of what it detects.

## Security Onion Detections

Add each Suricata rule or Security Onion hunt here with a plain-language explanation.

## Testing

Record whether each detection fired during normal traffic and simulated suspicious traffic.
'@

    "12_results.md" = @'
# 12 — Lab Results

## Purpose

This file summarizes what happened during the lab.

## Questions to Answer

1. Did the DNS server receive the requests?
2. Did Security Onion observe the traffic?
3. Did Splunk receive the logs?
4. Which detections worked?
5. Were there any false positives?
6. What should be improved?

## Evidence

List the important screenshots, logs, packet captures, and timestamps here.

## Final Summary

Write a short beginner-friendly explanation of the final result here.
'@

    "13_rollback.md" = @'
# 13 — Rollback

## Purpose

Rollback returns the lab to its known-good state after testing.

## Important Rule

Use `BASELINE_CONFIGURATION/` as the source of truth. Do not modify the baseline files.

## Rollback Checklist

1. Stop the DNS-exfiltration test.
2. Export any evidence that must be kept.
3. Stop the Windows, DNS, and Splunk lab VMs.
4. Remove temporary Juniper firewall rules.
5. Restore the original Proxmox network configuration if required.
6. Restore the original Cisco configuration if it was changed.
7. Start Security Onion.
8. Confirm management connectivity.
9. Confirm the SPAN monitoring path.
10. Record the rollback test result.

## Proxmox Network Backup

The pre-lab network configuration was saved as:

```text
/root/interfaces.before-dns-lab-2026-09-02
```

Add the exact restoration commands only after they have been safely tested.
'@

    "configs\README.md" = @'
# Configuration Files

Store copies of DNS-lab-specific configurations here.

Examples include:

- Proxmox network changes.
- Cisco SPAN configuration.
- Juniper firewall policies.
- BIND9 configuration.
- Sysmon configuration.
- Splunk inputs and searches.
- Security Onion detection rules.

Do not store passwords, private keys, tokens, or other secrets in this folder.
'@

    "evidence\README.md" = @'
# Lab Evidence

Store small, useful proof of the lab results here.

Examples include:

- Screenshots.
- Short log samples.
- Detection results.
- Sanitized search output.

Do not commit sensitive information or very large packet captures to Git.
'@

    "scripts\README.md" = @'
# Lab Scripts

Store only scripts created for this isolated DNS lab here.

Every script should explain:

1. What it does.
2. Where it should be run.
3. What safe test data it uses.
4. How to stop or undo it.

Do not include passwords, tokens, real documents, or production data.
'@
}

foreach ($File in $Files.GetEnumerator()) {
    New-BeginnerLabFile -RelativePath $File.Key -Content $File.Value
}

Write-Host ""
Write-Host "DNS lab structure is ready:" -ForegroundColor Cyan
Write-Host $LabRoot -ForegroundColor Cyan
Write-Host ""
Write-Host "Review the files, then run:" -ForegroundColor Cyan
Write-Host "  git status" -ForegroundColor White
Write-Host "  git add 01_dns_exfiltration_lab" -ForegroundColor White
Write-Host '  git commit -m "docs: create beginner DNS exfiltration lab structure"' -ForegroundColor White
Write-Host "  git push origin main" -ForegroundColor White
