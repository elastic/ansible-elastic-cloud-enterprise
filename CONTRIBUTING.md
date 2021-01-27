# Contributing

## Adding a new distribution

Ansible automatically determines on which distribution it is executing a playbook.

In `tasks/base/main.yml` tasks and variables are dynamically included depending on the distribution of the host they are run on. 

```yaml
- name: Include OS specific vars
  include_vars: "{{ item }}"
  with_first_found:
  - os_{{ ansible_distribution }}_{{ ansible_distribution_major_version }}.yml
  - unsupported.yml

- name: execute os specific tasks
  include_tasks: "{{ item }}"
  with_first_found:
  - "{{ ansible_distribution }}-{{ ansible_distribution_major_version}}/main.yml"
  - unsupported.yml
```
This means:
- All distribution specific *variables* go into `vars/os_DISTRIBUTION_MAJORVERSION.yml` (e.g. `os_Ubuntu_16.yml`)
- All distribution specific *tasks* go in `tasks/base/DISTRIBUTION-MAJORVERSION/`

Distribution specific tasks are executed prior to all general tasks and include e.g. installing specific packages.

Therefore to add a new distribution the following steps need to be done:

**1)** Add a file to `vars` with the naming scheme of `os_DISTRIBUTION_MAJORVERSION.yml`
Inside this file at least the following needs to be specified (example from `vars/os_SLES_12.yml`):

```yaml
---
# The following variables are used to populate templates/docker19.03.conf for the sysctl configuration
---
docker_unit_after: "network.target docker.socket"
docker_storage_driver: overlay
bootloader_update_command: update-bootloader

# Docker version mapping
docker_version_map:
  "19.03":
    package: docker-19.03.14_ce
```

See `vars/os_Ubuntu_16.yml` as an example.

**2)** Add a folder `DISTRIBUTION-MAJORVERSION` to `tasks/base/`

This folder must at least contain a file `main.yml`. Normally `main.yml` only includes playbooks which then contain the specific tasks.
The specific tasks must include installing docker and other required packages (see [tasks/base/Ubuntu-16](tasks/base/Ubuntu-16)).
