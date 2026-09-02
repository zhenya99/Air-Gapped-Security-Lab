# 07. Splunk Server

## Purpose

Splunk is used to search logs and practice DNS detection engineering with SPL.

## Planned Server Settings

| Setting | Value |
|---|---|
| VMID | 902 |
| Name | `SPLUNK-SRV-01` |
| Operating system | Ubuntu Server 24.04 LTS |
| IP address | `172.16.99.40` |
| Gateway | `172.16.99.1` |
| VLAN | 99 |
| Memory | 8 GB |
| Disk | 100 GB |

## Data Sources

- Windows Sysmon events.
- Windows DNS-client events.
- Ubuntu BIND9 query logs.

## Installation

Record the offline Splunk installation steps here.

## Validation

Record how Splunk Web, log ingestion, and searches were tested.