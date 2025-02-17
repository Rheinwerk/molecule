# Molecule

Github Action to use Molecule for Ansible Tests

# Containers

## Lint

Based on latest alpine with following software:
- bash
- curl
- ansible-lint
- shellcheck
- yamllint

## Ubuntu

Upstream Ubuntu 20.04 / 22.04 | Debian 12 Docker Container with following extensions:

- Cron
- DNSmasq
- GnuPG
- Python3
- Rsyslog
- SystemD
...

# Usage

## CI Workflow
To use this action in your repo you can create a new Github Workflow with the example [molecule.yml](examples/molecule.yml)

This will test your role against the following Ansible Scenarios:
- `ansible_current`
- `ansible_next`
- `ansible_latest`

Used Ansible Version for these scenarios are defined in [action.yml](examples/action.yml), but can be overridden. Leave `ansible_scenario` unset for simple tests against latest ansible and molecule version.

# Configuration
## Only Lint, no Molecule Tests

If your role is not testable inside a Container ( no AWS credentials, hardware related playbook ... ) you can still use the linting,
by setting the following attribute in your roles `meta/main.yml`

```yaml
galaxy_info:
...
  min_ansible_container_version: "X"
...
```

## Allow CI matrix jobs to fail

If you want to include tests which are not mandatory, mark them as `experimental: true`

```yaml
....
  molecule:
    ...
    strategy:
      fail-fast: false
      matrix:
        include:
          ...
          - distro: ubuntu-22.04
            test_type: unit
            python_version: '3.10'
            experimental: true

```

## Include prerequisite role

* Create `molecule/default/requirements.yml` inside the repository with following content and replace values as needed:

```yaml
- src: https://github.com/Rheinwerk/ansible-role-example.git
  name: example
  scm: git

```

* Create `molecule/default/converge.yml` inside the repository with following content, replacing `example` as needed:

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

The prerequisite role is included only in the converge stage of molecule, but not in idempotence test cause of the declaration:
`when: "'molecule-idempotence-notest' not in ansible_skip_tags"`


## Disable idempotence check on
- https://molecule.readthedocs.io/en/stable/configuration.html#id8

### Whole role

Create `molecule/default/converge.yml` inside the repository with following content:

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

## Skip idempotence check on

### Whole role

Create `molecule/default/converge.yml` inside the repository with following content, replacing `example` as needed:

```yaml
...
  tasks:
    # skip idempotence tests
    - name: Include Example install role
      ansible.builtin.include_role:
        name: example
      when: "'molecule-idempotence-notest' not in ansible_skip_tags"
...
```
