```

**2. Authenticate against the Database**
Verify the container is listening on port `9200` and can answer authenticated requests by pulling the generated password directly from Salt:
```bash
ES_PASS=$(salt-call pillar.get \
  'elasticsearch:auth:users:so_elastic_user:pass' \
  --out=txt | awk '{print $2}')

curl -k -u "so_elastic:$ES_PASS" https://127.0.0.1:9200/
```
*A successful response will output a JSON block identifying the cluster name as `"securityonion"` and the version as `"9.3.7"`.*

**3. Start the SOC and ElastAlert Services**
```bash
salt-call state.apply soc -l info
salt-call state.apply elastalert -l info
```

---

## Phase 5: System Convergence & Final Validation

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