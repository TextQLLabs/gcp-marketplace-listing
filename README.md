# TextQL — Google Cloud Marketplace app package

The Kubernetes app package behind the TextQL listing on Google Cloud
Marketplace: Helm chart, deployment container (deployer), deployer schema,
verification tests, and user guide.

This repository (chart, manifests, schemas, docs) is licensed under
[MIT](LICENSE). TextQL itself is a commercial, BYOL (bring your own
license) product: the container images the chart deploys are proprietary,
and a license plus deployment credentials issued by TextQL are required
for AI functionality. Contact support@textql.com.

## Layout

| Path | Purpose |
|---|---|
| `chart/textql/` | Helm chart. |
| `schema.yaml` | Deployer schema (v2): UI parameters, image substitution, generated passwords and certs. |
| `deployer/Dockerfile` | Deployment container, built on Google's `deployer_helm/onbuild` base. |
| `apptest/deployer/schema.yaml` | Verification overlay (`/data-test`): full stack at single-replica scale plus the tester Pod. |
| `docs/user-guide.md` | User guide, structured per Marketplace requirements. |
| `Makefile` | Build/push the deployer, sync and mirror images, annotate, verify, check health. |

## Registry layout

Everything lives under one product path, with the main app image at its
root and the deployer in `deployer/`, per Marketplace requirements:

```
us-docker.pkg.dev/textql-public/textql/textql-byoc-byol            # main image (compute engine)
us-docker.pkg.dev/textql-public/textql/textql-byoc-byol/deployer   # deployment container
us-docker.pkg.dev/textql-public/textql/textql-byoc-byol/<name>     # everything else
```

All images of a release carry the version tag (e.g. `1.3.20`) and the
track tag (`1.3`), plus the product service-name annotation.

## Releasing

```sh
make app-crd              # once per cluster: the Application CRD
make mirror-third-party   # valkey, postgres, tester
make push-minio           # build MinIO from source and push it
make push-deployer        # build and push the deployer
make annotate             # stamp the service-name annotation on everything
make verify               # Marketplace verification (install -> tests -> uninstall)
```

Defaults: `TAG=1.3.21`, `TRACK=1.3`. Override per invocation, e.g.
`make push-deployer TAG=1.3.22`.

`make health NAMESPACE=<ns>` summarizes an installed release: rollouts,
pods, volumes, and recent warnings.

`make verify` runs mpdev in a container that reads the kubeconfig's
current context and ships no cloud credential plugins. Point it at a
kubeconfig whose current context is the marketplace cluster and whose
user carries a static token, e.g. `KUBE_CONFIG=/path/to/kubeconfig make verify`
with `token: $(gcloud auth print-access-token)`.

## Vulnerability scan findings

Marketplace rescans every image in the schema's image map. OS package
findings on the Debian first-party images (compute engine, py-worker,
py-worker-dashboard) between releases are fixed registry-side: one
`apt-get full-upgrade` layer over the release image, re-pushed under the
same version and track tags, re-annotated, old digests pruned. The
application binary and Python environment stay those of the release
build. Findings inside statically linked third-party binaries or without
an upstream fix are reported as-is. The first-party Deployment containers
pull with `imagePullPolicy: Always` so a re-pushed tag is never shadowed
by a node's image cache.

MinIO is in the image map like everything else, and it is built from
source: MinIO publishes no container images any more and its repository is
archived, so `minio/Dockerfile` compiles the last public commit with the Go
modules the scanner flags bumped to their fixed versions, on a current Go
toolchain, into a fresh `ubi9/ubi-micro` base. The `mc` client is left out
(the chart never calls it). `make push-minio` builds and pushes it.

Python package findings in the worker images are fixed the same way as OS
packages: one `uv pip install` layer pinning the fixed version.
