# Cloud Marketplace deployment container. Build from the repo root:
#   make deployer
# The onbuild base copies chart/ and schema.yaml from the build context and
# substitutes $REGISTRY/$TAG into the schema.
# Pinned digest of deployer_helm/onbuild:latest as of 2026-09-10.
FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild@sha256:6a6d705987be9dacb976540b02901250bf09324c2fdc641f64c014da696bd198

ARG REGISTRY
ARG TAG

# GKE Autopilot needs time to provision nodes and pull multi-GB images.
ENV WAIT_FOR_READY_TIMEOUT=1500 \
    TESTER_TIMEOUT=600

COPY apptest/deployer/schema.yaml /data-test/schema.yaml.tmpl
RUN cat /data-test/schema.yaml.tmpl \
      | env -i "REGISTRY=$REGISTRY" "TAG=$TAG" envsubst \
      > /data-test/schema.yaml \
    && rm /data-test/schema.yaml.tmpl
