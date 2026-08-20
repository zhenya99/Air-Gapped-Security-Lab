## 4. Post-Install Network Configuration (CLI)

With the base OS installed and the VM successfully booted from the virtual hard disk, the next phase is to configure the **management network interface**. This configuration must be completed through the command-line interface (CLI) before transitioning to remote SSH management.

### 4.1 Initial Login and Interface Verification

#### 1. Log In

At the `localhost login:` prompt, authenticate using the administrative OS credentials created during the base OS installation.

> **Note:** Linux does not display characters on the screen while you type a password. This is expected behavior.

#### 2. Verify the Logical Network Interfaces

Before assigning the static IP address, verify how the operating system has mapped the virtual network adapters.

Run:

```bash
ip link
```

Compare the MAC addresses displayed in the output with the MAC addresses configured for the VM in Proxmox.

Identify the interfaces as follows:

* **Management Interface:** Locate the interface matching the management MAC address ending in `67:75`. In this lab, this interface is typically `ens18`.
* **Capture Interface:** Locate the interface matching the capture MAC address ending in `90:F1`. In this lab, this interface is typically `ens19`.

> **Important:** Do not assume the interface names are always `ens18` and `ens19`. Confirm the interface-to-MAC-address mapping using `ip link` before configuring the network.

The resulting interface mapping for this lab should be:

| Interface | MAC Address     | Purpose              |
| --------- | --------------- | -------------------- |
| `ens18`   | Ends in `67:75` | Management Interface |
| `ens19`   | Ends in `90:F1` | Capture Interface    |

---

### 4.2 Execute the Network Setup Wizard

With the management interface identified, launch the Security Onion network configuration utility:

```bash
sudo so-setup-network
```

Navigate through the wizard using the **arrow keys**, **Tab**, and **Enter**.

Apply the following configuration:

#### Initial Action

Select:

```text
Configure Network
```

> **Important:** Do **not** select the main **Install** option at this stage. The objective is to configure the management network first so that the remaining Security Onion installation can be performed remotely through SSH.

#### Hostname

Enter a short local hostname for the Security Onion VM.

Example:

```text
securityonion
```

#### Management Interface

Select the interface identified during **Step 4.1**.

For this lab:

```text
ens18
```

The wizard displays the MAC addresses next to the interface names. Use the MAC address to confirm that you are selecting the correct management interface.

---

### Network Configuration

Configure the management interface with the following values:

| Setting             | Required Value  | Description                                                                           |
| ------------------- | --------------- | ------------------------------------------------------------------------------------- |
| **Addressing Type** | `Static`        | Provides a permanent address for reliable sensor management and web dashboard access. |
| **IP Address**      | `172.16.99.30`  | Designated management IP address for the Security Onion VM.                           |
| **Subnet Mask**     | `255.255.255.0` | `/24` subnet used by the lab management network.                                      |
| **Gateway**         | `172.16.99.1`   | Default gateway for VLAN 99 traffic.                                                  |
| **DNS Server**      | `8.8.8.8`       | External DNS resolver used for network name resolution during installation.           |
| **Search Domain**   | `lab.home`      | Local DNS search domain used by the lab environment.                                  |

> **Lab Network:** The Security Onion management interface is configured for **VLAN 99** with the static address `172.16.99.30/24`.

Review all values carefully before applying the configuration.

---

### 4.3 Apply the Configuration and Reboot

After the network settings have been entered, the wizard should display a message similar to:

```text
Successfully set up networking
```

Select:

```text
<Ok>
```

to exit the wizard.

To ensure the new network configuration is fully initialized by the operating system, reboot the VM from the command line:

```bash
sudo reboot
```

The VM will shut down and restart.

After the reboot, log back into the Security Onion CLI using the administrative OS credentials.

---

### 4.4 Verify the Management Network

After logging back in, verify that the management interface has received the expected static address:

```bash
ip addr show ens18
```

You can also verify the routing configuration:

```bash
ip route
```

Confirm that the expected management address is present:

```text
172.16.99.30/24
```

Verify connectivity to the management gateway:

```bash
ping -c 4 172.16.99.1
```

Then verify external network connectivity:

```bash
ping -c 4 8.8.8.8
```

Finally, verify DNS resolution:

```bash
ping -c 4 google.com
```

> **Expected Result:** The management interface should be configured with `172.16.99.30/24`, the default route should point to `172.16.99.1`, and the VM should be able to reach the configured DNS server and external network.

Once these checks succeed, the Security Onion VM is ready for the next phase: **remote SSH management and the main Security Onion installation**.
