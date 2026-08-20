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