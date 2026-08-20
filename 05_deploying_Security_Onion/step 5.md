# Step 5: Complete and Validate Security Onion 3.2.0
---

> **Troubleshooting Scenario:** Under normal circumstances, the Security Onion setup wizard automates the entire deployment process. However, because this lab environment is strictly air-gapped, the automated installation crashed. The setup scripts attempted to reach the internet to seed the Docker registry, failing instantly and leaving the system with a fractured SaltStack configuration and missing Elasticsearch dependencies. 

![SaltStack Jinja Compilation Crash](images/Proxmox/SecOnion/085234.png)
*Figure 5.0: The fatal SaltStack compilation error (`TemplateNotFound: registry/map.jinja`) caused by the air-gapped installation failure.*

### The Investigation: Tracing the Missing Dependencies
To understand why the registry failed to build, we must track down where SaltStack is looking for its configuration files and why they are missing.

**1. Checking the Salt Master Configuration**
By parsing the `/etc/salt/master` file, we can see that Security Onion does not use the default `/srv/salt` directory. Instead, the `file_roots` are dynamically mapped to `/opt/so/saltstack/local/salt`.

![Checking file_roots](images/Proxmox/SecOnion/40403.png)
*Figure 5.1: Verifying the custom SaltStack `file_roots` directory mapping.*

**2. Verifying the Missing States**
Searching the active `file_roots` directory for the core components (`docker`, `firewall`, `registry`) confirms that the installation script crashed before it could copy the `.sls` state files into production.

![Missing SLS Files](images/Proxmox/SecOnion/0655.png)
*Figure 5.2: Querying the active Salt directory yields no results for the required state files.*

**3. Finding the Orphaned Files**
Searching the original installer directory reveals that the required state files do exist locally (`/root/SecurityOnion/salt/`), but were abandoned when the internet check failed.

![Orphaned SLS Files](images/Proxmox/SecOnion/40712.png)
*Figure 5.3: Locating the stranded `.sls` configuration files in the root installer directory.*

**The following steps detail the manual recovery and configuration engineering required to bypass this failure, restore the offline Docker registry, and successfully bring the SIEM online.**

---

**This final deployment stage transitions the Security Onion VM from a broken base installation into a fully operational security monitoring platform.**

At this point, the operating system and core Security Onion components are installed. The remaining work is to restore the offline container registry, synchronize Elasticsearch authentication, start the dependent services, and verify that the entire platform is operating correctly.

---

## 5.1 Recover and Mount the Offline Docker Registry
---

Because this lab operates in an air-gapped environment, the Security Onion VM cannot reach external container registries to download the images it needs. Fortunately, the Security Onion installation ISO contains the required registry data:

```text
/docker/registry.tar
/docker/registry_image.tar
```

These files allow the local Docker registry to be restored without Internet access. Create a temporary mount point and attach the ISO in read-only mode:

```bash
mkdir -p /mnt/securityonion-iso
mount -o ro /dev/sr0 /mnt/securityonion-iso
```

The `-o ro` option mounts the ISO as read-only, which prevents accidental changes to the installation media. Verify that the registry files are present:

```bash
ls -lh /mnt/securityonion-iso/docker/
```

You should see `registry.tar` and `registry_image.tar` in the output.

---

## 5.2 Stage and Verify the Registry Files
---

Create the directory where Security Onion expects the registry data and copy the archives over:

```bash
mkdir -p /nsm/docker-registry/docker

cp -v /mnt/securityonion-iso/docker/registry.tar \
  /nsm/docker-registry/docker/

cp -v /mnt/securityonion-iso/docker/registry_image.tar \
  /nsm/docker-registry/docker/
```

Verify the files were copied successfully:

```bash
ls -lh /nsm/docker-registry/docker/
```

A SHA-256 hash acts like a digital fingerprint for a file. To ensure the archives were not corrupted during the transfer, verify the hashes of both the source and destination files. 

Check `registry.tar`:

```bash
sha256sum /mnt/securityonion-iso/docker/registry.tar
sha256sum /nsm/docker-registry/docker/registry.tar
```

Check `registry_image.tar`:

```bash
sha256sum /mnt/securityonion-iso/docker/registry_image.tar
sha256sum /nsm/docker-registry/docker/registry_image.tar
```

The matching hashes confirm that the files were copied without corruption. Finally, confirm that the archive contains a real Docker Registry data structure:

```bash
tar -tf /nsm/docker-registry/docker/registry.tar | head -30
```

> **Important:** The expected output should include paths such as `registry/` and `registry/v2/`. Do not proceed if the archive is missing or the SHA-256 hashes do not match.

---

## 5.3 Initialize the Local Image Repository
---

The registry data is now in place, but the Docker image used to run the registry service must also be loaded. Load the embedded registry image:

```bash
docker load -i /nsm/docker-registry/docker/registry_image.tar
```

Verify the image (`ghcr.io/security-onion-solutions/registry:3.1.1`) is available:

```bash
docker images --no-trunc | grep 'security-onion-solutions/registry'
```

Security Onion uses SaltStack to manage system configuration and services. Apply the registry state to rebuild it:

```bash
salt-call state.apply registry queue=True
```

Check the container status and test the local registry API:

```bash
docker ps -a --filter name=so-dockerregistry
curl -sk https://127.0.0.1:5000/v2/
```

> **Lab Note:** A successful response from the curl command should be `{}`, which is an empty JSON object indicating that the registry API is responding successfully.

---

## 5.4 Verify the Security Onion Image Catalog
---

Now that the local registry is operational, confirm that it actually contains the Security Onion images required for the deployment. List the repositories:

```bash
curl -sk https://127.0.0.1:5000/v2/_catalog | jq -r '.repositories[]'
```

You should see repositories similar to `so-elasticsearch`, `so-kibana`, `so-soc`, `so-suricata`, and `so-zeek`. Check several of the application image versions:

```bash
for repo in so-soc so-suricata so-zeek; do
    echo "===== $repo ====="
    curl -sk \
      "https://127.0.0.1:5000/v2/security-onion-solutions/$repo/tags/list" \
      | jq .
done
```

> **Why this matters:** The application images should report `3.2.0` and Elasticsearch should report `9.3.7`. This proves that the local registry contains the correct software versions needed to complete the deployment without relying on the Internet.

---

## 5.5 Repair Elasticsearch Authentication
---

During the deployment, SOC configuration attempted to reference Elasticsearch authentication information that had not yet been generated. Check the current Elasticsearch authentication data:

```bash
salt-call pillar.get elasticsearch:auth --out=yaml
```

If the authentication data is missing, apply the built-in state and verify the authentication file now exists:

```bash
salt-call state.apply elasticsearch.auth
ls -l /opt/so/saltstack/local/pillar/elasticsearch/auth.sls
```

Security Onion also generates the Elasticsearch user and role files with `so-user`. Synchronize them:

```bash
so-user sync
```

Verify the generated files and the active Elasticsearch copies:

```bash
ls -lah \
  /opt/so/saltstack/local/salt/elasticsearch/files/users \
  /opt/so/saltstack/local/salt/elasticsearch/files/users_roles \
  /opt/so/conf/soc/soc_users_roles

ls -lah \
  /opt/so/conf/elasticsearch/users \
  /opt/so/conf/elasticsearch/users_roles
```

> **Important:** Elasticsearch requires these files before the container can be started with the expected Security Onion authentication configuration.

---

## 5.6 Start and Validate Elasticsearch
---

With the registry and authentication data in place, Elasticsearch can now be started. Apply the state and verify the container (`so-elasticsearch`) is running:

```bash
salt-call state.apply elasticsearch -l info
docker ps -a --filter name=so-elasticsearch
```

Verify that port `9200` is listening:

```bash
ss -lntp | grep ':9200'
```

Retrieve the generated `so_elastic` password and send an authenticated HTTPS request to test it directly:

```bash
ES_PASS=$(salt-call pillar.get \
  'elasticsearch:auth:users:so_elastic_user:pass' \
  --out=txt | awk '{print $2}')

curl -k -u "so_elastic:$ES_PASS" \
  https://127.0.0.1:9200/
```

> **Lab Note:** A running Docker container does not automatically mean the application inside it is ready. A successful JSON response confirming the cluster name (`securityonion`) and version (`9.3.7`) proves the database is actively accepting authenticated requests.

---

## 5.7 Start the SOC and ElastAlert Services
---

With Elasticsearch operational, the higher-level Security Onion services can now be started. Start SOC and ElastAlert:

```bash
salt-call state.apply soc -l info
salt-call state.apply elastalert -l info
```

Verify the services are in a running state:

```bash
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' \
  | grep -E 'so-soc|so-elastalert'
```

---

## 5.8 Run the Final SaltStack Highstate
---

A highstate tells SaltStack to compare the current system with the configuration Security Onion expects, then apply any required changes. Run the highstate:

```bash
salt-call state.highstate -l info
```

> **Important:** This can take several minutes. The exact number of successful states may vary between installations, but the critical requirement is that the output ends with `Failed: 0`. This confirms SaltStack was able to bring the system into the expected configuration securely.

---

## 5.9 Perform the Final Security Onion Health Check
---

Run the built-in Security Onion status command to verify all 20+ microservices:

```bash
so-status
```

The required services (such as `so-kibana`, `so-suricata`, `so-zeek`, and `so-strelka`) should report as `running`, and services that provide health checks should report a healthy status where applicable. 

The final validation should conclude with:

```text
✔ This onion is ready to make your adversaries cry!
```

---

## 5.10 Final Result & Architecture Overview
---

The Security Onion 3.2.0 standalone deployment is now operational. The completed platform includes the restored embedded Docker registry, active Elasticsearch authentication, and a clean SaltStack highstate with zero failures.

The overall flow of the validated platform operates as follows:

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
           └──┬───┘
              ▼
     Security Monitoring
  Detection & Investigation
```

In practical terms, Suricata and Zeek observe and analyze network traffic, the processing components prepare the data, Elasticsearch stores and indexes the information, and Kibana/SOC provide the interface used by the analyst to view, investigate, and manage security events.