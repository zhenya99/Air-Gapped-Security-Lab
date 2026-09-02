# Network rollback

Use the actual pre-change device backups from the change window. Historical baseline documentation is a reference and may differ from the live pre-change state. Restoring a backup also removes any later changes, so compare it with the current configuration first.

## Juniper: automatic recovery

The runbook applies changes with commit confirmed 10. If management fails, do not confirm; allow the rollback timer to expire. Both commit and commit check can confirm a pending change.

From console, inspect show system commit to see the active timer. Do not assume rollback 1 is always the desired baseline after several commits.

## Juniper: restore the saved configuration

For the first deployment, the runbook saved /var/tmp/pre-dns-lab.conf. Substitute the backup from the correct change window.

```text
configure exclusive
load override /var/tmp/pre-dns-lab.conf
show | compare
commit check
commit confirmed 10
```

Reconnect and verify the original interfaces, policies and Kali-to-Proxmox health test. Confirm only after those checks:

```text
commit
exit
```

An exact rollback restores the previous LOG-FORWARDING rule, including its broad TCP access. This is a return to the saved state, not a recommendation to use that rule for the new lab.

## Cisco: recover an SSH ACL mistake from console

If the analyst cannot open a new SSH session after applying the overlay, remove only the new VTY restriction while troubleshooting:

```text
configure terminal
line vty 0 15
 no access-class LAB_ANALYST_ONLY in
end
```

Check the analyst's actual source IP, existing ACL contents and VTY configuration. Preserve the working console session. Do not save a failed configuration.

## Cisco: restore an exact backup

The first-deployment backup is flash:pre-dns-lab.cfg. Verify its content and release support for configure replace before using:

```text
configure replace flash:pre-dns-lab.cfg
```

Review and respond to the device's confirmation prompts. After connectivity, trunk and SPAN checks pass, save with copy running-config startup-config.

If configure replace is unavailable on the installed image, schedule a console-assisted reload:

```text
copy flash:pre-dns-lab.cfg startup-config
reload
```

If asked to save the current running configuration during reload, answer no; saving it would overwrite the restored startup configuration. This fallback interrupts switching during reboot.

Copying a backup into running-config merges configuration and may leave newly added policies/ACLs in place. Use an exact replacement or reviewed inverse commands.

## Restore only the general SPAN profile

After an optional DNS-only capture session:

```text
configure terminal
no monitor session 1
monitor session 1 source interface GigabitEthernet1/0/27 both
monitor session 1 destination interface GigabitEthernet1/0/28 encapsulation replicate
end
show monitor session 1
```

Verify the Kali-to-Proxmox ICMP alert again.

## Proxmox and guests

Stop the DNS experiment before removing VLAN 20. Preserve VM disks and evidence. Restore the pre-change /etc/network/interfaces file through a local console and use ifreload -a. Confirm vmbr0 carries VLANs 10 and 99 and the unchanged vmbr1 capture path still works.

VM deletion is not required for a network rollback. Guests can be stopped or have their lab NICs disconnected.

Host Internet adapters are independent of these device overlays. Keep Kali's corrected lab-specific route and Internet default-route selection unless deliberately restoring its old host configuration.

## Validate the restored baseline

- Analyst reaches 172.16.99.1, .2, .20 and .30.
- Cisco Gi1/0/1 and Gi1/0/27 have their saved allowed/native VLANs.
- SPAN mirrors Gi1/0/27 both directions to Gi1/0/28 with replication.
- Security Onion management and capture NICs retain their original assignments.
- Kali-to-Proxmox ICMP is visible and generates SID 1000001.
- Both analyst and Kali retain their intended Internet adapter routes.
- No recorded evidence or VM disks were removed.
