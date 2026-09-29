# MinIO server image for the Marketplace listing, built from source.
#
# MinIO stopped publishing container images in 2026 and archived its GitHub
# repository, so the last public source (master at MINIO_COMMIT, i.e. release
# RELEASE.2025-10-15T17-29-55Z plus documentation commits) is compiled here
# with the Go modules the Marketplace scanner flags bumped to their fixed
# versions, on a current Go toolchain. The runtime layout mirrors MinIO's own
# Dockerfile.release minus the mc client (the chart never uses it) and the
# static curl (the chart's probes are httpGet).
#
# Build from the repo root with `make minio`: the compile runs on the build
# platform and cross-compiles; the runtime image is $(PLATFORM).

ARG MINIO_COMMIT=7aac2a2c5b7c882e68c1ce017d8256be2feea27f
ARG MINIO_RELEASE_TIME=2025-10-15T17-29-55Z

FROM --platform=$BUILDPLATFORM golang:1.27-trixie AS build
ARG TARGETARCH
ARG MINIO_COMMIT
ARG MINIO_RELEASE_TIME
WORKDIR /src
RUN git init -q \
 && git remote add origin https://github.com/minio/minio \
 && git fetch -q --depth 1 origin "$MINIO_COMMIT" \
 && git checkout -q FETCH_HEAD

ENV GOTOOLCHAIN=local GOFLAGS=-mod=mod CGO_ENABLED=0

# Every module with a published fix as of 2026-09-29 (Marketplace scan +
# trivy). golang.org/x/net, golang.org/x/text and go.opentelemetry.io/otel
# follow by minimal version selection. No `go mod tidy`: a test-only
# dependency of the upgraded go-openapi/swag no longer resolves, and the
# build needs none of it (-mod=mod completes go.sum).
RUN go get \
      golang.org/x/crypto@v0.56.0 \
      github.com/rabbitmq/amqp091-go@v1.13.0 \
      github.com/buger/jsonparser@v1.1.2 \
      github.com/go-jose/go-jose/v4@v4.1.4 \
      google.golang.org/grpc@v1.83.2 \
      github.com/apache/thrift@v0.24.0 \
      github.com/prometheus/prometheus@v0.311.3 \
      go.opentelemetry.io/otel/sdk@v1.45.0 \
      filippo.io/edwards25519@v1.1.1 \
      github.com/Azure/go-ntlmssp@v0.1.1 \
      github.com/eclipse/paho.mqtt.golang@v1.5.1

# Same flags as MinIO's Makefile hotfix target; the release tag keeps
# MinIO's RELEASE.<time>.hotfix.<commit> shape.
RUN LDFLAGS="$(MINIO_RELEASE=RELEASE MINIO_HOTFIX="hotfix.$(git rev-parse --short=12 HEAD)" \
              go run buildscripts/gen-ldflags.go "$MINIO_RELEASE_TIME")" \
 && mkdir -p /out \
 && GOOS=linux GOARCH="$TARGETARCH" go build -tags kqueue -trimpath -ldflags "$LDFLAGS" -o /out/minio . \
 && chmod 0755 /out/minio dockerscripts/docker-entrypoint.sh \
 && sha256sum /out/minio > /out/minio.sha256sum

FROM registry.access.redhat.com/ubi9/ubi-micro:latest
ARG MINIO_RELEASE_TIME
LABEL name="MinIO" \
      vendor="MinIO Inc <dev@min.io>" \
      version="RELEASE.${MINIO_RELEASE_TIME}" \
      release="RELEASE.${MINIO_RELEASE_TIME}" \
      summary="MinIO is a High Performance Object Storage, API compatible with Amazon S3 cloud storage service." \
      description="MinIO server built from the last public source with patched dependencies, for the TextQL Google Cloud Marketplace listing."

ENV MINIO_ACCESS_KEY_FILE=access_key \
    MINIO_SECRET_KEY_FILE=secret_key \
    MINIO_ROOT_USER_FILE=access_key \
    MINIO_ROOT_PASSWORD_FILE=secret_key \
    MINIO_KMS_SECRET_KEY_FILE=kms_master_key \
    MINIO_CONFIG_ENV_FILE=config.env

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /out/minio /out/minio.sha256sum /usr/bin/
COPY --from=build /src/CREDITS /licenses/CREDITS
COPY --from=build /src/LICENSE /licenses/LICENSE
COPY --from=build /src/dockerscripts/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh

EXPOSE 9000
VOLUME ["/data"]
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio"]
