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
3. **Molecule**: one job per matrix entry, by default `ansible_current` on `debian-12` and `debian-13`, plus
   `ansible_next` and `ansible_latest` on `debian-13`. `ansible_next` and `ansible_latest` are experimental
   and may fail. Facts are not injected as variables (`ANSIBLE_INJECT_FACT_VARS=False`, the behaviour of
   ansible-core 2.24): roles read `ansible_facts['<fact>']`, an `ansible_<fact>` variable fails the run.
4. **Release**: on a tag push, triggers the import of the role at Ansible Galaxy.

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `force_run` | `'false'` | Run molecule even if only ignored files changed |
| `molecule_debug` | `'false'` | Open a [tmate](https://github.com/mxschmitt/action-tmate) session right before molecule runs |
| `args` | `''` | Additional arguments for `molecule test` |
| `matrix` | see below | JSON list of matrix entries |
| `python_version` | `'3.12'` | Python version for the molecule virtualenv, unless the matrix entry sets `python_version` |
| `molecule_ref` | `main` | Ref of this repository to take the action, the scenario and the collections from |
| `role_repository` | calling repository | Repository of the role under test (used by the smoke test) |
| `role_ref` | triggering ref | Ref of the role under test |

Inputs are strings. Pass dispatch booleans through `format('{0}', ...)`, which yields `'true'`/`'false'`
and `''` for events without inputs.

### Matrix

The default matrix is

```json
[{"distro": "debian-12", "ansible_scenario": "ansible_current", "experimental": false},
 {"distro": "debian-13", "ansible_scenario": "ansible_current", "experimental": false, "python_version": "3.13"},
 {"distro": "debian-13", "ansible_scenario": "ansible_next", "experimental": true, "python_version": "3.13"},
 {"distro": "debian-13", "ansible_scenario": "ansible_latest", "experimental": true, "python_version": "3.13"}]
```

`distro` is a tag of `ghcr.io/rheinwerk/molecule`, `ansible_scenario` one of `ansible_current`,
`ansible_next`, `ansible_latest` or empty for the newest Ansible. `ansible_current` is the ansible-core line the
infrastructure runs (`==2.21.*`), `ansible_next` the line after it (`==2.22.*`; pip takes its pre-releases until the
first release); both are input defaults in [action.yml](action.yml) and are bumped by hand when the infrastructure
moves, `experimental: true` lets the job fail without failing the run. `python_version` follows the Ansible
virtualenv of the images: 3.12 on Debian 12, 3.13 on Debian 13. ansible-core 2.22 needs Python 3.13, so 2.21 is the
last line that runs on Debian 12. Pass your own list as the `matrix` input to add or remove entries.

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
      when: ansible_facts['os_family'] == 'Debian'

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
that the shared converge includes before the role runs. It is a task list, not a playbook; tell ansible-lint
so in the role's `.ansible-lint`, otherwise its syntax check fails on it:

```yaml
kinds:
  - tasks: "**/molecule/default/converge_override.yml"
```

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

# EC2 scenario

[scenarios/ec2](scenarios/ec2) runs the role on a real EC2 instance started from the newest baseimage AMI
of the AWS account, for roles a container cannot test. It runs on demand only, through the reusable
workflow [role-ec2.yml](.github/workflows/role-ec2.yml); a role adds
[examples/molecule-ec2.yml](examples/molecule-ec2.yml) as `.github/workflows/ci-ec2.yml` next to its
normal CI. The AWS side comes from the organisation: the secret `MOLECULE_EC2_ROLE_ARN` (a secret so the
account ID stays out of the public logs) and the variables `MOLECULE_EC2_SUBNET_ID` and
`MOLECULE_EC2_SECURITY_GROUP_ID`.

| Input | Default | Description |
|-------|---------|-------------|
| secret `MOLECULE_EC2_ROLE_ARN` | required | IAM role assumed via GitHub OIDC |
| `subnet_id` | required | Subnet for the instances |
| `security_group_id` | required | Security group for the instances |
| `aws_region` | `eu-central-1` | Region of the subnet and the AMIs |
| `image_env` | `staging` | Value of the AMIs' `Env` tag, empty for any |
| `args` | `''` | Additional arguments for `molecule test` |
| `matrix` | `debian-13`, `ansible_current` | JSON list as for `role.yml`, plus optional `arch` (`amd64`) and `instance_type` (`t3.small`; use `t4g` for `arm64`) |
| `python_version`, `molecule_ref`, `role_repository`, `role_ref` | | as for `role.yml` |

What a run does:

1. `create.yml` picks the newest available AMI named `baseimage_<distro>-*-<arch>` (for example
   `baseimage_debian13-*-amd64`) owned by the account and starts one instance with a public IP, IMDSv2 only,
   no instance profile and the tags `Name`, `Purpose: molecule`, `molecule-repository` and `molecule-run`.
   It creates no security group, key pair or IAM resource. The SSH key of the run goes to the image's
   default user (`cd-admin`) through cloud-init.
2. At boot, before sshd starts, [wipe-image-secrets.sh](scenarios/ec2/files/wipe-image-secrets.sh)
   removes what the image ships for production use: the host keys and host certificates configured in
   sshd (the instance gets fresh host keys), the apt credentials and the apt sources that need them.
   The second play of `create.yml` stops the run if any of it is still there, before any role code runs;
   for this scenario `create.yml`, `destroy.yml`, the user-data template and the wipe script always come from
   this repository, also when a role ships files of the same name (a role's own `prepare.yml` is kept). The files are deleted, not overwritten: this
   keeps them out of the public CI logs by accident (diff output, verbosity), it does not stop a role that
   reads the deleted blocks from the disk on purpose.
3. converge, idempotence and verify run as in the docker scenario, over SSH as `cd-admin` with `become`.
4. `destroy.yml` terminates the instances by their `Name` tag. If it never runs, the instance shuts itself
   down after 90 minutes and the shutdown terminates it, and [ec2-cleanup.yml](.github/workflows/ec2-cleanup.yml)
   terminates every `Purpose: molecule` instance older than 2 hours once an hour.

The workflow files are the trust anchor: the AWS role trusts the OIDC tokens of
`Rheinwerk/molecule/.github/workflows/role-ec2.yml@refs/heads/main` and `ec2-cleanup.yml@refs/heads/main`
(claim `job_workflow_ref`). Keep the file names, and test a branch of this repository with `molecule_ref`: the workflow then still comes from `main`, the
action and the scenario from the branch.

What the account owner sets up (in the CenterDevice staging account):

- an IAM role with a trust policy on the GitHub OIDC provider for `job_workflow_ref` above and `sub` of the
  Rheinwerk repositories, allowed to describe images, subnets and instances, to run instances only from the
  baseimage AMIs into that subnet and security group with `Purpose: molecule` tags, and to terminate only
  instances tagged that way
- a subnet with public IPs and no route to internal services, and a security group with SSH in and all out

Local run, with AWS credentials for that account in the environment and `boto3` from
[requirements/requirements-ec2.txt](requirements/requirements-ec2.txt):

```bash
make test MOLECULE_SCENARIO=ec2 MOLECULE_DISTRO=debian-13 \
  MOLECULE_EC2_SUBNET_ID=subnet-... MOLECULE_EC2_SECURITY_GROUP_ID=sg-... MOLECULE_EC2_IMAGE_ENV=staging
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

- `molecule` and `molecule-plugins` are pinned in
  [requirements/requirements-molecule.txt](requirements/requirements-molecule.txt), which the action installs.
  Molecule installed the newest version before, and a new molecule-plugins release broke every role run in
  2026 by rejecting a key in the shared `molecule.yml`. The `molecule_version` and `molecule_plugins_version`
  inputs override the pins for a single run. `boto3` for the ec2 scenario is pinned in
  [requirements/requirements-ec2.txt](requirements/requirements-ec2.txt).
- The tools of the lint image are pinned in [dockerfiles/requirements-lint.txt](dockerfiles/requirements-lint.txt).
- The Ansible collections for the molecule runs and the lint image are pinned in
  [dockerfiles/collections.yml](dockerfiles/collections.yml).

[Renovate](renovate.json) keeps all three and the GitHub Actions current; every bump of the molecule pins or
the collections runs the smoke test before it can be merged.

# Renovate preset for the roles

[default.json](default.json) is the shared preset for all Rheinwerk roles. A role's `renovate.json` is just

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>Rheinwerk/molecule"]
}
```

It brings `config:recommended` without semantic commit prefixes, the `dependencies` label, one grouped pull
request for GitHub Actions updates, merged automatically once the role's CI is green, and one for Ansible
collections and roles from `requirements.yml`, which stays for review. Roles
pinned to git tags, as in the CenterDevice infrastructure, are updated through Renovate's git-tags datasource.

# Containers

Built by [docker.yml](.github/workflows/docker.yml) weekly and on changes below `dockerfiles/`, for amd64
and arm64, published as `ghcr.io/rheinwerk/molecule:<tag>`.

## lint

Alpine with `ansible-core`, `ansible-lint`, `yamllint`, `black` (pip, pinned) and `shellcheck`, plus the
pinned collections so `ansible-lint --offline` resolves FQCNs.

## debian-12, debian-13

The molecule test targets ([dockerfiles/CI](dockerfiles/CI)): Debian with systemd, cron, dnsmasq, rsyslog.
Debian 12 gets Python 3.12 via [pascalroeleven's backport](https://github.com/pascallj/python3.12-backport)
and `software-properties-common`; Debian 13 uses its own Python 3.13 and has no
`software-properties-common` any more. The default matrix tests both; a role that does not support one of
them passes its own `matrix` input.

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
