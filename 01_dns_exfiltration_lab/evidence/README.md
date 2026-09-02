\# Lab Evidence



\## Purpose



This folder stores small, safe examples that prove the DNS Exfiltration Detection Lab is working as intended.



Evidence helps a beginner answer questions such as:



\* Did the DNS server receive the query?

\* Which lab system sent it?

\* Was the query allowed or refused?

\* Did the firewall permit the required traffic?

\* Did Security Onion observe the same network activity?

\* Did a detection rule produce the expected result?



Evidence is different from configuration:



\* `configs/` explains how a system is configured.

\* `evidence/` shows what happened when that configuration was tested.



\---



\## Current Folder Structure



```text

evidence/

├── README.md

└── dns-server/

&#x20;   └── query-log-sample.txt

```



Additional folders will be added later for Windows, Security Onion, detection rules, screenshots, and test results.



\---



\## DNS Server Evidence



The \[`dns-server/`](dns-server/) folder contains evidence collected from the Ubuntu BIND9 server at `192.168.66.53`.



\### Query Log Sample



\[`query-log-sample.txt`](dns-server/query-log-sample.txt) contains a small sample from:



```text

/var/log/named/query.log

```



The sample was collected with:



```bash

sudo tail -n 50 /var/log/named/query.log | tee /home/dnsadmin/lab-config-export/query-log-sample.txt

```



\### Command Explanation



\* `sudo` provides permission to read the protected log.

\* `tail` reads the newest part of a file.

\* `-n 50` limits the sample to the newest 50 lines.

\* The pipe symbol `|` sends the output to another command.

\* `tee` displays the output and saves an identical copy.



Only a short sample was saved so the repository does not contain an unnecessary growing log file.



\---



\## What the Current Evidence Shows



The current sample contains five controlled lab events.



| Query                      | Source          | Purpose                                            | Result                     |

| -------------------------- | --------------- | -------------------------------------------------- | -------------------------- |

| `logging-test.exfil.test`  | `192.168.66.53` | Verify local wildcard resolution and query logging | Logged                     |

| `normal.exfil.test`        | `172.16.99.10`  | Verify remote DNS resolution from the analyst host | Answered and logged        |

| `example.com`              | `192.168.66.53` | Verify recursive public resolution is disabled     | Refused and logged         |

| `exfil.test` with `AXFR`   | `192.168.66.53` | Verify complete zone transfers are blocked         | Transfer failed and logged |

| `firewall-test.exfil.test` | `172.16.99.10`  | Verify remote DNS still works after enabling UFW   | Answered and logged        |



`example.com` is a reserved documentation domain. It was used only to confirm that BIND refuses domains outside the private lab zone.



\---



\## How to Read a BIND Query Entry



A query entry may look similar to:



```text

02-Sep-2026 17:51:42.549 queries: info: client ... 172.16.99.10#59460 (normal.exfil.test): query: normal.exfil.test IN A ... (192.168.66.53)

```



The important fields are:



| Field                      | Meaning                                      |

| -------------------------- | -------------------------------------------- |

| `02-Sep-2026 17:51:42.549` | Date and time when BIND received the request |

| `queries`                  | BIND logging category                        |

| `info`                     | Event severity                               |

| `172.16.99.10`             | IP address of the requesting lab system      |

| `59460`                    | Temporary client source port                 |

| `normal.exfil.test`        | DNS name requested by the client             |

| `IN`                       | Internet DNS record class                    |

| `A`                        | Request for an IPv4 address                  |

| `192.168.66.53`            | BIND server that handled the request         |



The changing hexadecimal value after `client` is an internal BIND request reference. It is not a password or secret key.



\---



\## Evidence Safety Rules



Before committing evidence to Git:



1\. Use only fake lab data.

2\. Review every line for passwords, tokens, private keys, and personal information.

3\. Keep samples small.

4\. Do not commit the complete live DNS log.

5\. Do not commit large packet captures directly.

6\. Do not commit authentication logs containing real usernames from unrelated systems.

7\. Store evidence only under `01\_dns\_exfiltration\_lab/evidence/`.

8\. Confirm that `BASELINE\_CONFIGURATION/` remains unchanged.



\---



\## Evidence That Must Not Be Committed



Do not store:



\* Passwords

\* Private keys

\* API tokens

\* Authentication cookies

\* BIND `rndc.key` contents

\* Real customer or organizational DNS names

\* Real exfiltrated information

\* Large unsanitized packet captures

\* Evidence unrelated to this lab



\---



\## Future Evidence



As the lab progresses, this folder may include:



\* Windows DNS-query screenshots

\* Sysmon DNS telemetry

\* Security Onion DNS events

\* Suricata alerts

\* Zeek DNS records

\* Detection-rule test results

\* Sanitized PCAP summaries

\* Before-and-after detection comparisons

\* Rollback validation results



Each evidence file should be linked from the related documentation page and include a simple explanation of what it proves.



Detailed DNS-server procedures are available in \[`../05\_dns\_server.md`](../05\_dns\_server.md).



