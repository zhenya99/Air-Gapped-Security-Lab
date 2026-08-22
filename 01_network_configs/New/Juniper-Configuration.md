# Final Juniper SRX300 Configuration

This document reflects the **current known-good Juniper SRX300 routing, security-zone, and policy configuration** for the air-gapped Security Onion lab.

The final topology uses:

```text
ge-0/0/0       802.1Q trunk to Cisco Gi1/0/1
ge-0/0/0.10    VICTIMS gateway 172.16.10.1/24
ge-0/0/0.99    MGMT gateway    172.16.99.1/24

ge-0/0/5.0     ATTACKER gateway 192.168.66.1/24
                connected directly to the Netgear/Kali segment
```

Cisco `Gi1/0/2` is not part of the attacker path.

---

## 1. Physical and Logical Interfaces

Enter configuration mode:

```text
configure
```

Configure the Cisco-facing 802.1Q trunk:

```text
set interfaces ge-0/0/0 vlan-tagging

set interfaces ge-0/0/0 unit 10 vlan-id 10
set interfaces ge-0/0/0 unit 10 family inet address 172.16.10.1/24

set interfaces ge-0/0/0 unit 99 vlan-id 99
set interfaces ge-0/0/0 unit 99 family inet address 172.16.99.1/24
```

Configure the physical attacker-facing interface:

```text
set interfaces ge-0/0/5 unit 0 family inet address 192.168.66.1/24
```

Expected directly connected networks:

```text
172.16.10.0/24  -> ge-0/0/0.10
172.16.99.0/24  -> ge-0/0/0.99
192.168.66.0/24 -> ge-0/0/5.0
```

---

## 2. Security Zones and Host-Inbound Services

### ATTACKER

```text
set security zones security-zone ATTACKER interfaces ge-0/0/5.0
set security zones security-zone ATTACKER host-inbound-traffic system-services ping
```

### VICTIMS

```text
set security zones security-zone VICTIMS interfaces ge-0/0/0.10
set security zones security-zone VICTIMS host-inbound-traffic system-services ping
```

### MGMT

```text
set security zones security-zone MGMT interfaces ge-0/0/0.99
set security zones security-zone MGMT host-inbound-traffic system-services all
```

The observed working configuration does **not** require a separate:

```text
host-inbound-traffic protocols all
```

statement for the MGMT zone.

---

## 3. ATTACKER -> VICTIMS Policy

Permit laboratory attack traffic from Kali into the victim zone:

```text
set security policies from-zone ATTACKER to-zone VICTIMS policy ATTACK-TRAFFIC match source-address any
set security policies from-zone ATTACKER to-zone VICTIMS policy ATTACK-TRAFFIC match destination-address any
set security policies from-zone ATTACKER to-zone VICTIMS policy ATTACK-TRAFFIC match application any
set security policies from-zone ATTACKER to-zone VICTIMS policy ATTACK-TRAFFIC then permit
```

---

## 4. VICTIMS -> MGMT Log-Forwarding Policy

The current lab policy permits TCP traffic from the victim zone toward management:

```text
set security policies from-zone VICTIMS to-zone MGMT policy LOG-FORWARDING match source-address any
set security policies from-zone VICTIMS to-zone MGMT policy LOG-FORWARDING match destination-address any
set security policies from-zone VICTIMS to-zone MGMT policy LOG-FORWARDING match application junos-tcp-any
set security policies from-zone VICTIMS to-zone MGMT policy LOG-FORWARDING then permit
```

---

## 5. MGMT -> ATTACKER Policy

Allow the management/analyst side to initiate connections toward Kali:

```text
set security policies from-zone MGMT to-zone ATTACKER policy WIN-TO-KALI match source-address any
set security policies from-zone MGMT to-zone ATTACKER policy WIN-TO-KALI match destination-address any
set security policies from-zone MGMT to-zone ATTACKER policy WIN-TO-KALI match application any
set security policies from-zone MGMT to-zone ATTACKER policy WIN-TO-KALI then permit
```

---

## 6. ATTACKER -> MGMT Segmentation

The default lab policy intentionally prevents Kali from initiating arbitrary sessions into the management zone.

```text
set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI match source-address any
set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI match destination-address any
set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI match application any
set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI then deny
set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI then log session-init
```

This policy is retained.

---

## 7. Narrow Kali -> Proxmox ICMP Test Exception

For deterministic Security Onion testing, only Kali ICMP traffic to the Proxmox management address is permitted through the otherwise blocked `ATTACKER -> MGMT` direction.

### Address objects

```text
set security zones security-zone ATTACKER address-book address KALI-HOST 192.168.66.50/32
set security zones security-zone MGMT address-book address PROXMOX-HOST 172.16.99.20/32
```

### Permit only ICMP from Kali to Proxmox

```text
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX match source-address KALI-HOST
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX match destination-address PROXMOX-HOST
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX match application junos-ping
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX then permit
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX then log session-init
set security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX then log session-close
```

### Policy order

The narrow permit rule must be above `BLOCK-KALI`:

```text
insert security policies from-zone ATTACKER to-zone MGMT policy ALLOW-KALI-PING-PROXMOX before policy BLOCK-KALI
```

The resulting order is:

```text
ATTACKER -> MGMT

1. ALLOW-KALI-PING-PROXMOX
   source:      192.168.66.50/32
   destination: 172.16.99.20/32
   application: junos-ping
   action:      permit

2. BLOCK-KALI
   source:      any
   destination: any
   application: any
   action:      deny + log
```

---

## 8. Validate and Commit

Before committing:

```text
show | compare
commit check
```

Expected:

```text
configuration check succeeds
```

Commit:

```text
commit
```

Exit:

```text
exit
```

---

## 9. Verification Commands

### Interfaces

```text
show interfaces terse
```

Expected relevant state:

```text
ge-0/0/0       up up
ge-0/0/0.10    up up inet 172.16.10.1/24
ge-0/0/0.99    up up inet 172.16.99.1/24
ge-0/0/5       up up
ge-0/0/5.0     up up inet 192.168.66.1/24
```

### Routes

```text
show route 192.168.66.0/24
show route 172.16.10.0/24
show route 172.16.99.0/24
```

### ARP

```text
show arp no-resolve
```

Known-good lab observations include:

```text
172.16.99.20  -> fc:9d:05:05:87:6c  ge-0/0/0.99
172.16.99.30  -> bc:24:11:65:9f:86  ge-0/0/0.99
192.168.66.50 -> 22:12:4c:35:01:bb  ge-0/0/5.0
```

### Security policy order

```text
show security policies from-zone ATTACKER to-zone MGMT
```

Verify that:

```text
ALLOW-KALI-PING-PROXMOX
```

appears before:

```text
BLOCK-KALI
```

### Final connectivity test

From Kali:

```bash
ping -c 4 172.16.99.20
```

This traffic is intentionally permitted for IDS validation and is mirrored by the Cisco SPAN session when it crosses `Gi1/0/27`.
