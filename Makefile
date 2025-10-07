.PHONY: all build-lint build-debian-12 build-packer push-lint push-debian-12 push-packer build-all push-all clean help

# Variables
REGISTRY := ghcr.io
NAMESPACE := rheinwerk/molecule
PLATFORMS := linux/amd64,linux/arm64
CONTEXT := dockerfiles
ANSIBLE_VERSION := 2.18.5

# Image tags
LINT_IMAGE := $(REGISTRY)/$(NAMESPACE):lint
DEBIAN_12_IMAGE := $(REGISTRY)/$(NAMESPACE):debian-12-pkr
PACKER_IMAGE := $(REGISTRY)/$(NAMESPACE):packer

# Default target
all: build-all

help:
	@echo "Available targets:"
	@echo "  build-all        - Build all images locally"
	@echo "  build-lint       - Build lint image"
	@echo "  build-debian-12  - Build Debian 12 (Bookworm) image with ansible"
	@echo "  build-packer     - Build Packer image without ansible"
	@echo "  push-all         - Build and push all images to registry"
	@echo "  push-lint        - Build and push lint image"
	@echo "  push-debian-12   - Build and push Debian 12 image with ansible"
	@echo "  push-packer      - Build and push Packer image without ansible"
	@echo "  clean            - Clean up Docker build cache"
	@echo "  help             - Show this help message"

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
	@echo "Building Debian 12 (Bookworm) image with ansible..."
	docker buildx build \
		--build-arg OS_VERSION=bookworm \
		--build-arg ANSIBLE_VERSION=$(ANSIBLE_VERSION) \
		--file $(CONTEXT)/Debian \
		--tag $(DEBIAN_12_IMAGE) \
		--load \
		$(CONTEXT)

build-packer:
	@echo "Building Packer image without ansible..."
	docker buildx build \
		--build-arg OS_VERSION=bookworm \
		--file $(CONTEXT)/Packer \
		--tag $(PACKER_IMAGE) \
		--load \
		$(CONTEXT)

build-all: build-lint build-debian-12 build-packer

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
	@echo "Building and pushing Debian 12 (Bookworm) image with ansible (multi-platform)..."
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg OS_VERSION=bookworm \
		--build-arg ANSIBLE_VERSION=$(ANSIBLE_VERSION) \
		--file $(CONTEXT)/Debian \
		--tag $(DEBIAN_12_IMAGE) \
		--push \
		$(CONTEXT)

push-packer:
	@echo "Building and pushing Packer image without ansible (multi-platform)..."
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg OS_VERSION=bookworm \
		--file $(CONTEXT)/Packer \
		--tag $(PACKER_IMAGE) \
		--push \
		$(CONTEXT)

push-all: push-lint push-debian-12 push-packer

# Utility targets
clean:
	@echo "Cleaning up Docker build cache..."
	docker buildx prune -f

# Setup buildx (run once if needed)
setup-buildx:
	@echo "Setting up Docker buildx..."
	docker buildx create --use --name molecule-builder || docker buildx use molecule-builder
	docker buildx inspect --bootstrap
