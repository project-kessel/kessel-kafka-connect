IMAGE ?="quay.io/cloudservices/kessel-kafka-connect"
IMAGE_TAG=$(git rev-parse --short=7 HEAD)
GIT_COMMIT=$(git rev-parse --short HEAD)

ifeq ($(DOCKER),)
DOCKER:=$(shell command -v podman || command -v docker)
endif

ifeq ($(VERSION),)
VERSION:=$(shell git describe --tags --always)
endif

.PHONY: docker-build-push
docker-build-push:
	./build_deploy.sh
