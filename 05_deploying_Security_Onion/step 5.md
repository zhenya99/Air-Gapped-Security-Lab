5. Complete and Validate Security Onion 3.2.0
This final deployment stage transitions the Security Onion VM from a base installation into a fully operational security monitoring platform.
At this point, the operating system and core Security Onion components are installed. The remaining work is to restore the offline container registry, synchronize Elasticsearch authentication, start the dependent services, and verify that the entire platform is operating correctly.
---
Step 1: Recover the Offline Docker Registry
Because this lab operates in an air-gapped environment, the Security Onion VM cannot reach external container registries to download the images it needs.
Fortunately, the Security Onion installation ISO contains the required registry data:
```text
/docker/registry.tar
/docker/registry_image.tar
```
These files allow the local Docker registry to be restored without Internet access.
Mount the Security Onion ISO
Create a temporary mount point and attach the ISO in read-only mode:
```bash
mkdir -p /mnt/securityonion-iso
mount -o ro /dev/sr0 /mnt/securityonion-iso
```
The `-o ro` option mounts the ISO as read-only, which prevents accidental changes to the installation media.
Verify that the registry files are present:
```bash
ls -lh /mnt/securityonion-iso/docker/
```
You should see:
```text
registry.tar
registry_image.tar
```
---
Step 2: Stage and Verify the Registry Files
Create the directory where Security Onion expects the registry data:
```bash
mkdir -p /nsm/docker-registry/docker
```
Copy the registry archive:
```bash
cp -v /mnt/securityonion-iso/docker/registry.tar \
  /nsm/docker-registry/docker/
```
Copy the registry Docker image:
```bash
cp -v /mnt/securityonion-iso/docker/registry_image.tar \
  /nsm/docker-registry/docker/
```
Verify the files:
```bash
ls -lh /nsm/docker-registry/docker/
```
Verify File Integrity
A SHA-256 hash acts like a digital fingerprint for a file. The source and destination hashes should match exactly.
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
The matching hashes confirm that the files were copied without corruption.
Inspect the Registry Archive
Confirm that the archive contains a real Docker Registry data structure:
```bash
tar -tf /nsm/docker-registry/docker/registry.tar | head -30
```
Expected output should include paths such as:
```text
registry/
registry/v2/
```
> **Important:** Do not proceed if the archive is missing or the SHA-256 hashes do not match.
---
Step 3: Initialize the Local Image Repository
The registry data is now in place, but the Docker image used to run the registry service must also be loaded.
Load the Embedded Registry Image
```bash
docker load -i /nsm/docker-registry/docker/registry_image.tar
```
Verify the image:
```bash
docker images --no-trunc | grep 'security-onion-solutions/registry'
```
The expected image is:
```text
ghcr.io/security-onion-solutions/registry:3.1.1
```
Rebuild the Registry with SaltStack
Security Onion uses SaltStack to manage system configuration and services.
Apply the registry state:
```bash
salt-call state.apply registry queue=True
```
Verify the Registry Service
Check the container:
```bash
docker ps -a --filter name=so-dockerregistry
```
Then test the local registry API:
```bash
curl -sk https://127.0.0.1:5000/v2/
```
A successful response should be:
```text
{}
```
The `{}` response is an empty JSON object, and it indicates that the registry API is responding successfully.
---
Step 4: Verify the Security Onion Image Catalog
Now that the local registry is operational, confirm that it actually contains the Security Onion images required for the deployment.
List the repositories:
```bash
curl -sk https://127.0.0.1:5000/v2/_catalog | jq -r '.repositories[]'
```
You should see repositories similar to:
```text
security-onion-solutions/so-elasticsearch
security-onion-solutions/so-kibana
security-onion-solutions/so-logstash
security-onion-solutions/so-soc
security-onion-solutions/so-suricata
security-onion-solutions/so-zeek
```
Check several of the application images:
```bash
for repo in so-soc so-suricata so-zeek; do
    echo "===== $repo ====="
    curl -sk \
      "https://127.0.0.1:5000/v2/security-onion-solutions/$repo/tags/list" \
      | jq .
done
```
The application images should report:
```text
3.2.0
```
Elasticsearch should report:
```text
9.3.7
```
What this confirms
This step proves that the local registry contains the correct software versions needed to complete the Security Onion deployment without relying on the Internet.
---
Step 5: Repair Elasticsearch Authentication
During the deployment, SOC configuration attempted to reference Elasticsearch authentication information that had not yet been generated.
This produced a Salt/Jinja error similar to:
```text
Jinja variable 'dict object' has no attribute 'auth'
```
In simple terms, Security Onion knew it needed Elasticsearch credentials, but the expected authentication data did not yet exist.
Generate the Authentication Pillar
Check the current Elasticsearch authentication data:
```bash
salt-call pillar.get elasticsearch:auth --out=yaml
```
If the authentication data is missing, apply the built-in state:
```bash
salt-call state.apply elasticsearch.auth
```
Verify that the authentication file now exists:
```bash
ls -l /opt/so/saltstack/local/pillar/elasticsearch/auth.sls
```
Synchronize Elasticsearch Users and Roles
Security Onion also generates the Elasticsearch user and role files with `so-user`.
Run:
```bash
so-user sync
```
Verify the generated files:
```bash
ls -lah \
  /opt/so/saltstack/local/salt/elasticsearch/files/users \
  /opt/so/saltstack/local/salt/elasticsearch/files/users_roles \
  /opt/so/conf/soc/soc_users_roles
```
Verify the active Elasticsearch copies:
```bash
ls -lah \
  /opt/so/conf/elasticsearch/users \
  /opt/so/conf/elasticsearch/users_roles
```
> **Why this matters:** Elasticsearch requires these files before the container can be started with the expected Security Onion authentication configuration.
---
Step 6: Start and Validate Elasticsearch
With the registry and authentication data in place, Elasticsearch can now be started.
Apply the Elasticsearch state:
```bash
salt-call state.apply elasticsearch -l info
```
Verify the container:
```bash
docker ps -a --filter name=so-elasticsearch
```
Verify that port `9200` is listening:
```bash
ss -lntp | grep ':9200'
```
Test Elasticsearch Directly
Retrieve the generated `so_elastic` password:
```bash
ES_PASS=$(salt-call pillar.get \
  'elasticsearch:auth:users:so_elastic_user:pass' \
  --out=txt | awk '{print $2}')
```
Send an authenticated HTTPS request:
```bash
curl -k -u "so_elastic:$ES_PASS" \
  https://127.0.0.1:9200/
```
A successful response should identify:
```text
securityonion
```
and show Elasticsearch version:
```text
9.3.7
```
A successful response will look similar to:
```json
{
  "name" : "securityonion",
  "cluster_name" : "securityonion",
  "version" : {
    "number" : "9.3.7"
  }
}
```
> **Important:** A running Docker container does not automatically mean the application inside it is ready. The HTTPS request above confirms that Elasticsearch itself is actually responding and accepting authenticated requests.
---
Step 7: Start the SOC and ElastAlert Services
With Elasticsearch operational, the higher-level Security Onion services can now be started.
Start SOC:
```bash
salt-call state.apply soc -l info
```
Start ElastAlert:
```bash
salt-call state.apply elastalert -l info
```
Verify the services:
```bash
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' \
  | grep -E 'so-soc|so-elastalert'
```
Both services should report a running state.
---
Step 8: Run the Final SaltStack Highstate
What is a highstate?
SaltStack is Security Onion's configuration-management system.
A highstate tells Salt:
> Compare the current system with the configuration Security Onion expects, then apply any required changes.
Run:
```bash
salt-call state.highstate -l info
```
This can take several minutes.
The most important result is:
```text
Failed:      0
```
During this deployment, the final highstate completed with:
```text
Succeeded: 734 (changed=34)
Failed:      0
```
The exact number of successful states may vary between installations. The critical requirement is:
```text
Failed: 0
```
This confirms that SaltStack was able to bring the system into the expected configuration without leaving failed states behind.
---
Step 9: Perform the Final Security Onion Health Check
Run the built-in Security Onion status command:
```bash
so-status
```
The required services should report as:
```text
running
```
and services that provide health checks should report healthy status where applicable.
The completed service stack included:
```text
so-dockerregistry
so-elastalert
so-elastic-fleet-package-registry
so-elasticsearch
so-influxdb
so-kibana
so-kratos
so-logstash
so-nginx
so-postgres
so-redis
so-sensoroni
so-soc
so-strelka-backend
so-strelka-coordinator
so-strelka-filestream
so-strelka-frontend
so-strelka-gatekeeper
so-strelka-manager
so-suricata
so-telegraf
so-zeek
```
> **Important:** The exact container list can vary depending on the Security Onion role and enabled features. The goal is to confirm that all services required by this standalone deployment are running successfully.
The final validation should conclude with:
```text
✔ This onion is ready to make your adversaries cry!
```
---
Final Result
The Security Onion 3.2.0 standalone deployment is now operational.
The completed platform includes:
Embedded Docker registry restored from the Security Onion ISO
Security Onion 3.2.0 container images available locally
Elasticsearch 9.3.7 running and responding over HTTPS
Elasticsearch authentication generated and synchronized
SOC running
ElastAlert running
Suricata running
Zeek running and healthy
Kibana running
Logstash running
Strelka services running
Supporting Security Onion services operational
Final SaltStack highstate completed with zero failures
---
Architecture Overview
The overall flow can be simplified as follows:
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
         Kibana  SOC
           │      │
           └──┬───┘
              ▼
     Security Monitoring
  Detection & Investigation
```
In practical terms:
Suricata and Zeek observe and analyze network traffic.
Processing and logging components prepare the resulting data.
Elasticsearch stores and indexes the information.
Kibana and SOC provide the interface used to view, search, investigate, and manage security data.
The analyst can then use the platform for monitoring, detection, and investigation.
---
Deployment Complete
Run the final command one more time:
```bash
so-status
```
When Security Onion reports:
```text
✔ This onion is ready to make your adversaries cry!
```
the deployment and validation process is complete.