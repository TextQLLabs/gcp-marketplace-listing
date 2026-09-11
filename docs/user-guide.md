# TextQL on Google Kubernetes Engine — user guide

## Overview

TextQL builds the Ontology for LLMs to talk to your data, accurately and
securely. This app deploys the full TextQL platform onto your own GKE
cluster:

- **web** — the TextQL web application.
- **compute-engine** — the core API and orchestration service; it runs
  database migrations, manages AI analyst sessions, and spawns sandboxed
  Python workers for data analysis and dashboards.
- **ontology** — the ontology service.
- **tableau-engine** — the Tableau/BI connector engine.
- **oathkeeper** — the authentication proxy in front of the API.
- **postgres** — an in-cluster PostgreSQL database (default), or bring your
  own (e.g. Cloud SQL for PostgreSQL over private IP).
- **valkey** — in-cluster cache/queue.
- **minio** (default) — a single-node in-cluster S3-compatible object
  store so file features work out of the box. Heavy production use can
  switch to a GCS bucket (`minio.enabled=false`, `global.gcs.bucket` plus
  an HMAC key in `secrets.gcsHmac*`).

TextQL is a **commercial, BYOL (bring your own license)** product. The app
installs and starts without credentials, but AI features require a
deployment id and private key issued by TextQL with your license, and
sign-in requires an OIDC identity provider. Contact support@textql.com.

Configuration options are described in the chart's
[values.yaml](../chart/textql/values.yaml) and [SETUP.md](../chart/textql/SETUP.md).

Marketplace listing: once published, the product page will be at
`https://console.cloud.google.com/marketplace/product/textql-public/textql`
(link is final after the listing is approved).

Product documentation: https://docs.textql.com

## One-time setup

### Configure client tools

You need `kubectl`, `helm` (v3+), and `gcloud`:

```sh
gcloud auth login
gcloud container clusters get-credentials CLUSTER --location LOCATION --project PROJECT
kubectl config current-context   # verify it points at the intended cluster
```

The cluster must run x86 (amd64) nodes — GKE Standard and Autopilot default
node pools qualify. Istio sidecar injection is not supported; the app
disables injection on its pods.

### Install the Application CRD

The app is grouped under an `Application` custom resource. Install its CRD
once per cluster:

```sh
kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
```

### Acquire your TextQL license (BYOL)

1. Contact support@textql.com (or your TextQL account team) to obtain a
   license, a **deployment id**, and a **deployment private key**.
2. Provide them at install time (`compute.deploymentId`,
   `secrets.deploymentPrivateKey`), or add them after install with
   `helm upgrade` — see [Basic usage](#basic-usage).

No Marketplace usage-reporting Secret is needed: the product is BYOL and
does not meter usage through Google.

## Installation

### From the Google Cloud Marketplace UI

Select the app in the Marketplace catalog, pick the cluster, namespace, and
app instance name, fill in the optional parameters (public URL, hostname,
OIDC settings, TextQL license credentials), and deploy. Passwords and
internal keys are generated automatically.

### Quick evaluation install (command line)

The shortest path to a running deployment — no sign-in, no TextQL
credentials, MinIO for storage, and a single-node volume so a sandbox
worker can run:

```sh
NAME=textql
NAMESPACE=textql
kubectl create namespace "$NAMESPACE"

# Ed25519 keys, base64 of the raw bytes: a session-JWT pair, plus a
# throwaway deployment key so compute-engine can start (AI features need
# real TextQL credentials). macOS LibreSSL cannot generate ed25519; this
# uses python instead.
read -r JWT_PRIV JWT_PUB DEPLOY_KEY <<< "$(python3 -c '
import base64
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization as s
def gen():
    k = Ed25519PrivateKey.generate()
    seed = k.private_bytes(s.Encoding.Raw, s.PrivateFormat.Raw, s.NoEncryption())
    pub = k.public_key().public_bytes(s.Encoding.Raw, s.PublicFormat.Raw)
    return base64.b64encode(seed + pub).decode(), base64.b64encode(pub).decode()
jp, jpub = gen(); dp, _ = gen()
print(jp, jpub, dp)')"

# Sandbox proxy CA (required for compute-engine to launch workers)
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt \
  -days 3650 -subj "/CN=TextQL Sandbox Proxy CA" 2>/dev/null

helm install "$NAME" ./chart/textql -n "$NAMESPACE" \
  --set postgres.auth.password="$(openssl rand -hex 16)" \
  --set secrets.valkeyPassword="$(openssl rand -hex 16)" \
  --set secrets.internalKey="$(openssl rand -hex 32)" \
  --set secrets.sandboxAuthKey="$(openssl rand -hex 32)" \
  --set secrets.connectorEncryptionKey="$(openssl rand -hex 16)" \
  --set secrets.tableauInternalSecret="$(openssl rand -hex 16)" \
  --set secrets.gcsHmacAccessKey="$(openssl rand -hex 10)" \
  --set secrets.gcsHmacSecretKey="$(openssl rand -hex 20)" \
  --set secrets.authJwtPrivateKey="$JWT_PRIV" \
  --set secrets.authJwtPublicKey="$JWT_PUB" \
  --set global.sandboxProxy.caCert="$(base64 < ca.crt | tr -d '\n')" \
  --set secrets.sandboxProxyCaKey="$(base64 < ca.key | tr -d '\n')" \
  --set compute.deploymentId="00000000-0000-4000-8000-000000000000" \
  --set secrets.deploymentPrivateKey="$DEPLOY_KEY" \
  --set sandbox.rwoPvc.enabled=true

make health NAMESPACE="$NAMESPACE"    # or watch it in k9s
```

Sign-in and AI features stay disabled until OIDC and the TextQL deployment
credentials are configured (sections below).

### Full install (command line)

Clone this repository, then:

```sh
NAME=textql
NAMESPACE=textql
kubectl create namespace "$NAMESPACE"

# Sandbox proxy CA (compute-engine requires it to launch sandbox workers;
# the Marketplace UI generates it automatically)
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout ca.key -out ca.crt -days 3650 -subj "/CN=TextQL Sandbox Proxy CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

helm install "$NAME" ./chart/textql \
  --namespace "$NAMESPACE" \
  --set web.publicApi="https://textql.yourcompany.com" \
  --set global.hostname="textql.yourcompany.com" \
  --set postgres.auth.password="$(openssl rand -hex 16)" \
  --set secrets.valkeyPassword="$(openssl rand -hex 16)" \
  --set secrets.internalKey="$(openssl rand -hex 32)" \
  --set secrets.sandboxAuthKey="$(openssl rand -hex 32)" \
  --set secrets.connectorEncryptionKey="$(openssl rand -hex 16)" \
  --set secrets.tableauInternalSecret="$(openssl rand -hex 16)" \
  --set global.sandboxProxy.caCert="$(base64 < ca.crt | tr -d '\n')" \
  --set secrets.sandboxProxyCaKey="$(base64 < ca.key | tr -d '\n')"
```

The chart renders entirely client-side (it also works with
`helm template ... | kubectl apply -f -`); no server-side hooks or lookups
are required.

Key parameters (all settable in the UI or via `--set`):

| Parameter | Meaning | Default |
|---|---|---|
| `web.publicApi` | Public URL the app is served on | `https://textql.example.com` |
| `global.hostname` | Hostname for routing/CORS | `textql.example.com` |
| `postgres.enabled` | In-cluster PostgreSQL | `true` |
| `global.db.*` | External PostgreSQL (when `postgres.enabled=false`) | — |
| `compute.deploymentId` / `secrets.deploymentPrivateKey` | TextQL BYOL credentials | empty |
| `global.auth.oidc.*` / `secrets.oidcClientSecret` | OIDC single sign-on | empty |
| `secrets.authJwtPrivateKey` / `secrets.authJwtPublicKey` | Session JWT EC P-256 key pair | empty |
| `gateway.enabled` | GKE Gateway (external load balancer) | `false` |
| `minio.enabled` | In-cluster object storage | `true` |
| `computeEngine.poolSize` / `computeEngine.minWorkersAvailable.*` | Sandbox worker pool sizing | `256` / `10`,`2` |
| `sandbox.filestore.enabled` | Filestore-backed shared sandbox storage | `false` |
| `global.secretsMode` | `values` or `externalSecrets` | `values` |

The full list is documented in [values.yaml](../chart/textql/values.yaml).

### Pinning image references to immutable digests

For production, pin every image to a digest. Resolve the digest of each
image at your release tag and pass it as a full-reference override:

```sh
IMG=us-docker.pkg.dev/textql-public/textql/textql-byoc-byol/tql-web:1.3.20
DIGEST=$(docker manifest inspect -v "$IMG" | jq -r '.Descriptor.digest' | head -1)
helm upgrade "$NAME" ./chart/textql -n "$NAMESPACE" --reuse-values \
  --set images.web="us-docker.pkg.dev/textql-public/textql/textql-byoc-byol/tql-web@${DIGEST}"
```

Repeat for `images.computeEngine`, `images.pyWorker`,
`images.pyWorkerDashboard`, `images.ontology`, `images.textableau`,
`images.oathkeeper`, `images.valkey`, `images.kubectl`, `images.postgres`,
and `images.minio`.

## Basic usage

### Connect to the app

Without a load balancer, port-forward:

```sh
kubectl port-forward -n "$NAMESPACE" "svc/${NAME}-web" 8080:80
# open http://localhost:8080
```

Check health from a client tool:

```sh
curl -s http://localhost:8080/api/health
```

### Enable ingress and TLS

The chart ships a GKE Gateway (regional external load balancer). Reserve a
regional static IP and create a GCP SSL certificate for your hostname, then:

```sh
helm upgrade "$NAME" ./chart/textql -n "$NAMESPACE" --reuse-values \
  --set gateway.enabled=true \
  --set global.loadBalancer.staticIP="STATIC_IP_NAME" \
  --set global.loadBalancer.sslCertificate="SSL_CERT_NAME"

kubectl get gateway -n "$NAMESPACE" "${NAME}-gateway"   # LB address
```

Point your DNS record at the Gateway address. Without a certificate the app
is served over plain HTTP.

### Configure sign-in (usernames and passwords)

Sign-in is SSO-only through your OIDC identity provider; users and
credentials are managed in the identity provider, not in TextQL. Create an
OIDC application (redirect URI `https://<your hostname>/oidc/callback`),
generate the session JWT key pair, then:

The session JWT keys are Ed25519, passed as base64 of the raw key bytes
(private = 64-byte seed followed by public; public = 32 bytes). Generate
them with OpenSSL 1.1.1+ (macOS LibreSSL does not support ed25519):

```sh
openssl genpkey -algorithm ed25519 -out jwt.pem
JWT_PUB=$(openssl pkey -in jwt.pem -pubout -outform DER | tail -c 32 | base64)
JWT_PRIV=$(cat <(openssl pkey -in jwt.pem -outform DER | tail -c 32) \
               <(openssl pkey -in jwt.pem -pubout -outform DER | tail -c 32) | base64)

helm upgrade "$NAME" ./chart/textql -n "$NAMESPACE" --reuse-values \
  --set global.auth.oidc.providerType="generic" \
  --set global.auth.oidc.issuerUrl="https://YOUR_ISSUER" \
  --set global.auth.oidc.clientId="CLIENT_ID" \
  --set secrets.oidcClientSecret="CLIENT_SECRET" \
  --set secrets.authJwtPrivateKey="$JWT_PRIV" \
  --set secrets.authJwtPublicKey="$JWT_PUB"
```

To rotate any generated password or key, run `helm upgrade --reuse-values`
with the new value; the affected pods restart automatically. The in-cluster
PostgreSQL password is fixed at first initialization — to change it, alter
it in PostgreSQL first (`ALTER USER textql PASSWORD ...`), then set the new
value in the chart.

### Attach your TextQL license

```sh
helm upgrade "$NAME" ./chart/textql -n "$NAMESPACE" --reuse-values \
  --set compute.deploymentId="DEPLOYMENT_ID" \
  --set-file secrets.deploymentPrivateKey=deployment.key
```

### Object storage

File uploads, exports, and report assets need S3-compatible object storage.
Two options:

- **GCS (production):** create a bucket and an HMAC key
  (`gcloud storage hmac create <service-account-email>`), then set
  `global.gcs.bucket`, `secrets.gcsHmacAccessKey`, and
  `secrets.gcsHmacSecretKey`.
- **In-cluster MinIO (default):** the `secrets.gcsHmac*` values double as
  the MinIO root credentials and the bucket (`minio.bucket`, default
  `textql`) is created automatically. Data lives on a single
  PersistentVolumeClaim.

### Sandbox workers and outbound email

Pre-spawned sandbox workers require the shared Filestore volume: enable
`sandbox.filestore.enabled` (with `compute.gke.filestoreNetwork`) and raise
`computeEngine.minWorkersAvailable.hard` back to its default. Outbound email
(invites, shared reports) sends once `compute.smtp.host` and
`secrets.smtpPassword` are set; until then sends fail without affecting the
rest of the app.

## Back up and restore

Application state lives in PostgreSQL (and, if configured, the GCS bucket).

### In-cluster PostgreSQL (default)

Back up:

```sh
kubectl exec -n "$NAMESPACE" "deploy/${NAME}-postgres" -- \
  sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -F c' > textql-backup.dump
```

Restore (into a fresh install with an empty database):

```sh
kubectl exec -i -n "$NAMESPACE" "deploy/${NAME}-postgres" -- \
  sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' < textql-backup.dump
kubectl rollout restart -n "$NAMESPACE" \
  "deploy/${NAME}-compute-engine" "deploy/${NAME}-web" "deploy/${NAME}-ontology"
```

### External database

Use your database's native tooling (e.g. Cloud SQL automated backups and
point-in-time recovery).

Files stored in the GCS bucket are backed up with normal GCS tooling
(versioning, `gcloud storage cp -r`).

## Image updates

Releases are published under a release track (e.g. `1.3`) with immutable
version tags (e.g. `1.3.20`). To update to a new patch version:

```sh
helm upgrade "$NAME" ./chart/textql -n "$NAMESPACE" --reuse-values \
  --set global.imageTag="1.3.21"
```

(If you pinned per-image digests via `images.*`, update those instead.)
Deployments roll one pod at a time; compute-engine runs database migrations
in an init container before new pods serve traffic.

## Scaling

Stateless components scale horizontally:

```sh
helm upgrade "$NAME" ./chart/textql -n "$NAMESPACE" --reuse-values \
  --set web.replicas=5 --set oathkeeper.replicas=5 --set computeEngine.replicas=3
```

PostgreSQL, Valkey, and the Tableau engine are single-replica by design.
Their volumes can be expanded after install (`kubectl edit pvc`), and the
sandbox worker pools are sized via the compute-engine environment (POOL_SIZE
et al.) baked into the chart.

## Deletion

```sh
helm uninstall "$NAME" -n "$NAMESPACE"
```

If you installed from the Marketplace UI, delete the Application from the
"Applications" page in the GKE console instead, or:

```sh
kubectl delete application "$NAME" -n "$NAMESPACE"
```

`helm uninstall` deletes the chart-managed PersistentVolumeClaims and
their data — back up first (see above). Clean up what remains:

```sh
# Any claims left over from an interrupted uninstall
kubectl delete pvc -n "$NAMESPACE" -l "app.kubernetes.io/name=$NAME"

# Dynamically created sandbox worker pods and their token secret, if any.
# (CLI installs can automate this with --set sandboxPodCleaner.enabled=true,
# which adds a pre-delete helm hook; Marketplace installs cannot, because
# the Marketplace deployer does not support helm lifecycle hooks.)
kubectl delete pod -n "$NAMESPACE" -l 'worker-type in (sandbox,dashboard)'
kubectl delete secret -n "$NAMESPACE" sandbox-proxy-worker-tokens --ignore-not-found

# If sandbox.filestore.enabled was used: the cluster-scoped StorageClass
kubectl delete storageclass "filestore-$NAMESPACE" --ignore-not-found

# The namespace, if dedicated
kubectl delete namespace "$NAMESPACE"
```
