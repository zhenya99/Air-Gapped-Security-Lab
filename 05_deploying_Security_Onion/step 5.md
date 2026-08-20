# Step 5: Complete and Validate Security Onion 3.2.0

This final deployment step transitions the system from a base installation to a fully operational platform. At this stage, all backend components must be manually connected, synchronized, and verified to ensure the underlying architecture is functioning securely and cohesively. 

---

## Phase 1: Recovering the Offline Docker Registry

> **Context:** Security Onion relies on Docker containers to operate its core services. In an air-gapped environment, the system cannot reach out to the internet to populate its local registry. Fortunately, the massive installation ISO contains the necessary registry assets (`registry.tar` and `registry_image.tar`). We must manually extract and stage these files.

**1. Mount the Security Onion ISO**
Create a temporary mount point and attach the ISO in a read-only state to prevent accidental modifications:
```bash
mkdir -p /mnt/securityonion-iso
mount -o ro /dev/sr0 /mnt/securityonion-iso
```

**2. Stage the Registry Files**
Create the expected directory structure and copy the local registry archives into the system:
```bash
mkdir -p /nsm/docker-registry/docker

cp -v /mnt/securityonion-iso/docker/registry.tar \
  /nsm/docker-registry/docker/

cp -v /mnt/securityonion-iso/docker/registry_image.tar \
  /nsm/docker-registry/docker/
```

**3. Verify File Integrity (SHA-256)**
To ensure the archives were not corrupted during the transfer, verify the digital fingerprints of both the source and destination files. The outputs must be identical:
```bash
sha256sum /mnt/securityonion-iso/docker/registry.tar
sha256sum /nsm/docker-registry/docker/registry.tar

sha256sum /mnt/securityonion-iso/docker/registry_image.tar
sha256sum /nsm/docker-registry/docker/registry_image.tar
```

**4. Inspect the Archive Structure**
Confirm the primary archive contains a valid Docker Registry data set:
```bash
tar -tf /nsm/docker-registry/docker/registry.tar | head -30
```
*Expected output should include directories like `registry/` and `registry/v2/`.*

---

## Phase 2: Initializing the Local Image Repository

> **Context:** With the data staged, we now need to load the administrative Docker image responsible for actually running the local registry service, and then command SaltStack to rebuild the environment. 

**1. Load the Embedded Registry Image**
```bash
docker load -i /nsm/docker-registry/docker/registry_image.tar
```

**2. Rebuild the Registry via SaltStack**
Command the configuration manager to apply the registry state:
```bash
salt-call state.apply registry queue=True
```

**3. Verify Registry Operations**
Ensure the container is running and responding successfully to HTTPS API requests:
```bash
docker ps -a --filter name=so-dockerregistry
curl -sk https://127.0.0.1:5000/v2/
```
*A healthy registry API will respond with an empty JSON array: `{}`*

**4. Validate the Image Catalog**
Query the local registry to ensure it successfully indexed the Security Onion repositories (e.g., Elasticsearch, Kibana, Suricata, Zeek):
```bash
curl -sk https://127.0.0.1:5000/v2/_catalog | jq -r '.repositories[]'
```

---

## Phase 3: Repairing Elasticsearch Authentication

> **Context:** The automated SOC configuration often fails in offline setups because it lacks the generated Elasticsearch credentials (resulting in Salt/Jinja rendering errors). We must manually trigger the generation of these authentication pillars and synchronize the user roles.

**1. Generate the Authentication Pillar**
If `salt-call pillar.get elasticsearch:auth --out=yaml` returns missing data, manually apply the authentication state:
```bash
salt-call state.apply elasticsearch.auth
```

**2. Synchronize Users and Roles**
Generate the backend user mapping files required by Elasticsearch:
```bash
so-user sync
```

**3. Verify Configuration Files**
Confirm the newly generated authentication files are successfully staged:
```bash
ls -lah \
  /opt/so/conf/elasticsearch/users \
  /opt/so/conf/elasticsearch/users_roles
```

---

## Phase 4: Validating Core Infrastructure

> **Context:** With the registry populated and authentication repaired, the core SIEM components can finally be brought online and explicitly tested for functionality. 

**1. Start Elasticsearch**
```bash
salt-call state.apply elasticsearch -l info
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
           ▼      ▼
         Kibana   SOC
           │       │ 
           └──┬──┘
              ▼
     Security Monitoring
  Detection & Investigation
```

If the final `so-status` command returns **"✔ This onion is ready to make your adversaries cry!"**, the deployment is officially complete.