# Step 3: Install Security Onion 3.2.x

With the Security Onion virtual machine prepared in Proxmox, begin the operating-system installation from the official Security Onion ISO.

This step covers only the installation of the Security Onion operating system.

Security Onion platform configuration will be completed in **Step 4**.

---

## 3.1 Start the Virtual Machine

From the Proxmox host:

```bash
qm start 900
```

Open the Proxmox Web GUI and navigate to:

```text
Datacenter
└── lab
    └── VM 900 — SecurityOnion-3.2
        └── Console
```

The VM should boot from the attached Security Onion installation ISO.

---

## 3.2 Start the Security Onion Installer

At the Security Onion boot menu, select:

```text
Install Security Onion
```

Press:

```text
Enter
```

Allow the installation environment to initialize.

The Security Onion ISO provides the supported installation method and handles the operating-system disk partitioning automatically.

---

## 3.3 Select the Installation Disk

When prompted for the installation target, select the virtual system disk assigned to the Security Onion VM.

For this lab, the virtual disk is approximately:

```text
250 GB
```

The device may appear inside the installer as:

```text
/dev/sda
```

or another Linux block-device name depending on the virtual storage controller.

> **Warning**
>
> The Security Onion installation will erase the selected virtual disk.
>
> This is expected for a clean installation.

Confirm the destructive disk operation when prompted.

---

## 3.4 Allow Security Onion to Partition the Disk

Use the default disk layout provided by the official Security Onion ISO.

Do not manually create operating-system partitions unless there is a specific requirement to deviate from the supported ISO installation.

The installation process will prepare the filesystems required by Security Onion automatically.

---

## 3.5 Create the Linux Administrator Account

The installer will prompt for a local Linux username and password.

Create the account that will be used for:

* Local console access
* SSH administration
* `sudo` commands
* Security Onion command-line administration

Use a strong password and store the credentials securely.

> The Linux operating-system account is separate from the Security Onion Console account that will be created during Security Onion Setup.

---

## 3.6 Complete the Operating-System Installation

Allow the installation process to complete.

Do not interrupt the VM while files are being copied or while the boot environment is being created.

When installation completes, the installer will prompt for a reboot.

---

# 3.7 Change the Boot Order After Installation

The VM was configured to boot from the ISO first during installation:

```text
ide2 → scsi0
```

After installation, the virtual system disk must become the primary boot device.

For the expected `scsi0` system disk:

```bash
qm set 900 --boot "order=scsi0;ide2"
```

The new order is:

```text
1. scsi0 → Installed Security Onion
2. ide2  → Installation ISO
```

---

## 3.8 Detach the Installation ISO

Once installation has completed successfully, detach the ISO:

```bash
qm set 900 --ide2 none,media=cdrom
```

Then configure the system disk as the only boot device:

```bash
qm set 900 --boot "order=scsi0"
```

The final boot path is:

```text
Proxmox
   │
   ▼
VM 900
   │
   ▼
scsi0
   │
   ▼
Security Onion
```

> If the VM uses a different system-disk bus, such as `virtio0` or `sata0`, substitute the actual disk identifier established during VM provisioning.

---

## 3.9 Boot the Installed System

Start the VM if necessary:

```bash
qm start 900
```

Open the VM console.

Security Onion should now boot from the installed system disk rather than the installation ISO.

---

## 3.10 Log In

At the console login prompt, enter the Linux username and password created during installation.

After the first login, **Security Onion Setup should start automatically**.

If Setup was exited accidentally, log out and log back in.

If it still does not start, launch the supported ISO setup process manually:

```bash
sudo SecurityOnion/setup/so-setup iso
```

Do not use:

```bash
so-setup-network
```

for this deployment.

That command belongs to the unsupported network-installation workflow rather than the official Security Onion ISO installation method.

---

## 3.11 Preserve the Validated Network Hardware

After installation, do not alter the Proxmox NIC bindings while transitioning into Security Onion Setup.

The known-good bindings remain:

```text
net0 → vmbr0 → management, MTU 1500
net1 → vmbr1 → passive capture, MTU 9000
```

Step 4 will configure `ens18` as the management interface and `ens19` as the passive monitoring interface.
