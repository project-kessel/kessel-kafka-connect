IMAGE_TAG := $(shell git rev-parse --short=7 HEAD)
GIT_COMMIT := $(shell git rev-parse --short HEAD)

ifeq ($(DOCKER),)
DOCKER := $(shell command -v podman || command -v docker)
endif

# On macOS (Apple Silicon) cross-compile to linux/amd64 to match the target platform
ifeq ($(shell uname -s),Darwin)
PLATFORM_FLAGS := --platform linux/amd64 --build-arg TARGETARCH=amd64
else
PLATFORM_FLAGS :=
endif

# Hermeto runs the same prefetch locally that Konflux runs in CI. Konflux updates
# its own Hermeto version independently, so this pin can lag behind; bump it
# when convenient. The image is published for linux/amd64 only.
HERMETO_IMAGE := quay.io/konflux-ci/hermeto:0.64.0@sha256:3c7a8622981aec970c159e608500d75a01e6bb42564ec25a92369e178b6ace8f
HERMETO_OUTPUT := $(CURDIR)/hermeto-output

.PHONY: prefetch
prefetch: ## Fetch and checksum-verify the artifacts in artifacts.lock.yaml into ./hermeto-output (requires network)
	@[ -n "$(DOCKER)" ] || { echo "Error: neither podman nor docker found. Please install one to continue."; exit 1; }
	@rm -rf "$(HERMETO_OUTPUT)" && mkdir -p "$(HERMETO_OUTPUT)"
	@"$(DOCKER)" run --rm --platform linux/amd64 \
		-v "$(CURDIR):/source:z" -v "$(HERMETO_OUTPUT):/output:z" \
		"$(HERMETO_IMAGE)" fetch-deps --source /source --output /output '{"type": "generic", "path": "."}'

.PHONY: check-build-env
check-build-env:
	@case "$$(basename "$(DOCKER)")" in podman*) ;; *) echo "Error: building needs podman; 'docker build' cannot mount the prefetched dependencies. Install podman or set DOCKER=podman."; exit 1;; esac
	@[ -n "$(IMAGE)" ] || { echo "IMAGE is required. Example: make docker-build-push IMAGE=quay.io/youruser/kessel-kafka-connect"; exit 1; }
	@printf '%s\n' "$(IMAGE)" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9._/:@-]*$$' || { echo "IMAGE contains invalid characters. Use format: quay.io/your-org/image-name"; exit 1; }

.PHONY: docker-build-push
docker-build-push: check-build-env prefetch ## Build (network-isolated, like Konflux) and push the container image; IMAGE and quay.io login are required
	@"$(DOCKER)" build $(PLATFORM_FLAGS) --network none -v "$(HERMETO_OUTPUT):/cachi2/output:ro,z" \
		--build-arg GIT_COMMIT="$(GIT_COMMIT)" -t "$(IMAGE):$(IMAGE_TAG)" -f ./Dockerfile . || \
		{ echo "Build failed. If due to authentication, check your registry credentials and try again."; exit 1; }
	@"$(DOCKER)" push "$(IMAGE):$(IMAGE_TAG)" || \
		{ echo "Push failed. If due to authentication, run: $(DOCKER) login quay.io"; exit 1; }
	@"$(DOCKER)" tag "$(IMAGE):$(IMAGE_TAG)" "$(IMAGE):latest"
	@"$(DOCKER)" push "$(IMAGE):latest" || \
		{ echo "Push failed. If due to authentication, run: $(DOCKER) login quay.io"; exit 1; }

.PHONY: generate-checksums
generate-checksums: ## Print SHA-256 checksums for a Debezium version to paste into artifacts.lock.yaml; DEBEZIUM_VERSION is required (requires network)
	@[ -n "$(DEBEZIUM_VERSION)" ] || { echo "DEBEZIUM_VERSION is required. Example: make generate-checksums DEBEZIUM_VERSION=3.1.3.Final"; exit 1; }
	@bash scripts/generate-checksums.sh "$(DEBEZIUM_VERSION)"
