# Molecule

Github Action to use Molecule for Ansible Tests

# Usage

## CI Workflow
To use this action in your repo you can create a new Github Workflow with the example [molecule.yml](examples/molecule.yml)

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
