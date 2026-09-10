# TextQL — Google Cloud Marketplace app package

This repository contains the Kubernetes app package that backs the TextQL
listing on Google Cloud Marketplace: the Helm chart, the deployment-container
(deployer) build, the deployer schema, the verification tests, and the user
guide.

TextQL is a commercial, BYOL (bring your own license) product. See
[LICENSE](LICENSE). A license and deployment credentials issued by TextQL are
required for full functionality — contact support@textql.com.

## Layout

| Path | Purpose |
|---|---|
| `chart/textql/` | Helm chart deployed on users' GKE clusters. Client-side only: works with `helm template` (no hooks or lookups required), as Marketplace requires. |
| `schema.yaml` | Deployer schema (v2): parameters collected in the Marketplace UI, image substitution map, generated passwords, deployer service-account rules. |
| `deployer/Dockerfile` | Deployment container, built on Google's `deployer_helm/onbuild` base. |
| `apptest/deployer/schema.yaml` | Verification overlay (`/data-test`): trims the install to a minimal healthy footprint and enables the tester Pod and migration Job. |
| `docs/user-guide.md` | User guide, structured per Marketplace requirements. |
| `Makefile` | Build/push the deployer, mirror third-party images, run `mpdev verify`. |
| `NEXT_STEPS.md` | What is done and what remains before the listing can go live. |

## Building and verifying

```sh
# One-time: the Application CRD on the target cluster
make app-crd

# Mirror third-party images (valkey, kubectl, postgres, tester) into the
# staging registry at the release tags
make mirror-third-party

# Build and push the deployer
make push-deployer

# Run Marketplace verification (install -> tests -> uninstall)
make verify
```

Defaults: `REGISTRY=us-docker.pkg.dev/textql-public/textql`, `TAG=1.3.20`,
`TRACK=1.3`. Override per invocation, e.g. `make push-deployer TAG=1.3.21`.

First-party images (`tql-web`, `tql-compute-engine`, `tql-py-worker`,
`tql-py-worker-dashboard`, `tql-ontology`, `textableau`) and `oathkeeper` are
mirrored into the registry by `scripts/gcp-marketplace-ar-push.sh` in the main
TextQL repository, which also applies the Marketplace product service-name
annotation and maintains the track/latest tags.
