## Proxmox Change — Add VLAN 66

### Why Was This Needed?

The Ubuntu DNS server will use VLAN 66. Proxmox must allow VLAN 66 before the DNS-server VM can connect to that network.

### Configuration Change

The following line:

```text
bridge-vids 10 99
```

was changed to:

```text
bridge-vids 10 66 99
```

The final `vmbr0` VLAN settings are:

```text
bridge-vlan-aware yes
bridge-vids 10 66 99
```

### Commands Used

The configuration was checked before applying it:

```bash
ifreload -a -n
```

The configuration was then applied:

```bash
ifreload -a
```

### Verification

The following command displayed the permitted VLANs:

```bash
bridge -c vlan show
```

The result confirmed that `nic0` permits:

* VLAN 10 for the Windows victim.
* VLAN 66 for the Ubuntu DNS server.
* VLAN 99 for management.

Management connectivity was tested with:

```bash
ping -c 4 172.16.99.1
```

The gateway replied successfully with 0% packet loss.

### Result

VLAN 66 is now available on the Proxmox production bridge, and management connectivity remains operational.
