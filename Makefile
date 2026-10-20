# Docker image
IMAGE_NAME ?= ghcr.io/health-ai-consortium/datavalgen-model-beach
# Get version from pyproject.toml (sed, not python: tomllib needs Python 3.11+)
PY_PKG_VERSION := $(shell sed -n 's/^version = "\(.*\)"$$/\1/p' pyproject.toml | head -n 1)
GIT_TAG := release/v$(PY_PKG_VERSION)
DOCKER_TAG := v$(PY_PKG_VERSION)

DOCKERFILE ?= ./Dockerfile

# Default target
.PHONY: all
all: build tag

.PHONY: check-version
check-version:
	@test -n "$(PY_PKG_VERSION)" || { echo "Could not read version from pyproject.toml" >&2; exit 1; }

# Build the Docker image
.PHONY: build
build: check-version
	docker build -t $(IMAGE_NAME):$(DOCKER_TAG) -t $(IMAGE_NAME):latest -f $(DOCKERFILE) .

.PHONY: tag
tag: check-version
	git tag "$(GIT_TAG)"
	@echo You can push tag to origin with: git push origin "$(GIT_TAG)"
