# 13. Rollback

## Purpose

Rollback returns the lab to its known-good state after testing.

## Important Rule

Use `BASELINE_CONFIGURATION/` as the source of truth. Do not modify the baseline files.

## Rollback Checklist

1. Stop the DNS-exfiltration test.
2. Export any evidence that must be kept.
3. Stop the Windows, DNS, and Splunk lab VMs.
4. Remove temporary Juniper firewall rules.
5. Restore the original Proxmox network configuration if required.
6. Restore the original Cisco configuration if it was changed.
7. Start Security Onion.
8. Confirm management connectivity.
9. Confirm the SPAN monitoring path.
10. Record the rollback test result.

## Proxmox Network Backup

The pre-lab network configuration was saved as:

```text
/root/interfaces.before-dns-lab-2026-09-02
```

Add the exact restoration commands only after they have been safely tested.