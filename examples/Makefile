# Runs the shared docker scenario against the role in the current directory, with the same
# environment as the CI. Copy or symlink this file into a role as "Makefile".
#
#   make test                                            # full molecule test, debian-12
#   make converge MOLECULE_DISTRO=ubuntu-2404            # keep the container for inspection
#   make test MOLECULE_DIR=~/github/Rheinwerk/molecule   # scenario from a local checkout
#
# Needs molecule and molecule-plugins[docker] in the active virtualenv, docker, and gh (optional,
# for the ghcr.io login that molecule.yml expects).

SHELL := /bin/bash

MOLECULE_GIT_REPO ?= git@github.com:Rheinwerk/molecule.git
MOLECULE_REF ?= main
MOLECULE_DIR ?=
# zsh does not expand ~ in VAR=~/path arguments, so do it here (override: it is a command-line variable)
override MOLECULE_DIR := $(patsubst ~%,$(HOME)%,$(MOLECULE_DIR))
MOLECULE_SCENARIO ?= docker
MOLECULE_DISTRO ?= debian-12
LINT_IMAGE ?= ghcr.io/rheinwerk/molecule:lint

export MOLECULE_DISTRO
export GITHUB_WORKSPACE := $(CURDIR)
export ANSIBLE_ROLES_PATH := $(CURDIR)
export CI_HOSTNAME := $(shell echo $(MOLECULE_DISTRO) | tr -dc '[:alnum:]' | tr '[:upper:]' '[:lower:]')
export CI_PROJECT_NAME_MOLECULE := rheinwerk
export CI_JOB_ID := local-$(shell date +%s)
export TEST_TYPE := unit
export GITHUB_ACTOR := $(shell gh api user --jq .login 2>/dev/null)
export GITHUB_TOKEN := $(shell gh auth token 2>/dev/null)

.PHONY: help scenario test converge verify destroy lint clean

help:
	@echo "test      - molecule test with the shared $(MOLECULE_SCENARIO) scenario (MOLECULE_DISTRO=$(MOLECULE_DISTRO))"
	@echo "converge  - molecule converge, keeps the container"
	@echo "verify    - molecule verify against the running container"
	@echo "destroy   - molecule destroy"
	@echo "lint      - ansible-lint and yamllint in $(LINT_IMAGE)"
	@echo "clean     - remove the synced scenario files from molecule/ (role-owned files stay)"

# Files the role ships in molecule/default/ win over the shared scenario (--ignore-existing), as in CI
scenario:
	mkdir -p molecule/default
	if [ -n "$(MOLECULE_DIR)" ]; then \
	  rsync -a --ignore-existing "$(MOLECULE_DIR)/scenarios/$(MOLECULE_SCENARIO)/" molecule/default/; \
	else \
	  tmp=$$(mktemp -d) && git clone -q --depth 1 --branch "$(MOLECULE_REF)" "$(MOLECULE_GIT_REPO)" "$$tmp" \
	    && rsync -a --ignore-existing "$$tmp/scenarios/$(MOLECULE_SCENARIO)/" molecule/default/ && rm -rf "$$tmp"; \
	fi

test: scenario
	molecule test

converge: scenario
	molecule converge

verify: scenario
	molecule verify

destroy: scenario
	molecule destroy

lint:
	docker run --rm -v "$(CURDIR):/git" -w /git $(LINT_IMAGE) ansible-lint --force-color --offline /git
	docker run --rm -v "$(CURDIR):/git" -w /git $(LINT_IMAGE) yamllint -f colored /git

clean:
	git clean -xdf molecule/
