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
# The following variables are used to populate templates/docker18.09.conf for the sysctl configuration
docker_unit_after: "network.target docker.socket" # Goes into "[Unit] After=", e.g. 
docker_storage_driver: overlay # The storage driver to use with docker

# The command to be run to update the bootloader
bootloader_update_command: # e.g. update-bootloader on SLES

# The docker version mapping is used to easily support multiple docker versions
docker_version_map:
  # The version of docker to be installed, this value is referenced in defaults/main.yml (e.g. docker_version: "18.09")
  "18.09": 
    # The package name to be installed for this version
    package: docker-18.09.1_ce 
    # The repository that needs to be added for the docker package
    repo: https://download.opensuse.org/repositories/Virtualization:containers/SLE_12_SP3/ 
    name: Virtualization:containers # The name of the repository, if one is required
    keys:
      # The url from where to fetch the key for the repositry
      server: http://download.opensuse.org/repositories/Virtualization:/containers/SLE_12_SP3/repodata/repomd.xml.key
      # The id of the key
      id:
```

See `vars/os_Ubuntu_16.yml` as an example.

**2)** Add a folder `DISTRIBUTION-MAJORVERSION` to `tasks/base/`

This folder must at least contain a file `main.yml`. Normally `main.yml` only includes playbooks which then contain the specific tasks.
The specific tasks must include installing docker and other required packages (see [tasks/base/Ubuntu-16](tasks/base/Ubuntu-16)).
