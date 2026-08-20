Step 5: Complete and Validate Security Onion 3.2.0
This final deployment step transitions the system from a base installation into a fully operational Security Onion platform.
At this point, the goal is to make sure the major components are not only installed, but also able to communicate with one another and operate together as intended. The process below covers recovery of the offline Docker registry, repair of Elasticsearch authentication, service startup, and final validation.
> **Important:** This step was performed in an air-gapped lab environment. Some recovery actions were necessary because the system could not reach the Internet to obtain container registry content.
---
Phase 1: Recovering the Offline Docker Registry
Why this is necessary
Security Onion uses Docker containers for many of its core services. In an air-gapped environment, the system cannot contact external container registries to obtain those images.
Fortunately, the Security Onion ISO contains the registry data and registry image needed to restore the local repository.
The two important files are:
```text
/docker/registry.tar
/docker/registry_image.tar
```
1. Mount the Security Onion ISO
Create a temporary mount point and mount the ISO in read-only mode:
```bash
mkdir -p /mnt/securityonion-iso
mount -o ro /dev/sr0 /mnt/securityonion-iso
```
Using `-o ro` ensures that the ISO is mounted read-only and cannot be modified accidentally.
Verify the registry files are available:
```bash
ls -lh /mnt/securityonion-iso/docker/
```
You should see:
```text
registry.tar
registry_image.tar
```
2. Stage the Registry Files
Create the directory expected by Security Onion:
```bash
mkdir -p /nsm/docker-registry/docker
```
Copy the registry data:
```bash
cp -v /mnt/securityonion-iso/docker/registry.tar \
  /nsm/docker-registry/docker/
```
Copy the registry image:
```bash
cp -v /mnt/securityonion-iso/docker/registry_image.tar \
  /nsm/docker-registry/docker/
```
Verify the files:
```bash
ls -lh /nsm/docker-registry/docker/
```
3. Verify File Integrity with SHA-256
A SHA-256 hash acts like a digital fingerprint for a file. Matching hashes confirm that the files on the ISO and the copied files are identical.
Check the registry archive:
```bash
sha256sum /mnt/securityonion-iso/docker/registry.tar
sha256sum /nsm/docker-registry/docker/registry.tar
```
Check the registry image:
```bash
sha256sum /mnt/securityonion-iso/docker/registry_image.tar
sha256sum /nsm/docker-registry/docker/registry_image.tar
```
The corresponding source and destination hashes should match exactly.
4. Inspect the Registry Archive
Confirm that the archive contains a valid Docker Registry structure:
```bash
tar -tf /nsm/docker-registry/docker/registry.tar | head -30
```
Expected entries should include:
```text
registry/
registry/v2/
```
This confirms that the archive contains actual registry data rather than an empty or unrelated file.
---
Phase 2: Initializing the Local Image Repository
Why this is necessary
The registry data contains the Security Onion images, but the registry service itself also needs a Docker image in order to run.
We therefore load the embedded registry image and then allow Security Onion's configuration-management system to rebuild the local registry.
1. Load the Embedded Registry Image
```bash
docker load -i /nsm/docker-registry/docker/registry_image.tar
```
Verify the image is available:
```bash
docker images --no-trunc | grep 'security-onion-solutions/registry'
```
The expected registry image is:
```text
ghcr.io/security-onion-solutions/registry:3.1.1
```
2. Rebuild the Registry with SaltStack
Security Onion uses SaltStack to manage its configuration and services.
Apply the registry state:
```bash
salt-call state.apply registry queue=True
```
3. Verify the Registry Is Running
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
This is an empty JSON object, and it indicates that the registry responded successfully.
4. Validate the Image Catalog
List the repositories stored in the local registry:
```bash
curl -sk https://127.0.0.1:5000/v2/_catalog | jq -r '.repositories[]'
```
You should see Security Onion repositories such as:
```text
security-onion-solutions/so-elasticsearch
security-onion-solutions/so-kibana
security-onion-solutions/so-logstash
security-onion-solutions/so-soc
security-onion-solutions/so-suricata
security-onion-solutions/so-zeek
```
To verify the expected Security Onion application version:
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
---
Phase 3: Repairing Elasticsearch Authentication
Why this is necessary
During the deployment, SOC configuration attempted to reference Elasticsearch authentication information that had not yet been generated.
This resulted in a Salt/Jinja error similar to:
```text
Jinja variable 'dict object' has no attribute 'auth'
```
In simple terms, Security Onion expected Elasticsearch credentials to exist, but the required authentication data was not yet present.
1. Generate the Authentication Pillar
Check whether the Elasticsearch authentication data exists:
```bash
salt-call pillar.get elasticsearch:auth --out=yaml
```
If the expected authentication data is missing, apply the built-in Security Onion authentication state:
```bash
salt-call state.apply elasticsearch.auth
```
Verify the generated file:
```bash
ls -l /opt/so/saltstack/local/pillar/elasticsearch/auth.sls
```
2. Synchronize Elasticsearch Users and Roles
Security Onion also needs the Elasticsearch user and role files that are generated by its `so-user` utility.
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
These files are required before the Elasticsearch container can be started successfully.
---
Phase 4: Validating Core Infrastructure
Why this is necessary
Once the local registry and Elasticsearch authentication are working, the core Security Onion services can be started.
The goal here is to verify not only that the containers exist, but that the applications inside them are actually responding.
1. Start Elasticsearch
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
2. Authenticate Directly to Elasticsearch
Retrieve the generated `so_elastic` password from Salt:
```bash
ES_PASS=$(salt-call pillar.get \
  'elasticsearch:auth:users:so_elastic_user:pass' \
  --out=txt | awk '{print $2}')
```
Query Elasticsearch:
```bash
curl -k -u "so_elastic:$ES_PASS" \
  https://127.0.0.1:9200/
```
A successful response should identify the node as:
```text
securityonion
```
and report Elasticsearch:
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
At this point, Elasticsearch has been verified at the application level rather than simply being reported as a running container.
3. Start the SOC and ElastAlert Services
Start SOC:
```bash
salt-call state.apply soc -l info
```
Start ElastAlert:
```bash
salt-call state.apply elastalert -l info
```
Verify both services:
```bash
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' \
  | grep -E 'so-soc|so-elastalert'
```
Both should report a running state.
---
Phase 5: System Convergence and Final Validation
Why this is important
At this stage, the major services are running, but we still need to make sure the overall Security Onion configuration is consistent.
A SaltStack highstate compares the actual machine against the configuration Security Onion expects and applies any required changes.
This is the final configuration-management check.
1. Run the Final Highstate
```bash
salt-call state.highstate -l info
```
This can take several minutes.
A successful deployment must finish with:
```text
Failed:      0
```
During this deployment, the final highstate completed with:
```text
Succeeded: 734 (changed=34)
Failed:      0
```
The exact number of succeeded states may vary between systems, but the critical requirement is:
```text
Failed: 0
```
2. Run the Final Security Onion Health Check
Use Security Onion's built-in status utility:
```bash
so-status
```
The required services should report as:
```text
running
```
and health checks should report healthy where applicable.
The final service stack included:
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
The final validation should conclude with:
```text
✔ This onion is ready to make your adversaries cry!
```
---
Final Result
The Security Onion 3.2.0 standalone deployment is now operational.
The completed platform includes:
Embedded Docker registry restored from the ISO
Security Onion 3.2.0 container images available locally
Elasticsearch 9.3.7 running and responding over HTTPS
Elasticsearch authentication successfully generated and synchronized
SOC running
ElastAlert running
Suricata running
Zeek running and healthy
Kibana running
Logstash running
Strelka services running
Supporting Security Onion services operational
Final SaltStack highstate completed with zero failures
Architecture Overview
The simplified data flow looks like this:
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
Suricata and Zeek observe network activity.
Processing and logging components prepare the resulting data.
Elasticsearch stores and indexes the information.
Kibana and SOC provide the interface for viewing, searching, investigating, and managing security data.
Security analysts can then use the platform for monitoring, detection, and investigation.
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