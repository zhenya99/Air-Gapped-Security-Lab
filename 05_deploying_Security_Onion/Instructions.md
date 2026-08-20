# Deploying Security Onion v3.2.0

Deploying Security Onion 3.2.x requires precise interface alignment to ensure the mirrored VLAN 10 traffic successfully reaches the Suricata and Zeek sensors.

---

## 1. VM Provisioning in Proxmox

Before booting the ISO, configure the virtual hardware to match the network segmentation and storage layout. You can verify your host's capacity from the Proxmox shell:

```bash
ssh root@lab
lscpu
pvesh get /nodes/localhost/status
free -h
df -h
lsblk