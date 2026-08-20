Step 5 — Complete and Validate Security Onion 3.2.0
This is the final deployment and validation step.
At this point, the Security Onion system has already been installed, but several behind-the-scenes components still need to be connected and verified. Think of this stage as the point where we make sure all of the "moving parts" are not only installed, but actually working together.
You will see quite a few Linux and Docker commands below. You do not need to be a Linux expert to follow the process. Each section explains what we are doing, why we are doing it, and what a successful result looks like.
---
1. Restore the Offline Docker Registry
Why are we doing this?
Security Onion uses Docker containers for many of its services. Those containers are normally obtained from a registry.
In this lab, the system could not reach the Internet during installation, so the local Security Onion registry was not fully populated.
Fortunately, the Security Onion ISO already contains the registry data we need.
The two important files are:
```text
/docker/registry.tar
/docker/registry_image.tar
```
The large `registry.tar` file contains the actual Security Onion container data. The smaller `registry_image.tar` contains the Docker image used to run the registry itself.
Mount the Security Onion ISO
Create a temporary location where we can access the ISO:
```bash
mkdir -p /mnt/securityonion-iso
mount -o ro /dev/sr0 /mnt/securityonion-iso
```
The `-o ro` option means read-only. We are only reading from the ISO; we are not changing it.
Check that the registry files are there:
```bash
ls -lh /mnt/securityonion-iso/docker/
```
You should see:
```text
registry.tar
registry_image.tar
```
---
2. Copy the Registry Files into Security Onion
Why are we doing this?
The Security Onion installer expects the local registry content to be stored under:
```text
/nsm/docker-registry/docker/
```
Create the directory if necessary:
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
You should see both files.
---
3. Verify That the Files Were Not Corrupted
Why are we checking hashes?
Copying a file does not automatically prove that it arrived intact.
A SHA-256 hash is like a digital fingerprint for a file. If the source and destination hashes are identical, the files are identical.
Run:
```bash
sha256sum /mnt/securityonion-iso/docker/registry.tar
sha256sum /nsm/docker-registry/docker/registry.tar
```
The two values should match.
Do the same for the registry image:
```bash
sha256sum /mnt/securityonion-iso/docker/registry_image.tar
sha256sum /nsm/docker-registry/docker/registry_image.tar
```
Again, the two values should match.
This gives us confidence that the registry files were copied correctly before we depend on them.
---
4. Confirm the Registry Archive Contains Real Docker Registry Data
Before trying to start anything, inspect the archive:
```bash
tar -tf /nsm/docker-registry/docker/registry.tar | head -30
```
You should see entries beginning with:
```text
registry/
registry/v2/
```
This confirms that the archive is actually a Docker Registry data set rather than an empty or unrelated archive.
---
5. Load the Embedded Registry Image
The `registry_image.tar` file contains the Docker image needed to run Security Onion's local registry.
Load it:
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
What does this mean?
This image is not the Security Onion application itself. It is the local service that stores and serves the other Security Onion Docker images.
---
6. Rebuild the Embedded Registry
Now let Security Onion configure the registry using its normal SaltStack process:
```bash
salt-call state.apply registry queue=True
```
Check that the registry container is running:
```bash
docker ps -a --filter name=so-dockerregistry
```
A successful result should show:
```text
so-dockerregistry
```
with a running status.
Test the registry directly:
```bash
curl -sk https://127.0.0.1:5000/v2/
```
A healthy registry should return:
```text
{}
```
That small `{}` response is actually a good sign: it means the registry answered the request successfully.
---
7. Confirm the Security Onion Images Are Available
Now that the registry is running, we can ask it what it contains.
List the repositories:
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
Check the application image versions:
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
Why does this matter?
This confirms that the local registry contains the correct version of the software we are trying to deploy.
---
8. Repair Elasticsearch Authentication
What happened?
Security Onion's SOC configuration expected Elasticsearch authentication information, but the required authentication data was missing.
This caused Salt/Jinja rendering errors such as:
```text
Jinja variable 'dict object' has no attribute 'auth'
```
In plain English, the system was effectively saying:
> "I know I need Elasticsearch credentials, but I cannot find the credentials data I was expecting."
The correct approach is to let Security Onion generate that information using its own Salt state.
Check the authentication pillar:
```bash
salt-call pillar.get elasticsearch:auth --out=yaml
```
If the authentication data is missing, run:
```bash
salt-call state.apply elasticsearch.auth
```
Confirm the file was created:
```bash
ls -l /opt/so/saltstack/local/pillar/elasticsearch/auth.sls
```
---
9. Synchronize Elasticsearch Users and Roles
Elasticsearch needs more than a password stored in Salt. Security Onion also generates the user and role files used by Elasticsearch.
The Security Onion utility that performs this synchronization is:
```text
so-user sync
```
Run:
```bash
so-user sync
```
You should see messages indicating that users and roles are being synchronized.
Now verify the generated files:
```bash
ls -lah \
  /opt/so/saltstack/local/salt/elasticsearch/files/users \
  /opt/so/saltstack/local/salt/elasticsearch/files/users_roles \
  /opt/so/conf/soc/soc_users_roles
```
You should also see the active Elasticsearch copies:
```bash
ls -lah \
  /opt/so/conf/elasticsearch/users \
  /opt/so/conf/elasticsearch/users_roles
```
Why does this step matter?
These files were one of the key missing dependencies that prevented the Elasticsearch container from starting.
Once they exist, Salt has everything it needs to build the Elasticsearch container correctly.
---
10. Start Elasticsearch
Now apply the Elasticsearch state:
```bash
salt-call state.apply elasticsearch -l info
```
Check the container:
```bash
docker ps -a --filter name=so-elasticsearch
```
You should see:
```text
so-elasticsearch
```
Check that port `9200` is listening:
```bash
ss -lntp | grep ':9200'
```
---
11. Test Elasticsearch Directly
Why test it manually?
A container showing "running" does not always mean the application inside it is ready.
We therefore test Elasticsearch itself.
Get the generated `so_elastic` password:
```bash
ES_PASS=$(salt-call pillar.get \
  'elasticsearch:auth:users:so_elastic_user:pass' \
  --out=txt | awk '{print $2}')
```
Then query Elasticsearch:
```bash
curl -k -u "so_elastic:$ES_PASS" \
  https://127.0.0.1:9200/
```
A successful response should identify the Security Onion node and show Elasticsearch:
```text
9.3.7
```
A valid response should look similar to:
```json
{
  "name" : "securityonion",
  "cluster_name" : "securityonion",
  "version" : {
    "number" : "9.3.7"
  }
}
```
At this point, Elasticsearch is not just "running" — it is actually answering authenticated HTTPS requests.
---
12. Start SOC and ElastAlert
Once Elasticsearch is working, the remaining higher-level Security Onion services can be brought online.
Start SOC:
```bash
salt-call state.apply soc -l info
```
Then start ElastAlert:
```bash
salt-call state.apply elastalert -l info
```
Verify both:
```bash
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' \
  | grep -E 'so-soc|so-elastalert'
```
You should see both services in a running state.
---
13. Run a Final SaltStack Highstate
What is a highstate?
SaltStack is Security Onion's configuration-management system.
A highstate tells Salt:
> "Compare the system to the configuration Security Onion expects, and make any required corrections."
Run:
```bash
salt-call state.highstate -l info
```
This may take several minutes.
What are we looking for?
At the end, you want:
```text
Failed:      0
```
In the completed deployment, the final result was:
```text
Succeeded: 734 (changed=34)
Failed:      0
```
This is important because it shows that the configuration system successfully converged instead of simply leaving a collection of manually started containers behind.
---
14. Perform the Final Security Onion Health Check
Run:
```bash
so-status
```
This is the easiest final health check because Security Onion summarizes the status of the major containers for you.
The final environment should show services such as:
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
The important part is that the required services are reported as:
```text
running
```
and health checks that exist are reporting healthy status where appropriate.
The successful deployment should conclude with:
```text
✔ This onion is ready to make your adversaries cry!
```
---
15. What We Accomplished
This final step involved more than simply clicking through an installer.
We:
Recovered the offline Docker registry from the Security Onion ISO.
Verified that the registry files were copied correctly.
Confirmed the local registry contained the correct Security Onion 3.2.0 images.
Repaired missing Elasticsearch authentication data.
Regenerated Elasticsearch users and roles.
Successfully brought Elasticsearch 9.3.7 online.
Validated Elasticsearch through an authenticated HTTPS request.
Started SOC and ElastAlert.
Ran a complete SaltStack highstate.
Finished with zero failed Salt states.
Confirmed the complete Security Onion service stack with `so-status`.
---
16. Final Result
The Security Onion 3.2.0 standalone deployment is now operational.
The completed platform provides:
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
   │     │
   └──┬──┘
      ▼
Security Monitoring
Detection & Investigation
```
The final validation confirms that the platform is not only installed, but that its major components are communicating and operating together as intended.
Final Check
Run one last time:
```bash
so-status
```
If all required services are running and Security Onion reports:
```text
✔ This onion is ready to make your adversaries cry!
```
the deployment is complete.