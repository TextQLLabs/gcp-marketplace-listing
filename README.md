# TextQL — Google Cloud Marketplace app package

The Kubernetes app package behind the TextQL listing on Google Cloud
Marketplace: Helm chart, deployment container (deployer), deployer schema,
verification tests, and user guide.

TextQL is a commercial, BYOL (bring your own license) product — see
[LICENSE](LICENSE). A license and deployment credentials issued by TextQL
are required for AI functionality; contact support@textql.com.

## Layout

| Path | Purpose |
|---|---|
| `chart/textql/` | Helm chart. Renders client-side (`helm template` is enough), as Marketplace requires. |
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
make sync-first-party     # copy first-party images into the product path
make mirror-third-party   # valkey, kubectl, postgres, minio, tester
make push-deployer        # build and push the deployer
make annotate             # stamp the service-name annotation on everything
make verify               # Marketplace verification (install -> tests -> uninstall)
```

Defaults: `TAG=1.3.20`, `TRACK=1.3`. Override per invocation, e.g.
`make push-deployer TAG=1.3.21`. First-party images reach the flat staging
path via `scripts/gcp-marketplace-ar-push.sh` in the main TextQL repo;
`sync-first-party` copies them from there.

`make health NAMESPACE=<ns>` summarizes an installed release: rollouts,
pods, volumes, and recent warnings.
