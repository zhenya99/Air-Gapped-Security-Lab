# 04 — Detections and Telemetry

This folder documents the **working Security Onion 3.2.x detection pipeline** for the air-gapped lab.

The final validated flow is:

```text
Kali 192.168.66.50
        │
        │ ICMP
        ▼
Juniper SRX
ALLOW-KALI-PING-PROXMOX
        │
        ▼
Cisco Gi1/0/27
        │
        ├──── SPAN BOTH ────► Gi1/0/28
        │                         │
        ▼                         ▼
Proxmox 172.16.99.20            nic1
                              MTU 9000
                                  │
                                vmbr1
                              MTU 9000
                                  │
                              VM 900 net1
                              MTU 9000
                                  │
                                ens19
                                  │
                                bond0
                                  │
                              Suricata
                                  │
                              SID 1000001
                                  │
                                  ▼
                         Security Onion SOC
                              ALERT ✅
```

---

## 1. Custom Suricata Detection Rule

The deterministic local rule used to validate the sensor is:

```suricata
alert icmp 192.168.66.50 any -> 172.16.99.20 any (msg:"LAB TEST - Kali ICMP to Proxmox"; sid:1000001; rev:1;)
```

Rule file:

[`rules/lab-kali-icmp-to-proxmox.rules`](rules/lab-kali-icmp-to-proxmox.rules)

### Detection Logic

| Field | Value |
|---|---|
| Protocol | ICMP |
| Source | `192.168.66.50` |
| Destination | `172.16.99.20` |
| Message | `LAB TEST - Kali ICMP to Proxmox` |
| SID | `1000001` |
| Revision | `1` |

This rule is intentionally narrow. It exists only to prove that mirrored Kali traffic reaches Suricata and produces a deterministic SOC alert.

### Working Rule Screenshot

![Suricata custom rule SID 1000001](images/01_suricata_custom_rule_sid_1000001.png)

---

## 2. Verify the Rule Reached the Running Suricata Container

On Security Onion:

```bash
sudo docker exec so-suricata \
grep -Rni 'sid:1000001' /etc/suricata/rules 2>/dev/null
```

Known-good result:

```text
/etc/suricata/rules/all-rulesets.rules:51514:
alert icmp 192.168.66.50 any -> 172.16.99.20 any (msg:"LAB TEST - Kali ICMP to Proxmox"; sid:1000001; rev:1;)
```

This proves the rule is not merely visible in SOC; it has been deployed into the active Suricata ruleset.

---

## 3. Generate the Test Traffic

From Kali:

```bash
ping 172.16.99.20
```

The Juniper firewall keeps the normal `ATTACKER -> MGMT` deny policy in place, but allows this one test flow through the narrow policy:

```text
ALLOW-KALI-PING-PROXMOX
192.168.66.50/32
        ↓
172.16.99.20/32
Application: junos-ping
Action: permit
```

The permit rule must be ordered before:

```text
BLOCK-KALI
```

---

## 4. Verify the SPAN Telemetry Path

The Cisco SPAN session uses:

```text
Source:      Gi1/0/27
Direction:   BOTH
Destination: Gi1/0/28
Encapsulation: Replicate
```

On Proxmox, validate the mirrored feed hop by hop:

```bash
tcpdump -eni nic1 -c 10
tcpdump -eni vmbr1 -c 10
tcpdump -eni tap900i1 -c 10
```

The working capture path is:

```text
Cisco Gi1/0/28
      │
      ▼
nic1
MTU 9000
      │
      ▼
vmbr1
MTU 9000
      │
      ▼
tap900i1
MTU 9000
      │
      ▼
Security Onion ens19
```

### Working Proxmox SPAN Path Screenshot

![Proxmox SPAN path validation](images/03_proxmox_span_path_validation.png)

---

## 5. Verify Security Onion Monitoring Interfaces

Inside Security Onion:

```bash
ip -br addr
ip -br link show ens19
ip -br link show bond0
ip link show master bond0
```

Expected logical state:

```text
ens18   UP   172.16.99.30/24
ens19   UP   no IPv4 address
bond0   UP
```

The monitoring path is:

```text
ens19
  │
  ▼
bond0
  │
  ├── Suricata
  └── Zeek
```

The capture path uses **MTU 9000**.

Verify traffic on both interfaces:

```bash
sudo tcpdump -eni ens19 icmp
sudo tcpdump -eni bond0 icmp
```

---

## 6. Verify Suricata Is Capturing From `bond0`

The running Suricata configuration was verified with:

```bash
sudo docker exec so-suricata sh -c \
"grep -A20 '^af-packet:' /etc/suricata/suricata.yaml"
```

Expected:

```yaml
af-packet:
- interface: bond0
```

This distinction was critical during troubleshooting.

At one point:

```text
tcpdump on ens19              = traffic visible
Suricata capture counters     = 0
```

The root cause was that `ens19` was not successfully participating in `bond0` while Suricata was listening on `bond0`.

The final working capture path uses:

```text
Proxmox nic1        MTU 9000
Proxmox vmbr1       MTU 9000
VM 900 net1         MTU 9000
Security Onion ens19 MTU 9000
Security Onion bond0 MTU 9000
```

---

## 7. Verify Suricata Packet and Alert Counters

Run:

```bash
sudo grep -E 'capture.kernel_packets|decoder.pkts|detect.alert' \
/opt/so/log/suricata/stats.log | tail -15
```

Before the fix:

```text
capture.kernel_packets = 0
decoder.pkts           = 0
detect.alert           = 0
```

After the fix, non-zero counters were observed:

```text
capture.kernel_packets | Total | 1473
decoder.pkts           | Total | 1510
detect.alert           | Total | 28
```

Additional samples showed:

```text
capture.kernel_packets | Total | 3946
decoder.pkts           | Total | 4013
detect.alert           | Total | 57
```

This proves that Suricata is:

1. Receiving packets.
2. Decoding packets.
3. Matching detection rules.
4. Generating alerts.

---

## 8. Working SOC Detection

Security Onion SOC confirmed the custom rule fired successfully.

### Custom Detection

```text
Rule Name:     LAB TEST - Kali ICMP to Proxmox
Event Module:  suricata
Severity:      low
SID / UUID:    1000001
```

### Built-In Detection

The same test traffic also triggered:

```text
GPL ICMP PING *NIX
SID: 2100366
Module: suricata
Severity: low
```

### Working Alerts Screenshot

![Security Onion working Suricata alerts](images/02_security_onion_working_alerts.png)

The SOC screenshot proves the complete detection pipeline:

```text
Mirrored packet
      │
      ▼
Security Onion ens19
      │
      ▼
bond0
      │
      ▼
Suricata
      │
      ▼
SID 1000001 matched
      │
      ▼
Event pipeline
      │
      ▼
Security Onion SOC
      │
      ▼
ALERT ✅
```

---

## 9. Final Detection Validation Checklist

- [x] Kali can reach `172.16.99.20` through the narrow SRX test exception.
- [x] Cisco `Gi1/0/27` is the SPAN source in both directions.
- [x] Cisco `Gi1/0/28` is the SPAN destination.
- [x] SPAN traffic reaches Proxmox `nic1`.
- [x] SPAN traffic reaches `vmbr1`.
- [x] SPAN traffic reaches `tap900i1`.
- [x] SPAN traffic reaches Security Onion `ens19`.
- [x] `ens19` participates in the Security Onion monitoring path through `bond0`.
- [x] Suricata captures from `bond0`.
- [x] `capture.kernel_packets` is non-zero.
- [x] `decoder.pkts` is non-zero.
- [x] `detect.alert` is non-zero.
- [x] SID `1000001` is loaded in the active Suricata ruleset.
- [x] `LAB TEST - Kali ICMP to Proxmox` appears in SOC.
- [x] Built-in `GPL ICMP PING *NIX` detection also fires.

---

## 10. Folder Contents

```text
04_detections_and_telemetry/
│
├── README.md
│
├── rules/
│   └── lab-kali-icmp-to-proxmox.rules
│
└── images/
    ├── 01_suricata_custom_rule_sid_1000001.png
    ├── 02_security_onion_working_alerts.png
    └── 03_proxmox_span_path_validation.png
```
