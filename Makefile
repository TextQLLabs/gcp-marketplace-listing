# Build and publish the TextQL Cloud Marketplace app package.
#
# The staging registry layout Google Cloud Marketplace requires: every image
# of a release lives under one registry path and carries both the release
# track tag (1.3) and the release version tag (1.3.20); the deployment
# container lives in the `deployer` folder.

REGISTRY ?= us-docker.pkg.dev/textql-public/textql
TAG      ?= 1.3.20
TRACK    ?= 1.3
PLATFORM ?= linux/amd64

# Third-party images mirrored into the registry so that a release is
# self-contained (sources are multi-arch; the amd64 variant is mirrored).
MIRROR_SPECS = \
	valkey=docker.io/valkey/valkey:8.1-alpine \
	kubectl=docker.io/bitnamilegacy/kubectl:1.33 \
	postgres=docker.io/pgvector/pgvector:pg17 \
	tester=docker.io/curlimages/curl:8.11.1

# Marketplace product service-name annotation, required on every image
# manifest of a release. First-party images get it from the mirror script in
# the main repository; this covers the images built/mirrored here.
SERVICE_NAME_ANNOTATION = com.googleapis.cloudmarketplace.product.service.name=services/textql-byoc-listing.endpoints.textql-public.cloud.goog
ANNOTATE_IMAGES = valkey kubectl postgres tester deployer

.PHONY: deployer push-deployer mirror-third-party annotate app-crd verify

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

# Stamp the Marketplace annotation onto the image manifests (requires gcrane:
# go install github.com/google/go-containerregistry/cmd/gcrane@latest). Run
# after mirror-third-party / push-deployer.
annotate:
	@for img in $(ANNOTATE_IMAGES); do \
	  for tag in $(TAG) $(TRACK); do \
	    ref=$(REGISTRY)/$$img:$$tag; \
	    echo "==> annotate $$ref"; \
	    gcrane mutate -a "$(SERVICE_NAME_ANNOTATION)" $$ref -t $$ref >/dev/null || exit 1; \
	  done; \
	done

# The Application CRD must exist on the cluster before installing the app.
app-crd:
	kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml

# Runs the same verification the Marketplace runs before publishing:
# install -> tester Pod -> uninstall. Requires mpdev
# (https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools).
verify:
	mpdev verify --deployer=$(REGISTRY)/deployer:$(TAG)
