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
   `chart/textql/templates/tests/tester.yaml`,
   `chart/textql/templates/jobs/db-migrate-job.yaml`). In test mode the
   package installs PostgreSQL, Valkey, web, and oathkeeper. A Job runs the
   real database migrations. A tester Pod checks the web and oathkeeper
   health endpoints. `mpdev verify` result: see the line at the bottom of
   this file.
5. **Third-party images.** `valkey`, `kubectl`, `postgres`, and `tester`
   are mirrored to `us-docker.pkg.dev/textql-public/textql/*` at tags
   `1.3.20` and `1.3` (`make mirror-third-party`).
6. **Image annotations.** The mirrored images and the deployer have the
   `com.googleapis.cloudmarketplace.product.service.name` annotation
   (`make annotate`). The first-party images got it from
   `scripts/gcp-marketplace-ar-push.sh` in the main repository.
7. **License** (`LICENSE`). A restrictive commercial license. It does not
   permit unauthorized use.
8. **User guide** (`docs/user-guide.md`). It has all sections that Google
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
5. **Test a full production install.** Verification runs a reduced
   footprint (no compute-engine, ontology, or tableau). Do one real install
   with a TextQL deployment id, a deployment key, OIDC, JWT keys, and a GCS
   bucket. Confirm that every pod becomes ready and that you can sign in.
6. **Decide the sandbox storage default.** Sandbox files use emptyDir when
   `sandbox.filestore.enabled=false`. This is fine for evaluation. It is
   not durable. Production installs must enable Filestore. The user guide
   says this. Confirm this trade-off.
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

`mpdev verify` against cluster `gke-autopilot-marketplace` (project
`textql-public`): PENDING — see final line of the session summary.
