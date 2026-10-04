.PHONY: all build-lint build-debian-12 build-debian-13 build-ubuntu-22-04 build-ubuntu-24-04 push-lint push-debian-12 push-debian-13 push-ubuntu-22-04 push-ubuntu-24-04 build-all push-all clean help

# Variables
REGISTRY := ghcr.io
NAMESPACE := rheinwerk/molecule
PLATFORMS := linux/amd64,linux/arm64
CONTEXT := dockerfiles
ANSIBLE_VERSION := 2.18.5

# Image tags
LINT_IMAGE := $(REGISTRY)/$(NAMESPACE):lint
DEBIAN_12_IMAGE := $(REGISTRY)/$(NAMESPACE):pkr-debian-12
DEBIAN_13_IMAGE := $(REGISTRY)/$(NAMESPACE):pkr-debian-13
UBUNTU_22_04_IMAGE := $(REGISTRY)/$(NAMESPACE):pkr-ubuntu-22.04
UBUNTU_24_04_IMAGE := $(REGISTRY)/$(NAMESPACE):pkr-ubuntu-24.04

# Default target
all: build-all

help:
	@echo "Available targets:"
	@echo "  build-all          - Build all images locally"
	@echo "  build-lint         - Build lint image"
	@echo "  build-debian-12    - Build Debian 12 (Bookworm) image with ansible"
	@echo "  build-debian-13    - Build Debian 13 (Trixie) image with ansible"
	@echo "  build-ubuntu-22-04 - Build Ubuntu 22.04 (Jammy) image with ansible"
	@echo "  build-ubuntu-24-04 - Build Ubuntu 24.04 (Noble) image with ansible"
	@echo "  push-all           - Build and push all images to registry"
	@echo "  push-lint          - Build and push lint image"
	@echo "  push-debian-12     - Build and push Debian 12 image with ansible"
	@echo "  push-debian-13     - Build and push Debian 13 image with ansible"
	@echo "  push-ubuntu-22-04  - Build and push Ubuntu 22.04 image with ansible"
	@echo "  push-ubuntu-24-04  - Build and push Ubuntu 24.04 image with ansible"
	@echo "  clean              - Clean up Docker build cache"
	@echo "  help               - Show this help message"

# Build targets (local only, native platform)
build-lint:
	@echo "Building lint image..."
	docker buildx build \
		--build-arg OS_VERSION=3.17 \
		--file $(CONTEXT)/Lint \
		--tag $(LINT_IMAGE) \
		--load \
		$(CONTEXT)

build-debian-12:
	@echo "Building Debian 12 (Bookworm) image..."
	docker buildx build \
		--build-arg OS_VERSION=bookworm \
		--file $(CONTEXT)/Debian \
		--tag $(DEBIAN_12_IMAGE) \
		--load \
		$(CONTEXT)

build-debian-13:
	@echo "Building Debian 13 (Trixie) image..."
	docker buildx build \
		--build-arg OS_VERSION=trixie \
		--file $(CONTEXT)/Debian \
		--tag $(DEBIAN_13_IMAGE) \
		--load \
		$(CONTEXT)

build-ubuntu-22-04:
	@echo "Building Ubuntu 22.04 (Jammy) image with ansible..."
	docker buildx build \
		--build-arg OS_VERSION=22.04 \
		--build-arg ANSIBLE_VERSION=$(ANSIBLE_VERSION) \
		--file $(CONTEXT)/Ubuntu \
		--tag $(UBUNTU_22_04_IMAGE) \
		--load \
		$(CONTEXT)

build-ubuntu-24-04:
	@echo "Building Ubuntu 24.04 (Noble) image with ansible..."
	docker buildx build \
		--build-arg OS_VERSION=24.04 \
		--build-arg ANSIBLE_VERSION=$(ANSIBLE_VERSION) \
		--file $(CONTEXT)/Ubuntu \
		--tag $(UBUNTU_24_04_IMAGE) \
		--load \
		$(CONTEXT)

build-all: build-lint build-debian-12 build-debian-13 build-ubuntu-22-04 build-ubuntu-24-04

# Push targets (multi-platform)
push-lint:
	@echo "Building and pushing lint image (multi-platform)..."
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg OS_VERSION=3.17 \
		--file $(CONTEXT)/Lint \
		--tag $(LINT_IMAGE) \
		--push \
		$(CONTEXT)

push-debian-12:
	@echo "Building and pushing Debian 12 (Bookworm) image (multi-platform)..."
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg OS_VERSION=bookworm \
		--file $(CONTEXT)/Debian \
		--tag $(DEBIAN_12_IMAGE) \
		--push \
		$(CONTEXT)

push-debian-13:
	@echo "Building and pushing Debian 13 (Trixie) image (multi-platform)..."
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg OS_VERSION=trixie \
		--file $(CONTEXT)/Debian \
		--tag $(DEBIAN_13_IMAGE) \
		--push \
		$(CONTEXT)

push-ubuntu-22-04:
	@echo "Building and pushing Ubuntu 22.04 (Jammy) image with ansible (multi-platform)..."
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg OS_VERSION=22.04 \
		--build-arg ANSIBLE_VERSION=$(ANSIBLE_VERSION) \
		--file $(CONTEXT)/Ubuntu \
		--tag $(UBUNTU_22_04_IMAGE) \
		--push \
		$(CONTEXT)

push-ubuntu-24-04:
	@echo "Building and pushing Ubuntu 24.04 (Noble) image with ansible (multi-platform)..."
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg OS_VERSION=24.04 \
		--build-arg ANSIBLE_VERSION=$(ANSIBLE_VERSION) \
		--file $(CONTEXT)/Ubuntu \
		--tag $(UBUNTU_24_04_IMAGE) \
		--push \
		$(CONTEXT)

push-all: push-lint push-debian-12 push-debian-13 push-ubuntu-22-04 push-ubuntu-24-04

# Utility targets
clean:
	@echo "Cleaning up Docker build cache..."
	docker buildx prune -f

# Setup buildx (run once if needed)
setup-buildx:
	@echo "Setting up Docker buildx..."
	docker buildx create --use --name molecule-builder || docker buildx use molecule-builder
	docker buildx inspect --bootstrap
