# Hunting Network Ghosts: Troubleshooting Security Onion & Suricata on Proxmox

Building out a network security lab is one of the best ways to sharpen detection and incident response skills, but sometimes the lab itself becomes the primary incident. Recently, I ran into a complex packet capture issue in my virtualized Proxmox setup that completely blinded my Suricata sensor. 

Here is a deep dive into how I traced the packets hop-by-hop, uncovered a hidden firewall block, and ultimately fixed a silent MTU mismatch to get my SOC alerts firing again.

## The Lab Environment & The Setup
* **Platform:** Proxmox VE 9.2.x
* **Sensor:** Security Onion 3.2.x (Suricata Engine)

The goal was to route traffic from a Kali attacker machine through a Juniper SRX firewall and a Cisco switch, mirror that traffic via SPAN, and feed it into a virtualized Security Onion sensor for analysis. 

Here is what the intended end-to-end architecture looked like:

```text
                         ┌─────────────────────────┐
                         │       Kali Linux        │
                         │    192.168.66.50/24     │
                         └────────────┬────────────┘
                                      │
                                   Netgear
                                      │
                                      ▼
                         ┌─────────────────────────┐
                         │       Juniper SRX       │
                         │                         │
                         │ ge-0/0/5.0              │
                         │ 192.168.66.1/24         │
                         │ ATTACKER                 │
                         │                         │
                         │        Routing          │
                         │           │             │
                         │           ▼             │
                         │ ge-0/0/0.99             │
                         │ 172.16.99.1/24          │
                         │ MGMT                    │
                         └────────────┬────────────┘
                                      │
                                      ▼
                             Cisco Gi1/0/1
                                  Trunk
                                      │
                                      ▼
                               Cisco Switch
                                      │
                     ┌────────────────┴────────────────┐
                     │                                 │
                     ▼                                 ▼
                Gi1/0/27                          Gi1/0/28
              Proxmox Uplink                  SPAN Destination
              Native VLAN 99                        │
                     │                               │
                     ▼                               ▼
                   nic0                            nic1
                MTU 1500                         MTU 9000
                     │                               │
                     ▼                               ▼
                   vmbr0                           vmbr1
              172.16.99.20                      MTU 9000
                     │                               │
                     ▼                               ▼
                SO net0                         SO net1
              Management                       MTU 9000
                                                     │
                                                     ▼
                                                   ens19
                                                     │
                                                     ▼
                                                   bond0
                                                     │
                                                     ▼
                                                 Suricata
                                                     │
                                                     ▼
                                              SID 1000001
                                                     │
                                                     ▼
                                             Security Onion SOC
                                                     │
                                                     ▼
                                                ALERT ✅
```

### The Symptoms
Right off the bat, things weren't working:
1. Kali couldn't reach the Proxmox management address.
2. Even after confirming SPAN traffic was reaching the Security Onion monitoring NIC (`ens19`) via `tcpdump`, Suricata was processing **zero packets**.
3. My custom detection rule (`SID 1000001`) was correctly deployed but wasn't generating any events. 

---

## Investigation Phase 1: The Firewall Blockade
The first issue was getting my Kali machine (`192.168.66.50`) to talk to Proxmox (`172.16.99.20`). Initially, I was pinging the Kali gateway (`192.168.66.1`), but that didn't actually exercise the Cisco SPAN source port (`Gi1/0/27`). 

When I tried pinging Proxmox directly, it failed. Checking the Juniper SRX security policies revealed exactly why:

```text
From zone: ATTACKER
To zone: MGMT
Policy: BLOCK-KALI
Action: deny
```

The firewall was just doing its job. Rather than blowing away my segmentation policy, I created a narrow exception to allow only ICMP ping traffic from Kali to the Proxmox host, placing it *before* the `BLOCK-KALI` rule. 

After committing the change, Kali successfully reached Proxmox. Step one complete.

---

## Investigation Phase 2: The Silent Sensor
With traffic flowing, I traced the packets hop-by-hop using `tcpdump`. I confirmed the ICMP packets were crossing the Cisco SPAN, hitting the physical capture NIC (`nic1`), crossing the Linux capture bridge (`vmbr1`), and successfully arriving at the Security Onion sensor NIC (`ens19`).

Despite all this, Suricata's stats log was bleak:
```text
capture.kernel_packets | Total | 0
decoder.pkts           | Total | 0
detect.alert           | Total | 0
```

To figure out why, I checked the running Suricata container configuration:
```bash
sudo docker exec so-suricata sh -c "grep -A20 '^af-packet:' /etc/suricata/suricata.yaml"
```
The output revealed the culprit: **Suricata wasn't listening on `ens19`. It was listening on `bond0`.**

### The MTU Mismatch
Checking the link states, `ens19` was completely disconnected from the bond. A quick check with `nmcli` uncovered why:
* `ens19` was running at **MTU 1500**
* `bond0` expected **MTU 9000**

Earlier in my build, I had dropped the Proxmox sensor NIC down to MTU 1500 to clear a benign warning, totally forgetting that Security Onion's capture path strictly expects jumbo frames.

I went back and corrected the capture MTU across the entire chain:
```bash
# Setting Proxmox physical and bridge interfaces
ip link set nic1 mtu 9000
ip link set vmbr1 mtu 9000

# Setting the VM virtual NIC
qm set 900 --net1 virtio=BC:24:11:EE:90:F1,bridge=vmbr1,mtu=9000
```

---

## The Resolution & Results
As soon as the capture path was restored to MTU 9000, `ens19` immediately joined `bond0`.

I ran a quick check on the Suricata stats:
```text
capture.kernel_packets | Total | 1473
decoder.pkts           | Total | 1510
detect.alert           | Total | 28
```
We had packets! Suricata was finally ingesting the mirrored traffic. I hopped into the Security Onion SOC and was greeted by a beautiful sight: my custom detection rule (`LAB TEST - Kali ICMP to Proxmox`) was actively firing and generating alerts. 

## Key Takeaways
1. **`tcpdump` lies (sort of):** Just because you can see traffic hitting your sensor NIC doesn't mean your IDS engine is configured to look at that specific interface. Always verify where Suricata is actually listening.
2. **MTU matters:** Your entire passive capture path—from the physical SPAN NIC up through the virtual bridges and bonds—needs a consistent MTU (usually 9000). 
3. **Trace hop-by-hop:** Breaking down the network path and verifying traffic at every single physical and virtual interface is the only way to reliably troubleshoot complex hypervisor networking. 

The lab is back up, fully operational, and ready for the next round of testing.