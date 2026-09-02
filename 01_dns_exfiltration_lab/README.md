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