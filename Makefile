# Build and publish the TextQL Cloud Marketplace app package.
#
# Registry layout (what Marketplace expects): the main app image lives at
# REGISTRY itself, the deployment container under REGISTRY/deployer, and
# every other image in its own folder under REGISTRY. All images of a
# release carry the version tag (TAG) and the track tag (TRACK).

REGISTRY ?= us-docker.pkg.dev/textql-public/textql/textql-byoc-byol
TAG      ?= 1.3.21
TRACK    ?= 1.3
PLATFORM ?= linux/amd64

KUBE_CONTEXT ?= gke_textql-public_us-central1_gke-autopilot-marketplace
NAMESPACE    ?= textql

# First-party images built by the main repo's release pipeline and pushed
# to the flat staging path; sync-first-party copies them under REGISTRY.
UPSTREAM = us-docker.pkg.dev/textql-public/textql
FIRST_PARTY = tql-web tql-py-worker tql-py-worker-dashboard tql-ontology textableau oathkeeper

# Third-party images mirrored so a release is fully self-contained.
MIRROR_SPECS = \
	valkey=docker.io/valkey/valkey:8.1-alpine \
	kubectl=docker.io/bitnamilegacy/kubectl:1.33 \
	postgres=docker.io/pgvector/pgvector:pg17 \
	minio=docker.io/bitnamilegacy/minio:latest \
	tester=docker.io/curlimages/curl:8.11.1

# Product service name from Producer Portal; stamped on every image
# manifest (required by Marketplace).
SERVICE_NAME_ANNOTATION = com.googleapis.cloudmarketplace.product.service.name=services/textql-byoc-byol.endpoints.textql-public.cloud.goog
ANNOTATE_IMAGES = tql-web tql-py-worker tql-py-worker-dashboard tql-ontology textableau oathkeeper valkey kubectl postgres minio tester deployer

.PHONY: deployer push-deployer sync-first-party mirror-third-party annotate app-crd verify health

deployer:
	docker build --platform $(PLATFORM) \
	  --build-arg REGISTRY=$(REGISTRY) \
	  --build-arg TAG=$(TAG) \
	  -f deployer/Dockerfile \
	  -t $(REGISTRY)/deployer:$(TAG) .
	docker tag $(REGISTRY)/deployer:$(TAG) $(REGISTRY)/deployer:$(TRACK)

push-deployer: deployer
	docker push $(REGISTRY)/deployer:$(TAG)
	docker push $(REGISTRY)/deployer:$(TRACK)

# Server-side copies from the flat staging path into the product layout.
# The main app image (compute engine) lands at REGISTRY itself. Requires
# gcrane (go install github.com/google/go-containerregistry/cmd/gcrane@latest).
sync-first-party:
	@for tag in $(TAG) $(TRACK); do \
	  echo "==> $(UPSTREAM)/tql-compute-engine:$$tag -> $(REGISTRY):$$tag"; \
	  gcrane cp $(UPSTREAM)/tql-compute-engine:$$tag $(REGISTRY):$$tag >/dev/null || exit 1; \
	  for img in $(FIRST_PARTY); do \
	    echo "==> $(UPSTREAM)/$$img:$$tag -> $(REGISTRY)/$$img:$$tag"; \
	    gcrane cp $(UPSTREAM)/$$img:$$tag $(REGISTRY)/$$img:$$tag >/dev/null || exit 1; \
	  done; \
	done

mirror-third-party:
	@for spec in $(MIRROR_SPECS); do \
	  name=$${spec%%=*}; src=$${spec#*=}; \
	  echo "==> $$src -> $(REGISTRY)/$$name:$(TAG)"; \
	  docker pull --platform $(PLATFORM) $$src && \
	  docker tag $$src $(REGISTRY)/$$name:$(TAG) && \
	  docker tag $$src $(REGISTRY)/$$name:$(TRACK) && \
	  docker push $(REGISTRY)/$$name:$(TAG) && \
	  docker push $(REGISTRY)/$$name:$(TRACK) || exit 1; \
	done

annotate:
	@for tag in $(TAG) $(TRACK); do \
	  echo "==> annotate $(REGISTRY):$$tag"; \
	  gcrane mutate -a "$(SERVICE_NAME_ANNOTATION)" $(REGISTRY):$$tag -t $(REGISTRY):$$tag >/dev/null || exit 1; \
	  for img in $(ANNOTATE_IMAGES); do \
	    echo "==> annotate $(REGISTRY)/$$img:$$tag"; \
	    gcrane mutate -a "$(SERVICE_NAME_ANNOTATION)" $(REGISTRY)/$$img:$$tag -t $(REGISTRY)/$$img:$$tag >/dev/null || exit 1; \
	  done; \
	done

# The Application CRD must exist on the cluster before installing the app.
app-crd:
	kubectl --context $(KUBE_CONTEXT) apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml

# Marketplace verification: install -> tester Pod -> uninstall. Requires
# mpdev (marketplace-k8s-app-tools).
verify:
	mpdev verify --deployer=$(REGISTRY)/deployer:$(TAG)

# Health of an installed release: rollout state, pods, volumes, and any
# recent warnings.
health:
	@echo "== deployments =="
	@kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) get deploy -o wide
	@echo "\n== pods =="
	@kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) get pods
	@echo "\n== pvcs =="
	@kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) get pvc
	@echo "\n== not ready =="
	@kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) get pods --no-headers | awk '$$3 != "Running" && $$3 != "Completed" {print} $$3 == "Running" {split($$2, r, "/"); if (r[1] != r[2]) print}' | grep . || echo "all pods ready"
	@echo "\n== recent warnings =="
	@kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) get events --field-selector type=Warning --sort-by=.lastTimestamp 2>/dev/null | tail -12
