# TextQL on GKE — setup

This chart runs TextQL on GKE with almost everything decided for you:
sign-in is SSO-only (OIDC), all LLM traffic goes through the TextQL console
proxy using your deployment credentials, and scheduling policy is baked in.
It is the chart behind the Google Cloud Marketplace listing and renders
entirely client-side (works with `helm template`).

Defaults are self-contained: in-cluster PostgreSQL and MinIO object
storage, secrets from values (`global.secretsMode=values`), no load
balancer, ephemeral sandbox storage. Production installs typically enable
the Gateway and pick their storage (Filestore for sandboxes, optionally a
GCS bucket instead of MinIO).

## 1. What you need first

- A **GKE cluster** with x86 (amd64) nodes. For `gateway.enabled`: the
  Gateway API. For `sandbox.filestore.enabled`: the Filestore CSI driver
  (both are on by default on Autopilot).
- The **Application CRD** (`make app-crd` in the repository root, or see
  docs/user-guide.md).
- Optional: a **Cloud SQL for PostgreSQL** instance if you prefer an
  external database (`postgres.enabled=false`, `global.db.*`).
- Object storage: in-cluster MinIO by default (the `secrets.gcsHmac*`
  values double as the root credentials). For a GCS bucket instead:
  `minio.enabled=false`, `global.gcs.bucket`, and an HMAC key
  (`gcloud storage hmac create <service-account-email>`).
- An **OIDC application** at your identity provider (redirect URI:
  `<public URL>/oidc/callback`). Sign-in only works through it.
- Your **TextQL deployment id and private key** (issued with your license).
- For HTTPS: a regional external **static IP** and a GCP **SSL certificate**.

## 2. Choose a secrets mode

### values (default)

Kubernetes Secrets are rendered from chart values. The Cloud Marketplace
deployer generates the random ones; CLI installs must set them:

| Value | Generate with |
|---|---|
| `postgres.auth.password` | `openssl rand -hex 16` |
| `secrets.valkeyPassword` | `openssl rand -hex 16` |
| `secrets.internalKey` | `openssl rand -hex 32` |
| `secrets.sandboxAuthKey` | `openssl rand -hex 32` |
| `secrets.connectorEncryptionKey` | `openssl rand -hex 16` (chart derives `k1=<base64>`) |
| `secrets.tableauInternalSecret` | `openssl rand -hex 16` |
| `secrets.authJwtPrivateKey` / `authJwtPublicKey` | Ed25519, base64 of raw key bytes (private = seed\|\|public, 64 bytes; public = 32 bytes). With OpenSSL 1.1.1+: `openssl genpkey -algorithm ed25519 -out jwt.pem`, then public: `openssl pkey -in jwt.pem -pubout -outform DER \| tail -c 32 \| base64`, private: `cat <(openssl pkey -in jwt.pem -outform DER \| tail -c 32) <(openssl pkey -in jwt.pem -pubout -outform DER \| tail -c 32) \| base64` |
| `secrets.deploymentPrivateKey` | issued by TextQL |
| `secrets.oidcClientSecret` | from your identity provider |
| `secrets.gcsHmacAccessKey` / `gcsHmacSecretKey` | from step 1 |
| `secrets.sandboxProxyCaKey` | `openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -subj "/CN=Sandbox Proxy CA" -keyout ca.key -out ca.crt`; put `base64 < ca.crt` into `global.sandboxProxy.caCert` |
| `secrets.smtpPassword` | only if `compute.smtp.host` is set |

### externalSecrets

Set `global.secretsMode=externalSecrets`. Secrets sync from GCP Secret
Manager in `global.externalSecrets.gcp.projectId` through the External
Secrets Operator, which must already be installed on the cluster (the chart
no longer bundles it). Entries are named `<remoteKeyPrefix>-<suffix>`
(default prefix `textql`): `db-password`, `db-url`, `auth-private-key`,
`auth-public-key`, `auth-key-id`, `connector-encryption-keys`,
`internal-key`, `sandbox-auth-key`, `valkey-password`,
`deployment-private-key`, `oidc-client-secret`, `gcs-hmac-access-key`,
`gcs-hmac-secret-key`, `tableau-internal-secret`, `sandbox-proxy-ca-key`,
and `smtp-password` (if SMTP is enabled). Grant the ESO identity
`roles/secretmanager.secretAccessor`, or set
`global.externalSecrets.gcp.serviceAccountRef` (plus `clusterLocation` and
`clusterName`) for Workload Identity.

## 3. Choose a database

- **In-cluster (default)**: `postgres.enabled=true` deploys PostgreSQL with
  a PersistentVolumeClaim (`postgres.storage.size`, default 64Gi). All
  components are wired to it automatically; the connection string uses
  `sslmode=disable` inside the cluster.
- **External**: `postgres.enabled=false` plus `global.db.host/port/name/
  username` and `global.db.password` (values mode) — TLS required.

## 4. Install

See docs/user-guide.md in this repository for the full walkthrough,
including the Marketplace UI flow, CLI flags, ingress/TLS, backup/restore,
updates, scaling, and deletion.

## 5. Good to know

- Every image reference is substitutable through `images.*` (full
  references, digest pinning supported); otherwise images resolve to
  `global.registry`/`<name>`:`global.imageTag`, all at one release tag.
- Cluster-scoped resources exist only when `sandbox.filestore.enabled`:
  the `filestore-<namespace>` StorageClass. Everything else is namespaced,
  so Marketplace UI installs work with namespace-scoped permissions.
- Slack, Teams, and web-search integrations are not part of this chart and
  stay disabled.
- PVC sizes: postgres `postgres.storage.size` (64Gi), valkey 32Gi, tableau
  30Gi, sandbox 1Ti on Filestore when enabled. Expand after install with
  `kubectl edit pvc`.
