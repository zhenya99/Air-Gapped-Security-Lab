Step 5 — Complete and Validate Security Onion 3.2.0
This step completes the Security Onion 3.2.0 deployment by restoring the embedded Docker registry, resolving Elasticsearch/SaltStack dependencies, bringing the remaining services online, and validating the final system state.
---
1. Restore the Offline Docker Registry
Security Onion initially failed while attempting to seed the Docker registry because the system could not resolve `raw.githubusercontent.com`.
The Security Onion ISO contained the required registry assets:
```text
/docker/registry.tar
/docker/registry_image.tar
```
Mount the Security Onion ISO and verify the files:
```bash
mkdir -p /mnt/securityonion-iso
mount -o ro /dev/sr0 /mnt/securityonion-iso

ls -lh /mnt/securityonion-iso/docker/
```
Expected files:
```text
registry.tar
registry_image.tar
```
Create the local registry directory and copy the registry data:
```bash
mkdir -p /nsm/docker-registry/docker

cp -v /mnt/securityonion-iso/docker/registry.tar \
  /nsm/docker-registry/docker/

cp -v /mnt/securityonion-iso/docker/registry_image.tar \
  /nsm/docker-registry/docker/
```
Verify the files:
```bash
ls -lh /nsm/docker-registry/docker/
```
---
2. Verify Registry File Integrity
Compare the SHA-256 hashes of the ISO files and local copies:
```bash
sha256sum /mnt/securityonion-iso/docker/registry.tar
sha256sum /nsm/docker-registry/docker/registry.tar

sha256sum /mnt/securityonion-iso/docker/registry_image.tar
sha256sum /nsm/docker-registry/docker/registry_image.tar
```
The source and destination hashes should match.
Inspect the registry archive:
```bash
tar -tf /nsm/docker-registry/docker/registry.tar | head -30
```
The archive should contain the Docker Registry structure under:
```text
registry/v2/
```
---
3. Load the Registry Image
Load the embedded registry image from the ISO:
```bash
docker load -i /nsm/docker-registry/docker/registry_image.tar
```
Verify the image:
```bash
docker images --no-trunc | grep 'security-onion-solutions/registry'
```
The expected registry image is:
```text
ghcr.io/security-onion-solutions/registry:3.1.1
```
---
4. Rebuild the Embedded Registry
Apply the registry state:
```bash
salt-call state.apply registry queue=True
```
Verify the registry container:
```bash
docker ps -a --filter name=so-dockerregistry
```
Confirm the registry API responds over HTTPS:
```bash
curl -sk https://127.0.0.1:5000/v2/
```
Expected response:
```text
{}
```
---
5. Validate the Security Onion Image Catalog
List the available repositories:
```bash
curl -sk https://127.0.0.1:5000/v2/_catalog | jq -r '.repositories[]'
```
Security Onion should expose the required repositories, including:
```text
security-onion-solutions/so-elasticsearch
security-onion-solutions/so-kibana
security-onion-solutions/so-logstash
security-onion-solutions/so-soc
security-onion-solutions/so-suricata
security-onion-solutions/so-zeek
```
Verify image tags:
```bash
for repo in so-soc so-suricata so-zeek; do
    echo "===== $repo ====="
    curl -sk \
      "https://127.0.0.1:5000/v2/security-onion-solutions/$repo/tags/list" \
      | jq .
done
```
The Security Onion application images should report:
```text
3.2.0
```
Elasticsearch should report:
```text
9.3.7
```
---
6. Repair Elasticsearch Authentication Dependencies
The SOC Salt/Jinja configuration required Elasticsearch authentication data that was initially missing.
Verify the authentication pillar:
```bash
salt-call pillar.get elasticsearch:auth --out=yaml
```
If the authentication pillar is missing, apply:
```bash
salt-call state.apply elasticsearch.auth
```
Confirm the generated file exists:
```bash
ls -l /opt/so/saltstack/local/pillar/elasticsearch/auth.sls
```
---
7. Synchronize Elasticsearch Users and Roles
Security Onion uses `so-user sync` to generate the Elasticsearch authentication files.
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
---
8. Start Elasticsearch
Apply the Elasticsearch state:
```bash
salt-call state.apply elasticsearch -l info
```
Verify the container:
```bash
docker ps -a --filter name=so-elasticsearch
```
Verify port `9200`:
```bash
ss -lntp | grep ':9200'
```
---
9. Validate Elasticsearch
Retrieve the generated `so_elastic` password:
```bash
ES_PASS=$(salt-call pillar.get \
  'elasticsearch:auth:users:so_elastic_user:pass' \
  --out=txt | awk '{print $2}')
```
Test Elasticsearch:
```bash
curl -k -u "so_elastic:$ES_PASS" \
  https://127.0.0.1:9200/
```
A successful response should identify:
```text
securityonion
```
and Elasticsearch:
```text
9.3.7
```
---
10. Start Remaining Security Onion Services
Once Elasticsearch is operational, start SOC:
```bash
salt-call state.apply soc -l info
```
Then start ElastAlert:
```bash
salt-call state.apply elastalert -l info
```
Verify both containers:
```bash
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' \
  | grep -E 'so-soc|so-elastalert'
```
---
11. Run Final Salt Convergence
Run the complete highstate:
```bash
salt-call state.highstate -l info
```
The final result should show:
```text
Succeeded: 734
Failed:      0
```
The exact state counts may vary depending on the environment, but the critical requirement is:
```text
Failed: 0
```
---
12. Final Security Onion Validation
Run:
```bash
so-status
```
All required Security Onion containers should show `running`.
The final environment should include:
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
Healthy services should report their health status where applicable.
The final `so-status` validation should conclude with:
```text
✔ This onion is ready to make your adversaries cry!
```
---
13. Final Result
Security Onion 3.2.0 is now operational with:
Embedded Docker registry restored from the ISO
Security Onion 3.2.0 container images available locally
Elasticsearch 9.3.7 running over HTTPS
Elasticsearch authentication restored
SOC running
ElastAlert running
Suricata running
Zeek running and healthy
Kibana running
Logstash running
Strelka services running
Final Salt highstate completed with zero failures
This completes the Security Onion deployment and validation phase.