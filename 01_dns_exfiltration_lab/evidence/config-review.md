# Pre-deployment configuration review

Reviewed 2026-09-02. No network device configuration was applied and no live reachability or DNS test was performed.

## Static checks completed

- Parsed the saved Juniper baseline plus the proposed core overlay into an ordered, new-session policy model.
- Verified 22 traffic decisions: analyst administration; Kali exercise access; the existing ICMP sensor test; UDP/TCP DNS; blocked alternate DNS hosts and ports; blocked victim-to-management and unsolicited reverse connections; and no access to an undeployed collector.
- Reapplied the core overlay to the model and verified the same 22 decisions and matching policies.
- Added the optional collector overlay and verified 27 decisions, including TCP 9997 permits only from the named endpoints to the proposed collector, with Splunk web/API access still blocked.
- Reapplied the core after the collector overlay and verified those 27 decisions remained correct.
- Confirmed all 12 interzone pairs were covered, referenced address/application objects resolved, and specific active permits preceded catch-all denies.
- Confirmed both Cisco trunks add VLAN 20, the core preserves the SPAN source/destination and replication, and no automatic save command is present.
- Confirmed the core Juniper overlay contains no NAT or routing-options mutations.
- Confirmed new documentation's relative links resolve.

The model checks source/destination addresses, protocols, destination ports, policy order and activation state. It is not a Junos/IOS parser and does not simulate stateful reply handling, ALG behavior, guest firewalls, VLAN forwarding or packet capture. Its results do not prove live network behavior.

## Remaining device validation

Follow 02_network_changes.md for firmware/interface preflight, backups, Junos commit check and confirmed commit, Cisco new-session SSH validation, and VLAN/SPAN checks. Test actual UDP/TCP DNS only after the Windows and BIND guests exist. Verify actual syslog receipt and Splunk parsing only after deploying the collector.

The historical BASELINE_CONFIGURATION directory was not changed.
