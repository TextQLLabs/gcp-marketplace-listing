# Cloud Marketplace deployment container for TextQL.
#
# Build from the repository root (the ONBUILD base copies chart/ and
# schema.yaml from the build context):
#
#   docker build --platform linux/amd64 \
#     --build-arg REGISTRY=us-docker.pkg.dev/textql-public/textql \
#     --build-arg TAG=1.3.20 \
#     -f deployer/Dockerfile \
#     -t us-docker.pkg.dev/textql-public/textql/deployer:1.3.20 .
#
# Pinned digest of gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild:latest
# as of 2026-09-10.
FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild@sha256:6a6d705987be9dacb976540b02901250bf09324c2fdc641f64c014da696bd198

ARG REGISTRY
ARG TAG

# Generous readiness/test windows: GKE Autopilot may need to provision nodes
# and pull multi-GB images before workloads go healthy.
ENV WAIT_FOR_READY_TIMEOUT=1500 \
    TESTER_TIMEOUT=600

# Verification overlay (/data-test), with the same REGISTRY/TAG substitution
# the base image applies to /data/schema.yaml.
COPY apptest/deployer/schema.yaml /data-test/schema.yaml.tmpl
RUN cat /data-test/schema.yaml.tmpl \
      | env -i "REGISTRY=$REGISTRY" "TAG=$TAG" envsubst \
      > /data-test/schema.yaml \
    && rm /data-test/schema.yaml.tmpl
