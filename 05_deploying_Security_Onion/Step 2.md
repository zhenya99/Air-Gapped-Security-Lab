## Step 2: Provision the Virtual Machine via CLI

With the external SSD fully initialized, we can provision the VM directly from the Proxmox shell. This `qm create` command maps our defined hardware blueprint by allocating the `host` CPU architecture, 24 GB of dedicated RAM, the required network bridges, and 250 GB of storage on the newly created `ext-ssd` storage pool.

### 2.1 Create the VM

Run the following command to create the VM with ID `900` (adjust the ID as needed for your lab environment):

```bash
qm create 900 \
  --name SecurityOnion-3.2 \
  --ostype l26 \
  --cpu host --cores 8 \
  --memory 24576 --balloon 0 \
  --net0 virtio,bridge=vmbr0,tag=99,firewall=1 \
  --net1 virtio,bridge=vmbr1,firewall=0 \
  --scsihw virtio-scsi-pci \
  --scsi0 ext-ssd:250,discard=on,ssd=1 \
  --ide2 local:iso/securityonion-3.2.0.iso,media=cdrom \
  --boot "order=ide2;scsi0" \
  --agent 1 \
  --onboot 1
```

> **Important:** The boot-order value is enclosed in quotes because the `;` character has special meaning in the shell. Quoting `"order=ide2;scsi0"` ensures the entire value is passed to `qm` as a single argument.

![Proxmox VM Provisioning](/images/Proxmox/Provisioning.png)

The Proxmox backend should report successful creation of the VM resources, including the virtual disk:

* Logical volume `vm-900-disk-0` created.
* `scsi0` successfully created and attached to the VM.

---

### 2.2 Verify the VM Configuration

After creating the VM, verify the complete configuration:

```bash
qm config 900
```

![Verify VM Configuration](/images/Proxmox/verify_vm.png)

The configuration should contain the expected CPU, memory, networking, storage, boot, QEMU Guest Agent, and automatic-start settings.

### Configuration Review

The following settings are particularly important for this Security Onion deployment.

* **Boot Order:** The VM should use `order=ide2;scsi0`. This allows the VM to boot from the installation ISO initially while ensuring that the VM can subsequently boot from the installed operating system on the `scsi0` disk after installation is complete.

* **QEMU Guest Agent:** The `agent: 1` setting enables communication between the Proxmox host and the guest operating system through the QEMU Guest Agent. This provides several useful capabilities for a lab environment:

  * **Graceful Shutdowns:** With the guest agent available and running inside the VM, Proxmox can communicate with the operating system to request a controlled shutdown rather than relying on an abrupt power-off. This gives Security Onion an opportunity to safely close services and databases.

  * **IP Address Visibility:** The guest agent can report the VM's network information to Proxmox, allowing the VM's IP address to be displayed in the Proxmox Web GUI when the guest agent is functioning correctly.

  * **Application-Consistent Backups:** The QEMU Guest Agent can support filesystem freeze/thaw operations during supported Proxmox backup workflows. This helps coordinate filesystem activity so that data is flushed before the filesystem is temporarily frozen.

* **Start on Boot:** The `onboot: 1` setting instructs the Proxmox host to automatically start the VM when the physical server boots.

  * **Continuous Monitoring:** Security Onion acts as the security monitoring layer for the lab, capturing mirrored traffic and generating alerts. If the Proxmox host reboots and the VM remains powered off, network monitoring will not resume until the VM is manually started.

  * **Infrastructure Resilience:** If the lab experiences a power interruption or the Proxmox host requires maintenance and subsequently reboots, automatically starting the Security Onion VM allows the security monitoring infrastructure to return online without requiring manual intervention.

Without the `onboot` setting enabled, the VM will remain powered off after a Proxmox host reboot until an administrator manually starts it.

### Apply or Correct the Required Settings

If the boot order, QEMU Guest Agent, or automatic-start settings are missing or incorrect, apply them with:

```bash
qm set 900 --boot "order=ide2;scsi0" --agent 1 --onboot 1
```

Then verify the configuration again:

```bash
qm config 900
```

![Final VM Configuration Verification](/images/Proxmox/final_verify.png)

At this point, the VM configuration should reflect the complete deployment requirements, including:

* 8 CPU cores using the `host` CPU type
* 24 GB of RAM
* Memory ballooning disabled
* Management/network interface on `vmbr0` with VLAN tag `99`
* Monitoring interface on `vmbr1`
* VirtIO SCSI storage controller
* 250 GB virtual disk on the `ext-ssd` storage pool
* Security Onion installation ISO attached as `ide2`
* Boot order configured as `ide2;scsi0`
* QEMU Guest Agent enabled
* Automatic VM startup enabled

---

### 2.3 Start the VM and Verify in the Proxmox Web GUI

Start the VM from the Proxmox shell:

```bash
qm start 900
```

![Security Onion VM Running in Proxmox](/images/Proxmox/vm_fin.png)

After the VM starts successfully, open the Proxmox Web GUI and select the `SecurityOnion-3.2` VM.

Verify that:

* The VM is running.
* The expected network interfaces are present.
* The installation ISO is attached.
* The VM console is accessible.
* The hardware configuration matches the intended lab design.

---

# Step 3: Base OS Installation

With the VM powered on, navigate to the **Console** tab in the Proxmox Web GUI to interact with the virtual machine and begin the Security Onion installation.

### 3.1 Boot the Installation ISO

The VM should boot from the attached Security Onion installation ISO.

When the GRUB boot menu appears, select:

```text
Install Security Onion
```

The installer will begin loading the base operating system and Security Onion installation environment.

### 3.2 Create the Administrative OS Account

The base operating-system installer will initialize. Follow the on-screen prompts to create the administrative OS user account and password.

> **Note:** Store these credentials securely. This account is used for backend operating-system access and will be required when performing administrative tasks from the Security Onion terminal. It is separate from the web-based Security Onion SOC administrator account that will be configured later.

After the base operating-system installation completes, allow the VM to reboot.

Once the installation ISO is no longer required, verify that the VM boots from the installed `scsi0` disk according to the configured boot order.
