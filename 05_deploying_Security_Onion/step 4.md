## 4. Post-Install Network Configuration (CLI)

With the base OS installed and the VM booted from the virtual disk, configure the **management interface** before transitioning to SSH-based administration.

### 4.1 Initial Login and Interface Verification

Log in at the `localhost login:` prompt using the administrative OS credentials created during installation.

> **Note:** Linux does not display characters while entering a password.

Verify the VM's network interfaces:

```bash
ip link
```

Compare the displayed MAC addresses with the Proxmox VM configuration.

* **Management:** MAC ending in `67:75` → typically `ens18`
* **Capture:** MAC ending in `90:F1` → typically `ens19`

> **Important:** Confirm the MAC-to-interface mapping with `ip link` rather than assuming the interface names.

---

### 4.2 Configure the Management Network

Launch the Security Onion network configuration utility:

```bash
sudo so-setup-network
```

Select **Configure Network** and enter:

| Setting                  | Value           |
| ------------------------ | --------------- |
| **Hostname**             | `securityonion` |
| **Management Interface** | `ens18`         |
| **Addressing**           | `Static`        |
| **IP Address**           | `172.16.99.30`  |
| **Subnet Mask**          | `255.255.255.0` |
| **Gateway**              | `172.16.99.1`   |
| **DNS Server**           | `8.8.8.8`       |
| **Search Domain**        | `lab.home`      |

> **Lab Network:** The management interface uses `172.16.99.30/24` on VLAN 99.

Apply the configuration and select **`<Ok>`** when the wizard reports:

```text
Successfully set up networking
```

---

### 4.3 Reboot and Verify

Reboot the VM:

```bash
sudo reboot
```

After logging back in, verify the interface:

```bash
ip addr show ens18
```

Verify routing:

```bash
ip route
```

Test connectivity to the gateway:

```bash
ping -c 4 172.16.99.1
```

Test external connectivity:

```bash
ping -c 4 8.8.8.8
```

Test DNS resolution:

```bash
ping -c 4 google.com
```

> **Expected Result:** `ens18` should have `172.16.99.30/24`, the default route should use `172.16.99.1`, and external/DNS connectivity should succeed.

---

### 4.4 Verify Workstation Reachability

From the Windows management workstation, test connectivity to Security Onion:

```cmd
ping 172.16.99.30
```

If the VM is reachable locally but the workstation receives **Destination host unreachable**, check the Proxmox network configuration.

#### Proxmox VLAN Troubleshooting

If `net0` was created with `tag=99`, Proxmox sends the VM's traffic with an 802.1Q VLAN tag. If the workstation is connected to an **untagged/native network**, this can prevent communication.

In the Proxmox Web GUI:

1. Select the **Security Onion VM**.
2. Open **Hardware**.
3. Select **Network Device (net0)**.
4. Clear the **VLAN Tag** field.
5. If required for initial troubleshooting, temporarily disable **Firewall**.
6. Click **OK**.

Test again from Windows:

```cmd
ping 172.16.99.30
```

Once successful replies are received, the management path is verified and the VM is ready for **SSH access and the main Security Onion installation**.
