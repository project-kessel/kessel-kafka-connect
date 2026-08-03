IMAGE_TAG := $(shell git rev-parse --short=7 HEAD)
GIT_COMMIT := $(shell git rev-parse --short HEAD)

ifeq ($(DOCKER),)
DOCKER := $(shell command -v podman || command -v docker)
endif

ifeq ($(VERSION),)
VERSION := $(shell git describe --tags --always)
endif

# On macOS (Apple Silicon) cross-compile to linux/amd64 to match the target platform
ifeq ($(shell uname -s),Darwin)
PLATFORM_FLAGS := --platform linux/amd64 --build-arg TARGETARCH=amd64
else
PLATFORM_FLAGS :=
endif

.PHONY: docker-build-push
docker-build-push: ## Build and push the container image; IMAGE and quay.io login are required
	@[ -n "$(DOCKER)" ] || { echo "Error: neither podman nor docker found. Please install one to continue."; exit 1; }
	@[ -n "$(IMAGE)" ] || { echo "IMAGE is required. Example: make docker-build-push IMAGE=quay.io/youruser/kessel-kafka-connect"; exit 1; }
	@printf '%s\n' "$(IMAGE)" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9._/:@-]*$$' || { echo "IMAGE contains invalid characters. Use format: quay.io/your-org/image-name"; exit 1; }
	@"$(DOCKER)" build $(PLATFORM_FLAGS) --build-arg GIT_COMMIT="$(GIT_COMMIT)" -t "$(IMAGE):$(IMAGE_TAG)" -f ./Dockerfile . || \
		{ echo "Build failed. If due to authentication, check your registry credentials and try again."; exit 1; }
	@"$(DOCKER)" push "$(IMAGE):$(IMAGE_TAG)" || \
		{ echo "Push failed. If due to authentication, run: $(DOCKER) login quay.io"; exit 1; }
	@"$(DOCKER)" tag "$(IMAGE):$(IMAGE_TAG)" "$(IMAGE):latest"
	@"$(DOCKER)" push "$(IMAGE):latest" || \
		{ echo "Push failed. If due to authentication, run: $(DOCKER) login quay.io"; exit 1; }
