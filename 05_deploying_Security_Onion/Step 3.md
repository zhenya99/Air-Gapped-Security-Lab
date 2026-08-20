## 3. Base OS Installation

With the VM powered on, navigate to the **Console** tab in the Proxmox Web GUI to interact with the virtual machine and begin the Security Onion installation.

### Step 1: Boot the Installation ISO

The VM will automatically boot from the attached Security Onion ISO.

When the GRUB boot menu appears, select the default option:

```text
Install Security Onion
```

Press **Enter** to begin the installation.

---

### Step 2: Confirm the Disk Installation

During the initial installation process, the installer will display a warning indicating that all data on the selected installation device will be destroyed.

Because this lab uses a dedicated **250 GB virtual disk** provisioned specifically for the Security Onion VM, it is safe to proceed as long as the correct virtual disk has been selected.

When prompted, type:

```text
yes
```

and press **Enter**.

![Security Onion OS Installation Warning](images/Proxmox/os_warning.png)

> **⚠️ Important:** Verify that the installer is targeting the intended Security Onion VM disk before confirming. The installation process will erase the selected disk.

---

### Step 3: Create the Administrative OS Account

The base operating-system installation will initialize and prompt you to create an administrative OS user account and password.

Follow the on-screen prompts to configure the account.

> **Note:** Store these credentials securely. This account is used for backend operating-system access and will be required to run the `so-setup` wizard during the next phase of the deployment. It is separate from the web-based SOC administrator account.

---

### Step 4: Complete the Installation

Allow the base operating-system installation to complete.

When the installer indicates that the installation has finished, press **Enter** when prompted.

The VM will reboot and load the newly installed operating system.

![Security Onion OS Installation](images/Proxmox/s_o_install.png)

After the reboot, the VM should arrive at the Security Onion command-line interface.

At this point, the base operating-system installation is complete and the system is ready for the next phase of the deployment.
