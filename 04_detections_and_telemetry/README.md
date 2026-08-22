# 04 — Detections and Telemetry

This section provides visual proof that the Security Onion detection pipeline is working.

---

## 1. Custom Suricata Rule

![Custom Suricata Rule](images/01_suricata_custom_rule_sid_1000001.png)

**Description:**  
Custom Suricata rule **SID 1000001** detects ICMP traffic from Kali `192.168.66.50` to Proxmox `172.16.99.20`.

```text
LAB TEST - Kali ICMP to Proxmox
```

---

## 2. Working Security Onion Alerts

![Working Security Onion Alerts](images/02_security_onion_working_alerts.png)

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

## 3. Proxmox SPAN Traffic Validation

![Proxmox SPAN Validation](images/03_proxmox_span_path_validation.png)

**Description:**  
Packet captures confirm mirrored traffic successfully travels through the Proxmox monitoring path:

```text
Cisco Gi1/0/28
      ↓
nic1
      ↓
vmbr1
      ↓
tap900i1
      ↓
Security Onion ens19
      ↓
bond0
      ↓
Suricata
```

The capture path uses **MTU 9000**.

---

## Final Result

```text
Cisco SPAN
    ↓
Proxmox
    ↓
Security Onion
    ↓
Suricata
    ↓
SOC Alert ✅
```
