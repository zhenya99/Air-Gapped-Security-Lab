\# 06. Sysmon Telemetry



\## Purpose



Sysmon records detailed Windows endpoint activity.



In this lab, Sysmon helps associate DNS and network activity with the Windows processes that generated it.



The three primary event types collected are:



| Event ID | Event |

|---:|---|

| `1` | Process Creation |

| `3` | Network Connection |

| `22` | DNS Query |



\---



\## Telemetry Flow



```text

Windows 11 Victim

172.16.10.50

&#x20;     |

&#x20;     v

Sysmon

&#x20;     |

&#x20;     v

Microsoft-Windows-Sysmon/Operational

&#x20;     |

&#x20;     +-- Event ID 1  - Process Creation

&#x20;     +-- Event ID 3  - Network Connection

&#x20;     +-- Event ID 22 - DNS Query

&#x20;     |

&#x20;     v

Future: Splunk Universal Forwarder

```



Splunk forwarding is intentionally handled in the next phase.



\---



\## 1. Verify Sysmon Was Not Already Installed



Before installation, the victim was checked with:



```powershell

Get-Service Sysmon\* -ErrorAction SilentlyContinue

```



```powershell

Get-Process Sysmon\* -ErrorAction SilentlyContinue

```



```powershell

Get-WinEvent -ListLog "Microsoft-Windows-Sysmon/Operational" -ErrorAction SilentlyContinue

```



All checks returned empty.



\### Result



```text

\[PASS] Existing Sysmon installation ruled out

```



\---



\## 2. Offline Sysmon Transfer



Sysmon was downloaded on the administrative workstation rather than directly from the isolated victim.



The files were placed under:



```text

C:\\LabTools\\Sysmon

```



A PowerShell session to the victim was created:



```powershell

$session = New-PSSession -ComputerName 172.16.10.50 -Credential victim

```



The destination directory was created:



```powershell

Invoke-Command -Session $session -ScriptBlock {

&#x20;   New-Item -ItemType Directory -Path C:\\LabTools\\Sysmon -Force

}

```



The Sysmon files were copied into the victim:



```powershell

Copy-Item C:\\LabTools\\Sysmon\\\* `

\-Destination C:\\LabTools\\Sysmon `

\-ToSession $session `

\-Recurse

```



The transferred files were verified on the victim.



\---



\## 3. Sysmon Configuration



A minimal configuration was created to collect the telemetry needed by this lab:



```xml

<Sysmon schemaversion="4.90">

&#x20; <EventFiltering>

&#x20;   <ProcessCreate onmatch="exclude" />

&#x20;   <NetworkConnect onmatch="exclude" />

&#x20;   <DnsQuery onmatch="exclude" />

&#x20; </EventFiltering>

</Sysmon>

```



The configuration was saved as:



```text

C:\\LabTools\\Sysmon\\sysmonconfig.xml

```



\---



\## 4. Install Sysmon



From an elevated PowerShell session on the victim:



```powershell

cd C:\\LabTools\\Sysmon

```



Install Sysmon:



```powershell

.\\Sysmon64.exe -accepteula -i .\\sysmonconfig.xml

```



Verify the service:



```powershell

Get-Service Sysmon\*

```



Verify the event log:



```powershell

Get-WinEvent -ListLog "Microsoft-Windows-Sysmon/Operational" |

Select-Object LogName,RecordCount,IsEnabled

```



\### Result



```text

\[PASS] Sysmon installed

\[PASS] Sysmon service operational

\[PASS] Sysmon Operational log enabled

```



\---



\# 5. Validate Event ID 1 — Process Creation



A controlled process was generated:



```powershell

Start-Process cmd.exe -ArgumentList '/c','echo SYSMON\_EVENT1\_TEST > C:\\LabTools\\Sysmon\\event1\_test.txt' -Wait

```



Confirm the command ran:



```powershell

Get-Content C:\\LabTools\\Sysmon\\event1\_test.txt

```



Search for recent Event ID 1 records:



```powershell

Get-WinEvent -FilterHashtable @{

&#x20;   LogName='Microsoft-Windows-Sysmon/Operational'

&#x20;   Id=1

&#x20;   StartTime=(Get-Date).AddMinutes(-5)

} | Where-Object {$\_.Message -match 'SYSMON\_EVENT1\_TEST|cmd.exe'} |

Select-Object TimeCreated,Id,Message

```



Validated result:



```text

Event ID 1

Process Create

```



\### Result



```text

\[PASS] Event ID 1 — Process Creation

```



\---



\# 6. Validate Event ID 3 — Network Connection



Generate a controlled network connection to the lab DNS server:



```powershell

Test-NetConnection 192.168.66.53 -Port 53

```



Search Sysmon:



```powershell

Get-WinEvent -FilterHashtable @{

&#x20;   LogName='Microsoft-Windows-Sysmon/Operational'

&#x20;   Id=3

&#x20;   StartTime=(Get-Date).AddMinutes(-5)

} | Where-Object {$\_.Message -match '192\\.168\\.66\\.53'} |

Select-Object TimeCreated,Id,Message

```



The event identified the connection to:



```text

Destination IP:   192.168.66.53

Destination Port: 53

```



\### Result



```text

\[PASS] Event ID 3 — Network Connection

```



\---



\# 7. Validate Event ID 22 — DNS Query



Generate a unique DNS query:



```powershell

nslookup sysmon22test.exfil.test 192.168.66.53

```



Search for Event ID 22:



```powershell

Get-WinEvent -FilterHashtable @{

&#x20;   LogName='Microsoft-Windows-Sysmon/Operational'

&#x20;   Id=22

&#x20;   StartTime=(Get-Date).AddMinutes(-5)

} | Where-Object {$\_.Message -match 'sysmon22test\\.exfil\\.test'} |

Select-Object TimeCreated,Id,Message

```



The query was successfully recorded by Sysmon.



\### Result



```text

\[PASS] Event ID 22 — DNS Query

```



\---



\# 8. Validate Events in Event Viewer



On the Windows victim, open:



```text

eventvwr.msc

```



Navigate to:



```text

Applications and Services Logs

&#x20;   > Microsoft

&#x20;       > Windows

&#x20;           > Sysmon

&#x20;               > Operational

```



Select:



```text

Filter Current Log

```



Enter:



```text

1,3,22

```



The generated test events were visible.



\### Verified Events



```text

Event ID 1  - Process Creation

Event ID 3  - Network Connection

Event ID 22 - DNS Query

```



\### Result



```text

\[PASS] Sysmon telemetry visible in Windows Event Viewer

```



\---



\# 9. Why This Matters



Sysmon provides endpoint context that network DNS logs alone cannot provide.



For example:



```text

Windows Process

&#x20;     |

&#x20;     v

DNS Query

sysmon22test.exfil.test

&#x20;     |

&#x20;     v

DNS Server

192.168.66.53

```



This allows later analysis to answer questions such as:



```text

Which host generated the DNS request?

Which process generated it?

Which user was running the process?

Which destination was contacted?

What DNS name was queried?

```



\---





\# Confirmed Sysmon State



```text

Host:          Windows 11 Victim

IP:            172.16.10.50



Sysmon:        Installed and Operational



Collected:

Event ID 1     Process Creation

Event ID 3     Network Connection

Event ID 22    DNS Query



Event Log:

Microsoft-Windows-Sysmon/Operational



Validated DNS Test:

sysmon22test.exfil.test

```



\---



\# Conclusion



Sysmon endpoint telemetry is successfully operating on the Windows 11 victim.



Process creation, network connection, and DNS query activity have all been generated and confirmed in the Sysmon Operational event log and Windows Event Viewer.



