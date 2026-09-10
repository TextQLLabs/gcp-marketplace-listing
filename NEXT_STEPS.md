# Next steps

This file uses simple language (ASD-STE100 style): short sentences, one
instruction for each sentence.

## What is done

1. **Git repository.** This repository has the full app package. The
   remote `origin` points to `TextQLLabs/gcp-marketplace-listing`. Nothing
   is pushed. You push when you are ready.
2. **Helm chart** (`chart/textql/`). It is a copy of the
   `kubernetes-gcp-mp` chart from the `sergi/gcp-marketplace` branch, with
   these changes:
   - Each resource name starts with the release name. Google requires this.
   - Each image reference is a parameter (`images.*`). Google requires this.
   - All images of one release use one version tag (`1.3.20`) and one track
     tag (`1.3`). Google requires this.
   - PostgreSQL runs in the cluster by default (`postgres.enabled=true`),
     like the k3d local mode. Set `postgres.enabled=false` and `global.db.*`
     for an external database.
   - A new secrets mode (`global.secretsMode=values`, the default) renders
     plain Kubernetes Secrets from values. The deployer generates the
     passwords. The old External Secrets mode is still there
     (`global.secretsMode=externalSecrets`). The External Secrets Operator
     dependency is removed from the chart. Install ESO yourself for that
     mode.
   - Every pod has `nodeSelector: kubernetes.io/arch: amd64` (x86 only) and
     `sidecar.istio.io/inject: "false"`. The schema declares Istio as
     UNSUPPORTED. No Istio resources exist.
   - The chart renders fully client-side. `helm template` is enough. There
     are no lookups and no required server-side hooks.
   - The Gateway (load balancer) and the Filestore sandbox storage are off
     by default. Marketplace UI installs run with namespace permissions
     only, and these two features need more. Enable them after install with
     `helm upgrade`. The user guide shows how.
   - The `Application` resource describes the app in the GKE UI.
3. **Deployer image** (`deployer/Dockerfile`, `schema.yaml`). Built on
   Google's `deployer_helm/onbuild` base image. Pushed to
   `us-docker.pkg.dev/textql-public/textql/deployer:1.3.20` and `:1.3`.
   The schema collects the UI parameters, generates the passwords, and
   substitutes the images.
4. **Verification tests** (`apptest/deployer/schema.yaml`,
   `chart/textql/templates/tests/tester.yaml`). In test mode the package
   installs the full stack: PostgreSQL, Valkey, **compute-engine** (with the
   real database migrations in its init container), **ontology**,
   **tableau-engine**, web, oathkeeper, and MinIO, at single-replica scale.
   The tester Pod checks the health endpoints of web, oathkeeper,
   compute-engine, ontology, and MinIO. Compute-engine runs with a
   placeholder deployment id (a valid UUID that TextQL never issued) and a
   throwaway generated ed25519 deployment key: it parses them locally at
   startup, so the service is healthy; only real LLM calls would fail.
   `mpdev verify` result: see the bottom of this file.
5. **In-cluster S3 (MinIO).** `minio.enabled` deploys a single-node MinIO
   and points compute-engine and web at it. This works because the
   compute-engine S3 client always uses path-style addressing and takes its
   endpoint from `AWS_ENDPOINT`. The bucket is created automatically. It is
   for evaluation and verification; production installs should use a GCS
   bucket.
6. **Third-party images.** `valkey`, `kubectl`, `postgres`, `minio`, and
   `tester` are mirrored to `us-docker.pkg.dev/textql-public/textql/*` at
   tags `1.3.20` and `1.3` (`make mirror-third-party`).
7. **Image annotations.** The mirrored images and the deployer have the
   `com.googleapis.cloudmarketplace.product.service.name` annotation
   (`make annotate`). The first-party images got it from
   `scripts/gcp-marketplace-ar-push.sh` in the main repository.
8. **License** (`LICENSE`). A restrictive commercial license. It does not
   permit unauthorized use.
9. **User guide** (`docs/user-guide.md`). It has all sections that Google
   requires: overview, one-time setup, installation, usage, backup and
   restore, image updates, scaling, and deletion.

## What you must still do

1. **Push this repository.** Run `git push -u origin main`. Google wants a
   public repository. Decide if you make it public.
2. **Check the license text with legal counsel.** Google's page asks for an
   open-source license for the repository. Your instruction was a
   restrictive commercial license. These two points conflict. Your Partner
   Engineer can confirm what is acceptable for a BYOL listing.
3. **Confirm the product service name.** The images use the annotation
   `services/textql-byoc-listing.endpoints.textql-public.cloud.goog`. Check
   this value in Producer Portal, on the Overview page, in the Service name
   column. Fix `Makefile` and `scripts/gcp-marketplace-ar-push.sh` if it is
   different.
4. **Confirm the image layout with your Partner Engineer.** Google's page
   says the main app image must sit at the root of the repository path, and
   the deployer in a `deployer` folder. Artifact Registry cannot hold an
   image at the bare repository root. Ask how to map this rule to
   `us-docker.pkg.dev/textql-public/textql`.
5. **Test one real production install.** Verification now runs the full
   stack (compute-engine, ontology, tableau, web, oathkeeper, PostgreSQL,
   Valkey, MinIO) and all pods become ready. What verification cannot
   prove, because it needs real accounts:
   - **Sign-in.** Needs a real OIDC provider. Configure OIDC and confirm
     that you can log in.
   - **AI features.** Need a real TextQL deployment id and key.
     Verification uses a placeholder id, so LLM calls fail at runtime.
   - **Pre-spawned sandbox workers.** The spawned worker pods mount the
     fixed-name PVC `sandbox-files-pvc`, which needs Filestore
     (ReadWriteMany) and a cluster-scoped StorageClass. Verification cannot
     create those, so the pool minimums are 0 there. Enable
     `sandbox.filestore.enabled` in a real install and confirm workers
     start.
6. **Decide the storage defaults.** Sandbox files use emptyDir and MinIO is
   off by default. Both are evaluation trade-offs: emptyDir is not durable,
   and MinIO is a single node. Production installs should enable Filestore
   and use a GCS bucket. The user guide says this. Confirm these defaults.
7. **Submit in Producer Portal.** Upload the deployer path
   (`us-docker.pkg.dev/textql-public/textql/deployer:1.3.20`), attach the
   user guide link, and complete the listing content (descriptions, icons,
   pricing, BYOL terms). Then send the app for Google review.
8. **Automate releases.** Today the flow is manual: run
   `scripts/gcp-marketplace-ar-push.sh` in the main repository, then `make
   mirror-third-party push-deployer annotate verify` here, for each new
   release. Consider a CI job.
9. **Optional: least-privilege RBAC review.** The deployer service account
   rules in `schema.yaml` are broad (namespaced `*` verbs on the kinds the
   chart uses). Narrow them if review asks for it.

## Verification result

`mpdev verify --deployer=us-docker.pkg.dev/textql-public/textql/deployer:1.3.20`
against cluster `gke-autopilot-marketplace` (project `textql-public`),
2026-09-10: **PASSED**.

The run did these steps: it created a test namespace, deployed the app,
waited until PostgreSQL, Valkey, web, and oathkeeper were healthy, ran the
database migration Job (468+ real migrations against the in-cluster
PostgreSQL), ran the tester Pod (web `/api/health` and oathkeeper
`/health/alive` returned success), and removed the app and the namespace.

To run it again: `make verify`.
