Here is the cleaned-up, professionally formatted Markdown code for your GitHub repository.

I fixed the typos (like "IOS" to "ISO" and "Lob back in" to "Log back in"), removed the duplicated paragraph under the OS installation step, fixed the numbering sequence, and dropped your terminal commands into proper `bash` code blocks so they will format beautifully on the web.

You can copy and paste this entire block directly into your GitHub file:

```markdown
# Deploying Security Onion v3.2.0

Deploying Security Onion 3.2.x requires precise interface alignment to ensure the mirrored VLAN 10 traffic successfully reaches the Suricata and Zeek sensors.

---

## 1. VM Provisioning in Proxmox

Before booting the ISO, configure the virtual hardware to match the network segmentation and storage layout. You can verify your host's capacity from the Proxmox shell:

```bash
ssh root@lab
lscpu
pvesh get /nodes/localhost/status
free -h
df -h
lsblk

```

*I am running an **i7-12700K**, which features 12 physical cores (8 Performance, 4 Efficient) and hyper-threading, meaning Proxmox actually has 20 logical threads to work with. The host also features **46GB of memory**, a **240GB internal SSD**, and a **1TB external SSD**.*

### The Security Onion 3.2.0 VM Blueprint

* **CPU:** 8 to 12 Cores. (Under the *Advanced* CPU settings in Proxmox, change the CPU type from `kvm64` to `host` so Suricata can fully utilize the i7-12700K's architecture for faster packet inspection).
* **Memory:** 24 GB to 28 GB (24576 MB - 28672 MB). Disable "Ballooning" so the memory is strictly locked to this VM, as 24 GB is the required minimum for a standalone deployment.
* **Storage:** 250GB to 500GB provisioned entirely on your 1TB external drive.
* **Network Device 1 (Management):** Bridge `vmbr0` | VLAN Tag: `99` | Firewall: **Checked**
* **Network Device 2 (Capture):** Bridge `vmbr1` | VLAN Tag: `<Leave Blank>` | Firewall: **Unchecked**

---

## 2. Base OS Installation

1. Boot the VM using the Security Onion 3.2.0 ISO and select **Install Security Onion** from the GRUB menu.
2. The CentOS/Oracle Linux installer will prompt you to create an administrative OS user and password. *(Note: Document these securely, as they are required to execute the setup wizard later).*
3. Allow the base OS installation to complete. Press **Enter** to reboot when prompted.

---

## 3. The `so-setup` Wizard

When the VM reboots, log in at the terminal prompt using the newly created OS credentials.

### Network Configuration:

1. Execute the setup script:
```bash
sudo so-setup-network

```


2. Select **Management Interface** (the first interface, e.g., `ens18` or `eth0`).
3. Set a **Static** IP configuration:
* **IP Address:** `172.16.99.30`
* **Subnet Mask:** `255.255.255.0`
* **Gateway:** `172.16.99.1`
* **DNS:** `8.8.8.8` (or local resolver)


4. Reboot the VM to apply the network bindings.

### Sensor Application Setup:

1. Log back in and execute:
```bash
sudo so-setup

```


2. Select **Install** -> **Standalone** (Installs SIEM, Suricata, and Zeek locally) -> **Standard**.
3. Select the **Monitor/Capture Interface** (the second interface, e.g., `ens19` or `eth1`).
4. Establish the Administrator email address and password for the web-based SOC dashboard (Kibana).
5. Allow the script to pull and deploy the Elastic Stack Docker containers.
6. Once complete, navigate to `https://172.16.99.30` from the Windows Station to access the interface.

```

```