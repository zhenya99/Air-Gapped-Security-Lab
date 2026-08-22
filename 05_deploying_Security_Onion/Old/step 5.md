# Step 5: Post-Installation Configuration and Sensor Bring-Up

After Security Onion Setup completes, configure access, confirm platform services, and bring the passive monitoring interface into operational use.

This step transitions the deployment from:

```text
Installed and configured
```

to:

```text
Operational network sensor
```

---

## 5.1 Log In to Security Onion

Log in at the Linux console if necessary using the operating-system account created during Step 3.

Security Onion administrative commands requiring elevated permissions should be run with:

```bash
sudo
```

---

# 5.2 Check Security Onion Service Status

Run:

```bash
sudo so-status
```

Security Onion uses `so-status` to report the state of enabled platform services.

Immediately after installation, some services may still be starting.

A newly installed node can temporarily display a fault condition while initialization completes.

For a machine-readable health result:

```bash
sudo so-status -q
echo $?
```

A healthy system should eventually return:

```text
0
```

The documented meanings include:

```text
0   System appears healthy
1   One or more subsystems are not running
2   System is still starting
99  Installation is in progress
100 Installation encountered errors
```

---

# 5.3 Access Security Onion Console

From the authorized management workstation, open a Chromium-based browser and navigate to:

```text
https://172.16.99.30
```

Sign in using the **SOC account** created during Setup.

Security Onion recommends Chromium-based browsers for SOC access.

---

# 5.4 If SOC Access Is Blocked

If the web interface cannot be reached because the workstation was not permitted through the Security Onion host firewall, add the analyst workstation.

From Security Onion:

```bash
sudo so-firewall includehost analyst <WORKSTATION-IP>
```

Example format:

```bash
sudo so-firewall includehost analyst 172.16.99.X
```

Use the actual administrative workstation address.

After SOC becomes available, firewall configuration should normally be managed through:

```text
SOC
  │
  ▼
Administration
  │
  ▼
Configuration
  │
  ▼
firewall
  │
  ▼
hostgroups
```

Do not manually modify `iptables` rules because Security Onion manages its host firewall configuration.

---

# 5.5 Open the Grid Page

In SOC, navigate to:

```text
Administration
     │
     ▼
Grid
```

or the corresponding **Grid** page in the current SOC navigation.

Expand the Standalone node.

Allow the platform enough time to finish initializing.

The desired state is:

```text
Connection Status:      OK
Process Status:         OK
Elasticsearch Status:   OK
```

along with healthy container/service status.

A new node may initially show:

```text
Fault
```

before eventually transitioning to:

```text
OK
```

as its services initialize.

---

# 5.6 Confirm the Interface Configuration

On the Security Onion host:

```bash
ip -br addr
```

The intended logical configuration is:

```text
ens18    UP    172.16.99.30/24
ens19    UP
```

The monitoring interface should not contain an IPv4 address.

The final design is:

```text
ens18
  │
  ├── 172.16.99.30/24
  ├── Management
  └── Default gateway


ens19
  │
  ├── No IP
  ├── No gateway
  └── Passive monitoring
```

Security Onion recommends a single IP-bearing management interface and dedicated IP-less sniffing interfaces for TAP/SPAN monitoring.

---

# 5.7 Confirm the Management Route

Display the routing table:

```bash
ip route
```

The default route should use the management network:

```text
default via 172.16.99.1
```

There should be no routing requirement associated with `ens19`.

The sensor interface observes traffic rather than routing it.

---

# 5.8 Confirm Mirrored Traffic Reaches Security Onion

Capture packets directly from the monitoring interface:

```bash
sudo tcpdump -eni ens19 -c 20
```

The SPAN feed should contain mirrored network traffic from VLAN 10.

Example traffic may include:

```text
ARP, Request who-has 172.16.10.15 tell 172.16.10.1
```

The complete monitoring path is:

```text
VLAN 10
   │
   ▼
Cisco Catalyst 2960-X
   │
   ▼
SPAN Session
   │
   ▼
Gi1/0/28
   │
   ▼
Proxmox nic1
   │
   ▼
vmbr1
   │
   ▼
VM net1
   │
   ▼
ens19
   │
   ├── Suricata
   └── Zeek
```

Do not configure VLAN 10 addressing on Security Onion merely because VLAN 10 packets appear on the capture interface.

They are mirrored packets.

---

# 5.9 Understand the Security Onion Monitoring Interface

Security Onion may place configured sniffing interfaces into its monitoring architecture, including `bond0`.

If another sniffing interface needs to be added **after Setup**, Security Onion provides:

```bash
sudo so-monitor-add
```

which adds monitor interfaces to the Security Onion monitoring configuration.

Do not run `so-monitor-add` unnecessarily if Setup already configured the intended monitoring interface.

---

# 5.10 Confirm Suricata Is Running

Check the Suricata container:

```bash
sudo docker ps --format 'table {{.Names}}\t{{.Status}}' | grep suricata
```

Then inspect recent logs:

```bash
sudo docker logs so-suricata --tail 50
```

The Suricata engine should start without persistent capture-interface errors.

---

# 5.11 Confirm Suricata Is Actually Processing Packets

A running container alone does not prove that packets are being decoded.

Inspect the Suricata statistics:

```bash
sudo docker exec so-suricata sh -c \
'grep -E "capture.afpacket.poll_data|capture.kernel_packets|decoder.pkts|decoder.bytes|detect.alert" \
/var/log/suricata/stats.log | tail -20'
```

Generate normal traffic on the monitored VLAN and run the command again.

The important counters should increase over time:

```text
capture.afpacket.poll_data   > 0
decoder.pkts                 > 0
decoder.bytes                > 0
```

The first success condition is:

```text
SPAN packets reach ens19
           +
Suricata decoder.pkts increases
```

An alert counter of zero does **not** automatically indicate a capture failure. It may simply mean that no current traffic matched an enabled detection rule.

---

# 5.12 Do Not Tune Suricata Before Establishing the Baseline

Do not immediately modify Suricata:

```text
AF_PACKET threads
rulesets
BPF filters
capture buffers
cluster settings
```

on a clean installation.

First determine whether the default Security Onion configuration successfully captures and decodes packets.

Only tune Suricata if the clean-install baseline demonstrates a specific problem.

Configuration changes should be made through Security Onion's supported configuration interface where available rather than by directly modifying generated files under:

```text
/opt/so/conf/
```

---

# 5.13 Confirm Zeek Operation

Check the Zeek container:

```bash
sudo docker ps --format 'table {{.Names}}\t{{.Status}}' | grep zeek
```

Inspect recent Zeek messages if troubleshooting is required:

```bash
sudo docker logs so-zeek --tail 50
```

Traffic observed on the monitoring interface should ultimately result in network metadata that can be searched through SOC.

---

# 5.14 Confirm Data Appears in SOC

From Security Onion Console, use:

```text
Hunt
Dashboards
Alerts
```

to inspect newly generated events.

Normal traffic should generate network metadata even if it does not produce an IDS alert.

The operational pipeline is:

```text
SPAN Traffic
     │
     ▼
Monitoring Interface
     │
     ├──────────────┐
     ▼              ▼
 Suricata          Zeek
     │              │
     └──────┬───────┘
            ▼
       Event Pipeline
            │
            ▼
      Elasticsearch
            │
            ▼
            SOC
```

---

# 5.15 Do Not Use Internet-Dependent Detection Tests

Because this system is configured in Airgap mode, avoid validation procedures that require reaching public Internet hosts.

For example, do not make the air-gapped deployment dependent on:

```bash
curl http://testmynids.org/uid/index.html
```

or other public test services.

Security Onion's `so-test` utility can also require Internet access to download replay resources, so it should not be assumed to work as an offline validation method.

For this lab, use:

* Existing VLAN 10 traffic
* Locally generated traffic
* Locally stored PCAPs
* Local Suricata test rules where necessary

to validate sensor operation.

---

# 5.16 Configure the Airgap NIDS Rules Profile

Security Onion uses an Airgap-specific NIDS configuration profile when the system is operating in Airgap mode.

Rule configuration should be managed through:

```text
SOC
  │
  ▼
Administration
  │
  ▼
Configuration
  │
  ▼
NIDS / Ruleset configuration
```

Do not manually download rules from the Internet from the Security Onion sensor.

When adding additional offline rulesets later, make sure each ruleset has a unique name to avoid rule synchronization problems.

---

# 5.17 Configure Time Synchronization

Accurate timestamps are critical for:

```text
Suricata alerts
Zeek metadata
Elasticsearch events
PCAP correlation
Incident timelines
```

For a completely air-gapped environment, configure Security Onion to use an internal NTP source available within the lab rather than a public Internet NTP service.

Security Onion exposes NTP-related configuration through the Administration configuration interface.

---

# 5.18 Review Data Retention

In a Standalone deployment, network telemetry, packet capture, and Elasticsearch data share finite local storage.

Review retention settings after installation.

Pay particular attention to:

```text
Elasticsearch data retention
Full packet capture retention
Suricata-related storage
Available free disk space
```

Security Onion specifically recommends reviewing data lifecycle and packet-capture retention so Elasticsearch does not reach storage watermarks and stop ingesting data.

---

# 5.19 Final Operational State

At the completion of Step 5, the deployment should have the following architecture:

```text
                    AIR-GAPPED SECURITY LAB

                           VLAN 10
                              │
                              ▼
                    Cisco Catalyst 2960-X
                              │
                       SPAN Destination
                          Gi1/0/28
                              │
                              ▼
                         Proxmox nic1
                              │
                              ▼
                            vmbr1
                              │
                              ▼
                         VM 900 net1
                              │
                              ▼
                            ens19
                         NO IP ADDRESS
                              │
                   ┌──────────┴──────────┐
                   │                     │
                   ▼                     ▼
               Suricata                 Zeek
                   │                     │
                   └──────────┬──────────┘
                              │
                              ▼
                       Security Onion
                         Event Pipeline
                              │
                              ▼
                        Elasticsearch
                              │
                              ▼
                             SOC


                    MANAGEMENT PLANE

                     Cisco Gi1/0/27
                              │
                              ▼
                         Proxmox nic0
                              │
                              ▼
                            vmbr0
                              │
                              ▼
                         VM 900 net0
                              │
                              ▼
                            ens18
                      172.16.99.30/24
                              │
                              ▼
                      Gateway 172.16.99.1
```

---

# Step 5 Completion Criteria

The Security Onion deployment is operational when:

* [ ] Security Onion Setup completed successfully.
* [ ] Deployment type is `STANDALONE`.
* [ ] Connectivity mode is `AIRGAP`.
* [ ] `ens18` provides management connectivity.
* [ ] `ens18` uses `172.16.99.30/24`.
* [ ] Default gateway is `172.16.99.1`.
* [ ] `ens19` is the passive monitoring interface.
* [ ] `ens19` has no IP address.
* [ ] Security Onion Console is accessible from the authorized management workstation.
* [ ] `sudo so-status` reports healthy services after initialization.
* [ ] Grid status transitions to healthy.
* [ ] Mirrored VLAN 10 traffic is visible on the monitoring interface.
* [ ] Suricata is processing packets.
* [ ] Zeek is running and generating network metadata.
* [ ] SOC receives network telemetry.
* [ ] Airgap rules/configuration is active.
* [ ] No Security Onion service depends on public Internet connectivity for normal operation.

---

# Deployment Phase Summary

```text
STEP 1
Environment Staging
        │
        ▼
STEP 2
Proxmox VM Provisioning
        │
        ▼
STEP 3
Security Onion OS Installation
        │
        ▼
STEP 4
Standalone + Airgap Configuration
        │
        ▼
STEP 5
Post-Installation Configuration
and Sensor Bring-Up
        │
        ▼
OPERATIONAL SECURITY ONION SENSOR
```
