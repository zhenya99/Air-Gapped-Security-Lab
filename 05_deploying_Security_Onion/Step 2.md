### Boot Order During Installation

Before starting the Security Onion installer, configure the VM to boot from the ISO first:

```bash
qm set 900 --boot "order=ide2;scsi0"
```

Verify:

```bash
qm config 900 | grep '^boot:'
```

Expected:

```text
boot: order=ide2;scsi0
```

This means:

```text
1. ide2  → Security Onion installation ISO
2. scsi0 → Security Onion virtual system disk
```

Use this boot order **only during installation**.

---

### Post-Installation Boot Order

After the Security Onion base operating system has finished installing and the installer prompts you to reboot, change the boot order so the virtual disk is first.

From the Proxmox host:

```bash
qm shutdown 900
```

Then configure:

```bash
qm set 900 --boot "order=scsi0;ide2"
```

Verify:

```bash
qm config 900 | grep '^boot:'
```

Expected:

```text
boot: order=scsi0;ide2
```

The VM will now use:

```text
1. scsi0 → Installed Security Onion system
2. ide2  → Security Onion ISO, if still attached
```

This prevents the VM from repeatedly returning to the Security Onion installer after reboot.

---

### Recommended: Eject the Installation ISO

Once Security Onion has been installed successfully, the ISO is no longer required for normal booting.

You can detach it from the virtual CD/DVD drive:

```bash
qm set 900 --ide2 none,media=cdrom
```

Then configure the system disk as the only boot device:

```bash
qm set 900 --boot "order=scsi0"
```

Verify both settings:

```bash
qm config 900 | grep -E '^boot:|^ide2:'
```

Expected boot configuration:

```text
boot: order=scsi0
```

The final production boot path is therefore:

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
Security Onion 3.2.x
```

---

### Boot Order Summary

| Phase                                 | Boot Order   | Purpose                                       |
| ------------------------------------- | ------------ | --------------------------------------------- |
| Before installation                   | `ide2;scsi0` | Boot Security Onion ISO first                 |
| Immediately after installation        | `scsi0;ide2` | Boot installed system first                   |
| Final configuration after ISO removal | `scsi0`      | Boot only from the Security Onion system disk |

> **Important:** Do not leave `ide2` first in the boot order after installation. Otherwise, the VM may boot back into the Security Onion installation media instead of the installed operating system.
