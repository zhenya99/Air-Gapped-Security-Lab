# 04 — Detections and Telemetry

This section provides visual proof that the Security Onion detection pipeline is working.

---

## 1. Custom Suricata Rule

![Custom Suricata Rule](/images/Rules/01_suricata_custom_rule_sid_1000001.png)

**Description:**  
Custom Suricata rule **SID 1000001** detects ICMP traffic from Kali `192.168.66.50` to Proxmox `172.16.99.20`.

```text
LAB TEST - Kali ICMP to Proxmox
```

---

## 2. Working Security Onion Alerts

![Working Security Onion Alerts](/images/Rules/02_security_onion_working_alerts.png)

**Description:**  
Security Onion SOC confirms that the custom rule is generating alerts.

The screenshot shows:

- `LAB TEST - Kali ICMP to Proxmox`
- Suricata
- SID `1000001`
- Successful alert count
- Built-in `GPL ICMP PING *NIX` detection

This confirms that Suricata is receiving, decoding, and alerting on the mirrored traffic.

---

