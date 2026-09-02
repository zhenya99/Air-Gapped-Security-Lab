\# Configuration Files



\## Purpose



This folder stores safe copies of the configuration files created specifically for the DNS Exfiltration Detection Lab.



These files help us:



\* Understand how the lab is configured.

\* Reproduce the configuration later.

\* Review changes through Git.

\* Troubleshoot configuration mistakes.

\* Compare the running system with the documented version.



These are documentation copies. Editing a file in this Git folder does \*\*not\*\* automatically change the running server, firewall, switch, or hypervisor.



\---



\## Current Folder Structure



```text

configs/

├── README.md

├── bind9/

│   ├── db.exfil.test

│   ├── named.conf

│   ├── named.conf.local

│   ├── named.conf.logging

│   └── named.conf.options

└── ubuntu/

&#x20;   ├── bind9-package-versions.txt

&#x20;   └── ufw-status.txt

```



\---



\## BIND9 Configuration



The \[`bind9/`](bind9/) folder contains copies from the Ubuntu DNS server at `192.168.66.53`.



| File                                             | Purpose                                                                                        |

| ------------------------------------------------ | ---------------------------------------------------------------------------------------------- |

| \[`named.conf`](bind9/named.conf)                 | Main BIND configuration file that loads the other configuration files                          |

| \[`named.conf.options`](bind9/named.conf.options) | Controls listeners, approved client networks, recursion, DNSSEC validation, and zone transfers |

| \[`named.conf.local`](bind9/named.conf.local)     | Defines the private `exfil.test` zone                                                          |

| \[`named.conf.logging`](bind9/named.conf.logging) | Sends incoming DNS queries to `/var/log/named/query.log`                                       |

| \[`db.exfil.test`](bind9/db.exfil.test)           | Contains the SOA, NS, A, and wildcard records for the lab zone                                 |



\### Important Note



The files in this folder are safe copies of the active files under:



```text

/etc/bind/

```



The running DNS server will not use changes made to the Git copies unless an administrator deliberately copies them back to `/etc/bind`, validates them, and restarts BIND.



\---



\## Ubuntu Configuration



The \[`ubuntu/`](ubuntu/) folder contains operating-system configuration evidence from the DNS server.



| File                                                              | Purpose                                                        |

| ----------------------------------------------------------------- | -------------------------------------------------------------- |

| \[`bind9-package-versions.txt`](ubuntu/bind9-package-versions.txt) | Records the exact installed BIND and DNS-tool package versions |

| \[`ufw-status.txt`](ubuntu/ufw-status.txt)                         | Records the active Ubuntu firewall rules and default policies  |



The package inventory helps future users understand why their package filenames or versions may differ after Ubuntu updates.



The firewall record confirms:



\* SSH is allowed only from VLAN 99.

\* DNS is allowed from VLANs 10, 66, and 99.

\* Unmatched incoming traffic is denied.

\* Unmatched outgoing traffic is denied.

\* Outbound traffic is limited to approved internal lab networks.



\---



\## Files That Must Never Be Stored Here



Do not commit:



\* Passwords

\* Private keys

\* API tokens

\* SSH private keys

\* Authentication cookies

\* BIND control keys

\* Full packet captures containing sensitive traffic

\* Real personal or organizational data



The following BIND file is intentionally excluded:



```text

/etc/bind/rndc.key

```



`rndc.key` contains a secret used to control BIND. It must remain only on the DNS server.



The complete local backup directory is also excluded:



```text

/etc/bind.before-dns-lab-2026-09-02

```



That directory contains the private `rndc.key` file.



\---



\## Validation Before Committing



Before adding configuration files to Git:



1\. Confirm that the file belongs to this lab.

2\. Open the file and check for passwords or keys.

3\. Confirm that only fake test data is present.

4\. Confirm that the file is stored under `01\_dns\_exfiltration\_lab/`.

5\. Run `git status --short` and verify that `BASELINE\_CONFIGURATION/` is unchanged.



Detailed BIND9 installation and configuration instructions are available in \[`../05\_dns\_server.md`](../05\_dns\_server.md).



