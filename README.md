# Molecule

Shared CI for the Rheinwerk Ansible roles: a reusable GitHub workflow, the molecule scenario it runs, the
container images it uses, and the pinned tool and collection versions behind all of it.

# CI for a role

Roles do not carry their own pipeline. A role's `.github/workflows/ci.yml` is a short caller of the reusable
workflow in this repository, see [examples/molecule.yml](examples/molecule.yml):

```yaml
jobs:
  ci:
    uses: Rheinwerk/molecule/.github/workflows/role.yml@main
    with:
      force_run: ${{ format('{0}', inputs.force_run) }}
      molecule_debug: ${{ format('{0}', inputs.molecule_debug) }}
      args: ${{ inputs.args }}
      molecule_ref: ${{ inputs.molecule_ref || 'main' }}
    secrets: inherit
```

`secrets: inherit` hands the `GALAXY_API_KEY` organisation secret to the release job.

## Pipeline

1. **Changes**: decides whether molecule has to run. Changes to `README.md`, `LICENSE`, `.gitignore`,
   `renovate.json` and `docs/` alone skip it; deletions count as changes.
2. **Lint**: `ansible-lint --offline` and `yamllint` in `ghcr.io/rheinwerk/molecule:lint`. Always runs.
3. **Molecule**: one job per matrix entry, by default `debian-12` with the `ansible_current`, `ansible_next`
   and `ansible_latest` scenarios. `ansible_next` and `ansible_latest` are experimental and may fail.
4. **Release**: on a tag push, triggers the import of the role at Ansible Galaxy.

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `force_run` | `'false'` | Run molecule even if only ignored files changed |
| `molecule_debug` | `'false'` | Open a [tmate](https://github.com/mxschmitt/action-tmate) session right before molecule runs |
| `args` | `''` | Additional arguments for `molecule test` |
| `matrix` | see below | JSON list of matrix entries |
| `python_version` | `'3.12'` | Python version for the molecule virtualenv |
| `molecule_ref` | `main` | Ref of this repository to take the action, the scenario and the collections from |
| `role_repository` | calling repository | Repository of the role under test (used by the smoke test) |
| `role_ref` | triggering ref | Ref of the role under test |

Inputs are strings. Pass dispatch booleans through `format('{0}', ...)`, which yields `'true'`/`'false'`
and `''` for events without inputs.

### Matrix

The default matrix is

```json
[{"distro": "debian-12", "ansible_scenario": "ansible_current", "experimental": false},
 {"distro": "debian-12", "ansible_scenario": "ansible_next", "experimental": true},
 {"distro": "debian-12", "ansible_scenario": "ansible_latest", "experimental": true}]
```

`distro` is a tag of `ghcr.io/rheinwerk/molecule`, `ansible_scenario` one of `ansible_current`,
`ansible_next`, `ansible_latest` (the Ansible versions are defined in [action.yml](action.yml)) or empty
for the newest Ansible, `experimental: true` lets the job fail without failing the run. Pass your own list
as the `matrix` input to add or remove entries.

### Lint only, no molecule

If a role cannot be tested in a container (needs cloud credentials, hardware, ...), set

```yaml
galaxy_info:
  min_ansible_container_version: "X"
```

in `meta/main.yml`. Lint and release still run.

## Migrating a role from the old per-role workflow

1. Replace `.github/workflows/ci.yml` with [examples/molecule.yml](examples/molecule.yml).
2. Remove `parseable: true` from `.ansible-lint` if present; current ansible-lint rejects the key.
3. Make sure the `GALAXY_API_KEY` secret is available to the repository.
4. Add `renovate.json` with `"extends": ["github>Rheinwerk/molecule"]` and remove `.github/dependabot.yml`.

The composite action (`uses: Rheinwerk/molecule@main`) keeps working for roles that have not migrated yet.

# Using the action directly

The reusable workflow runs molecule through the composite action in [action.yml](action.yml). It can
still be used on its own:

```yaml
      - uses: Rheinwerk/molecule@main
        with:
          distro: debian-12
          ansible_scenario: ansible_current
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

# Scenario

[scenarios/docker](scenarios/docker) is synced into the role's `molecule/default/` with
`rsync --ignore-existing`: files the role ships there win. That is how a role adds its own `verify.yml`,
`converge.yml`, `requirements.yml` or `converge_override.yml`.

## Include prerequisite role

Create `molecule/default/requirements.yml` inside the repository with following content and replace values as needed:

```yaml
- src: https://github.com/Rheinwerk/ansible-role-example.git
  name: example
  scm: git
```

Create `molecule/default/converge.yml` inside the repository with following content, replacing `example` as needed:

```yaml
---
- name: Converge
  hosts: all
  become: true

  pre_tasks:
    - name: Update APT Cache
      ansible.builtin.apt:
        update_cache: yes
        cache_valid_time: 600
      register: result
      until: result is succeeded
      when: ansible_os_family == 'Debian'

    # skip idempotence tests
    - name: Include Example install role
      ansible.builtin.include_role:
        name: example
      when: "'molecule-idempotence-notest' not in ansible_skip_tags"

  tasks:
    - name: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }}"
      ansible.builtin.include_role:
        name: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }}"
```

The prerequisite role is included only in the converge stage of molecule, but not in the idempotence test
because of `when: "'molecule-idempotence-notest' not in ansible_skip_tags"`.

## Converge override

Instead of replacing `converge.yml`, a role can ship `molecule/default/converge_override.yml` with tasks
that the shared converge includes before the role runs.

## Disable the idempotence check

See https://ansible.readthedocs.io/projects/molecule/configuration/

### Whole role

Create `molecule/default/converge.yml` and tag the role include:

```yaml
  tasks:
    # skip idempotence tests
    - name: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }}"
      ansible.builtin.include_role:
        name: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') | basename }}"
      tags:
        - molecule-idempotence-notest
```

### Single tasks

Tag the task with `molecule-idempotence-notest`:

```yaml
# skip idempotence tests
- name: Not idempotent task
  ansible.builtin.command: "echo not-idempotent"
  tags:
    - molecule-idempotence-notest
```

# Local runs

[examples/Makefile](examples/Makefile) runs the shared scenario against the role in the current directory
with the same environment variables as the CI. Copy or symlink it into the role:

```bash
make test                                            # full molecule test, debian-12
make converge MOLECULE_DISTRO=ubuntu-2404            # keep the container for inspection
make test MOLECULE_DIR=~/github/Rheinwerk/molecule   # scenario from a local checkout
make lint
make clean                                           # remove the synced scenario files
```

It needs `molecule` and `molecule-plugins[docker]` in the active virtualenv and docker.

# Testing changes to this repository

- [ci.yml](.github/workflows/ci.yml) lints the scenario (ansible-lint, yamllint) and the workflows
  (actionlint) on every push and pull request.
- [smoke-test.yml](.github/workflows/smoke-test.yml) runs the reusable workflow against a pinned
  commit of `Rheinwerk/ansible-role-transparent_hugepage_setup` with the action, scenario and collections of the
  pushed ref whenever one of them changes. The workflows run with a read-only token. A role can do the same for a branch of this repository by dispatching
  its CI with `molecule_ref`.

# Pinned versions

- `molecule` and `molecule-plugins` are pinned in [requirements/molecule.txt](requirements/molecule.txt), which
  the action installs. Molecule installed the newest version before, and a new molecule-plugins release broke
  every role run in 2026 by rejecting a key in the shared `molecule.yml`. The `molecule_version` and
  `molecule_plugins_version` inputs override the pins for a single run.
- The tools of the lint image are pinned in [dockerfiles/lint-requirements.txt](dockerfiles/lint-requirements.txt).
- The Ansible collections for the molecule runs and the lint image are pinned in
  [dockerfiles/collections.yml](dockerfiles/collections.yml).

[Dependabot](.github/dependabot.yml) opens pull requests for the GitHub Actions and for both requirements
files. Dependabot has no Galaxy support, so [bump-collections.yml](.github/workflows/bump-collections.yml)
runs [scripts/bump-collections.py](scripts/bump-collections.py) weekly, pushes a `bump-collections` branch,
opens a pull request (or an issue, if the repository does not let Actions create pull requests) and dispatches
CI and the smoke test on it. `make bump-collections` does the same locally. The smoke test runs every bump
against a role before it reaches the roles.

# Containers

Built by [docker.yml](.github/workflows/docker.yml) weekly and on changes below `dockerfiles/`, for amd64
and arm64, published as `ghcr.io/rheinwerk/molecule:<tag>`.

## lint

Alpine with `ansible-core`, `ansible-lint`, `yamllint`, `black` (pip, pinned) and `shellcheck`, plus the
pinned collections so `ansible-lint --offline` resolves FQCNs.

## debian-12

The molecule test target ([dockerfiles/CI](dockerfiles/CI)): Debian 12 with systemd, Python 3.12 (via
[pascalroeleven's backport](https://github.com/pascallj/python3.12-backport)), cron, dnsmasq, rsyslog.

## pkr-debian-12, pkr-debian-13, pkr-ubuntu-2204, pkr-ubuntu-2404

Debian and Ubuntu with systemd and the stock Python for Packer builds ([dockerfiles/Debian](dockerfiles/Debian),
[dockerfiles/Ubuntu](dockerfiles/Ubuntu)).

## Building images locally

```bash
make build-all            # all images, native platform
make build-lint           # one image
make push-all             # build and push, amd64 + arm64
make help
```
