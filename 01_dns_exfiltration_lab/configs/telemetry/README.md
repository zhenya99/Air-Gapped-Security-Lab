# Future Splunk collection stage

Splunk is not installed. These optional files prepare network access after a collector exists; do not apply them with the core overlay.

## Proposed deployment

Reserve 172.16.99.40/24, gateway 172.16.99.1, for a Linux Splunk Enterprise host with a syslog daemon. Confirm availability first. This can be a later VM or separate machine; budget CPU, RAM and disk alongside the existing Security Onion VM before deciding. The analyst uses its existing Internet connection to obtain installation material.

| Sender | Receiver | Transport | Purpose |
|---|---|---|---|
| Cisco 172.16.99.2 | Syslog daemon .99.40 | UDP 514 | Switch events |
| SRX 172.16.99.1 | Syslog daemon .99.40 | UDP 514 | Structured RT_FLOW and system logs |
| Windows .10.50 | Splunk .99.40 | TCP 9997 | Configured Windows/Sysmon universal forwarder |
| BIND .20.53 | Splunk .99.40 | TCP 9997 | Configured Linux universal forwarder |
| Security Onion .99.30 | Splunk ingestion/export workflow | Select during deployment | Zeek, Suricata, exported evidence |

The syslog daemon writes separate files per device. Splunk monitors those local files using the appropriate Cisco IOS and Juniper add-ons. Preserve the device's original message, timestamp and hostname. UDP syslog can drop data, so reconcile source and collector counts; use a supported stream/collector design if experiment rates exceed this small-lab profile.

TCP 9997 is a Splunk forwarding receiver, not a generic syslog input. Configure TLS and receiver/forwarder settings in Splunk and its host firewall. Opening the port on the SRX does not configure the service.

Keep the Splunk web/management services accessible from the analyst through VLAN 99 using the collector's host firewall. Do not open those interfaces to victims. Devices and the analyst are on the same management VLAN, so their mutual traffic does not traverse the SRX.

## Activation order

1. Deploy the collector and verify .40 is unique.
2. Configure local syslog files and Splunk inputs/add-ons.
3. Configure the TCP 9997 receiver and host firewall.
4. Apply the optional Cisco and Juniper telemetry files.
5. Install and configure endpoint forwarders on Windows and BIND.
6. Select a supported Security Onion export/collection method for the installed version; do not assume the current sensor automatically sends events to Splunk.
7. Select and configure a common time source, then measure clock offsets.
8. Validate one event from each source before generating a larger dataset.

For the first DNS exercise, retain a victim-side PCAP, Zeek DNS records, BIND query logs and Windows process/DNS events with a shared run identifier. Keep request counts distinct from SRX session counts and from duplicated SPAN observations.

## References

- [Splunk receiver configuration](https://help.splunk.com/?resourceId=Splunk_Forwarding_Enableareceiver): TCP 9997 is the conventional receiver port.
- [Splunk JunOS source handling](https://splunk.github.io/splunk-connect-for-syslog/main/sources/vendor/Juniper/junos/): structured and unstructured Juniper flow records use different sourcetypes.
- [Juniper logging modes](https://www.juniper.net/documentation/us/en/software/junos/network-mgmt/topics/topic-map/system-logging-for-a-security-device.html): choose a logging mode appropriate to traffic rate.
