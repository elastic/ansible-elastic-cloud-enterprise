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

# Docker version mapping.
# "N" is latest of that major; "N.M" is that minor line only.
docker_version_map:
  "19.03":
    package: docker-19.03.14_ce
```

See `vars/os_Ubuntu_16.yml` as an example.

**2)** Add a folder `DISTRIBUTION-MAJORVERSION` to `tasks/base/`

This folder must at least contain a file `main.yml`. Normally `main.yml` only includes playbooks which then contain the specific tasks.
The specific tasks must include installing docker and other required packages (see [tasks/base/Ubuntu-16](tasks/base/Ubuntu-16)).

## Running ECE PrSuite from a role PR

This repo is public and has no ECE environment of its own. The `ansible-ece-prsuite`
Buildkite pipeline `trigger`s `cloud-integration-ece-matcher-tests` on
`elastic/cloud` `master` with `ANSIBLE_ECE_BRANCH` set to this PR's branch.

Elastic org members can start it by:

- Commenting `run ece` or `run ece/tests` on the pull request (after the
  [pr-bot webhook](https://docs.elastic.dev/ci/configuring-pull-requests-for-buildkite) is registered), or
- **New Build** on [ansible-ece-prsuite](https://buildkite.com/elastic/ansible-ece-prsuite) for the PR branch

Fork PRs are not built. GitHub pushes do not start ECE. The parent build waits
for matcher and reports a GitHub check; it does not post Buildkite URLs as PR
comments.

Default combo is Ubuntu 22.04 / Docker 25 (Ansible-provisioned on cloud
`master`). Images come from the latest cloud `master` build
(`ECE_TEST_USE_LATEST_AVAILABLE_IMAGES`).

Terrazzo creates the pipeline from `catalog-info.yaml` after this lands on
`master`. `elasticmachine` needs at least Read on the repo for comment
triggers.
