### Step 2: Provision the Virtual Machine via CLI

With the external SSD fully initialized, we can provision the VM directly from the Proxmox shell. This `qm create` command maps our exact hardware blueprint—allocating the `host` CPU architecture, 24 GB of dedicated RAM, bridging the specific network interfaces, and assigning 250 GB of storage on the newly created `ext-ssd` pool.



**2.1 Create a VM**
*Run the following command to with ID `900` (adjust the ID as needed for your lab environment):*

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
  --boot order=ide2;scsi0 \
  --agent 1 \
  --onboot 1
```

![Disk](/images/Proxmox/Provisioning.png)

You can see the Proxmox backend doing exactly what it was supposed to do:
* Logical volume "vm-900-disk-0" created.
* scsi0: successfully created disk...

**2.2 Verify VM's configuration**
```bash
qm config 900
```

![Disk](/images/Proxmox/verify_vm.png)

**What Got Missed:**

* **Boot Order:** It currently says `boot: order=ide2`. It is missing the `;scsi0` part. While it will successfully boot from the ISO to allow the OS install, Proxmox won't know to boot from the actual hard drive once the installation finishes and the VM reboots.

* **QEMU Guest Agent:** The `agent: 1` flag is missing. The QEMU Guest Agent is a small background service that runs inside your virtual machine's operating system. It acts as a direct communication bridge between the Proxmox host and the Security Onion VM. Here is why enabling it is considered a best practice for a lab:

  * **Graceful Shutdowns:** Without the agent, telling Proxmox to "Shutdown" the VM is the equivalent of pulling the power cord out of the wall. With the agent enabled, Proxmox sends a polite shutdown command to the OS, allowing Security Onion to safely close its databases (like Elasticsearch and Zeek logs) without corrupting your data.

  * **IP Address Visibility:** The agent pushes the VM's active IP address directly to the Proxmox Web GUI summary page. This saves you from having to log into the VM console just to figure out what IP address it is using.

  * **Application-Consistent Backups:** If you ever take a snapshot or run a Proxmox backup of this VM, the agent tells the OS to briefly pause and flush all pending data to the disk. This ensures your backups are completely stable and not captured in the middle of a file write.

* **Start on Boot:** The `onboot: 1` flag is missing. The `--onboot 1` flag simply tells the Proxmox host: *"Whenever the physical server powers on, automatically start this virtual machine."* Here is why this is specifically important for this type of deployment:

  * **Continuous Monitoring:** Security Onion acts as the "eyes" of your network, capturing mirrored traffic and generating alerts. If your physical host reboots and the VM stays powered off, you have a complete blind spot in your network until you manually log into Proxmox and hit start.

  * **Infrastructure Resilience:** If your lab loses power or requires a host-level update, you want your core security infrastructure (like your SIEM and IDS sensors) to come back online autonomously alongside your networking equipment.

  Without this flag (or if it is set to `0`), the VM will just sit in a powered-off state after a host reboot, waiting for you to intervene. By adding it, the sensor is always up and listening whenever the server is running.

**To fix this, run:**
```bash
qm set 900 --boot "order=ide2;scsi0" --agent 1 --onboot 1
```
Once done, verify the configuration:
``` bash
qm config 900
```
![Disk](/images/Proxmox/final_verify.png)

Everything from the CPU and memory allocation to the network bridges and the external SSD storage is exactly where it needs to be.


**2.3 Start the VM and verify in Proxmox Web GUI**
```bash 
qm start 900
```
![Disk](/images/Proxmox/vm_fin.png)


## Step 3. Base OS Installation

With the VM powered on, navigate to the **Console** tab in the Proxmox Web GUI to interact with the virtual machine and begin the installation.

### Step 1: Boot the Installation ISO

The VM will automatically boot from the attached ISO. When the GRUB boot menu appears, select the default option:

`Install Security Onion`

### Step 2: Create the Administrative OS Account

The base CentOS/Oracle Linux installer will initialize. Follow the on-screen prompts to create your administrative OS user account and password. 

> **Note:** Store these credentials securely. This account is strictly for backend operating system access and will be required to run the `so-setup` wizard in the next phase. This is separate from your web-based SOC administrator account.
