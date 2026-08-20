---

## Step 5: System Convergence & Final Validation

> **Context:** A "highstate" forces SaltStack to compare the entire system against its ideal configuration files and automatically correct any remaining discrepancies. A clean highstate is the ultimate proof of a stable environment. 

**1. Run the Final Highstate**
```bash
salt-call state.highstate -l info
```
*Wait for completion. A successful deployment must conclude with: `Failed: 0`.*

**2. Global Health Check**
Run the native diagnostic tool to verify all 20+ microservices:
```bash
so-status
```
*All required services must report as `running` or `OK`.*

---

## Final Result & Architecture Summary

The Security Onion 3.2.0 standalone deployment is now fully operational. The final validation confirms that the platform is not only installed, but that its major components are communicating, logging, and operating together securely.

```text
       Network Traffic
              │
              ▼
       Suricata + Zeek
              │
              ▼
     Processing / Logging
              │
              ▼
        Elasticsearch
              │
           ┌──┴──┐
           ▼     ▼
         Kibana SOC
           │     │
           └──┬──┘
              ▼
     Security Monitoring
  Detection & Investigation
```

If the final `so-status` command returns **"✔ This onion is ready to make your adversaries cry!"**, the deployment is officially complete.