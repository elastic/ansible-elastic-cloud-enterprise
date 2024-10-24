# ansible-elastic-cloud-enterprise

Ansible role for installing [Elastic Cloud Enterprise](https://www.elastic.co/products/ece) and preparing hosts for it.

Please note that the ECE Ansible playbook is not officially supported by Elastic, but rather a community project. Elastic welcomes all community contributions to the repository and will validate any changes on a best-effort basis.

## Requirements

This role is tested against Ansible 2.8.7.

## Contents of this role

A minimal example of a [small playbook](https://www.elastic.co/guide/en/cloud-enterprise/current/ece-install-small-cloud.html) might look like this:

```yaml
---
- hosts: primary
  gather_facts: true
  roles:
    - ansible-elastic-cloud-enterprise
  vars:
    ece_primary: true

- hosts: secondary
  gather_facts: true
  roles:
    - ansible-elastic-cloud-enterprise
  vars:
    ece_roles: [director, coordinator, proxy, allocator]

- hosts: tertiary
  gather_facts: true
  roles:
    - ansible-elastic-cloud-enterprise
  vars:
    ece_roles: [director, coordinator, proxy, allocator]
```

At least three hosts are needed for this example, a primary, a secondary, and tertiary host. The example above would execute the following high level steps on the defined hosts:
- On all hosts:
  - Remove an existing docker installation
  - Install required general packages
  - Install a current, supported docker version
  - Create required users and set limits for them
  - Create a xfs partition and configure it
  - Configure docker

More information about the prerequisites can be found in the following [page](https://www.elastic.co/guide/en/cloud-enterprise/current/ece-prereqs.html).
- On the primary host:
  - Make the primary installation of Elastic Cloud Enterprise
- On the secondary host:
  - Install Elastic Cloud Enterprise to join the existing installation with the given ece_roles
- On the tertiary host:
  - Install Elastic Cloud Enterprise to join the existing installation with the given ece_roles

There is a set of variables and tags available to further define the behaviour of this role, or exclude certain steps.

For example in many cases you might want to install Elastic Coud Enterprise without running any of the potentially destructive system prerequisites like removing existing docker installations and setting up a filesystem. This can be done by specifying `--skip-tags destructive` on your ansible run - or if you want to only install Elastic Coud Enterprise without any system tasks before `--tags bootstrap`.


## Role Variables

The following variables are avaible:

- `device_name`: The name of the device on which the xfs partition should be created
    - **Required** unless filesystem tasks are skipped via tags
    - Default: xvdb
- `ece_primary`: Whether this host should be the primary (first) host where Elastic Cloud Enterprise is installed
    - **Required** on a single host
- `data_dir`: Which directory to mount the xfs partition under
    - Default: `/mnt/data`
- `ece_roles`: Elastic Cloud Enterprise roles that successive hosts should assume
    - Default: [director, coordinator, proxy, allocator]
- `capacity`: [Amount of memory to grant to the allocator](https://www.elastic.co/guide/en/cloud-enterprise/current/ece-manage-capacity.html#ece-alloc-memory)
    - Default: left empty, installer default behavior will be applied
- `availability_zone`: The availability zone this group of hosts belongs to
- `ece_version`: The Elastic Cloud Enterprise version that should get installed
    - Default: 2.8.1
- `ece_docker_registry`: The docker registry from where to pull the Elastic Cloud Enterprise images. This is only relevant if you have a private mirror
    - Default: docker.elastic.co
- `ece_docker_repository`: The docker repository in the given registry. This is only relevant if you have a private mirror
    - Default: cloud-enterprise
- `ece_installer_url`: The url of the installation script to download.
    - Default: `https://download.elastic.co/cloud/elastic-cloud-enterprise.sh`
    - This will use the local script if existing in `/home/elastic/elastic-cloud-enterprise.sh`
- `ece_installer_path`: The location of the installation script on the controller machine. It will be copied to remote host. 
    - Default: left empty, it will download it from internet (cf. `ece_installer_url`)
- `docker_config`: If specified as a path to a docker config, copies it to the target hosts
- [Supported Docker Versions](https://www.elastic.co/guide/en/cloud-enterprise/2.7/ece-software-prereq.html#ece-linux-docker)
  - `docker_version`: Last supported version on Centos 7/8 and RHEL 7/8 is 20.0, Ubuntu 16, Ubuntu 18 and SLES 12 is 19.03.
- `docker_bridge_ip `: The default IP of the docker bridge. Configurable to avoid overlapping with the current host subnet.
- `force_xfc`: By default if the `lxc` xfc volume already exists, the `setup_xfc` step is skipped, if this is set to true, creation of the volume is forced
    - Default: false
- `elastic_authorized_keys_file`: Defines a local path to an `authorized_keys` file that should be copied to the `elastic` user. If not set, the keys from the default user that is used with ansible will be copied over.
- `memory`: Defines the JVM heap size to be used for different services running in ece. See https://www.elastic.co/guide/en/cloud-enterprise/2.7/ece-jvm.html for example values and [defaults/main.yml](defaults/main.yml) for the default values.

- `fetch_diagnostics`: Determines if Elastic Cloud Enterprise Support Diagnostics should be downloaded and executed
- `ece_supportdiagnostics_url`: THe location of the diagnostics tool. Can be a local file for offline installation.
    - Default: `https://github.com/elastic/ece-support-diagnostics/archive/v1.1.tar.gz`
- `ece_supportdiagnostics_result_path`: The localtion where to store the diagnostic bundles on ansible host.
    - Default: `/tmp/ece-support-diagnostics`
- `ece_runner_id`: Assigns an arbitrary ID to the host (runner) that you are installing Elastic Cloud Enterprise on
    - Default: `ansible_default_ipv4.address`

If more hosts should join an Elastic Cloud Enterpise installation when a primary host was already installed previously there are two more variables that are required:
- `primary_hostname`: The (reachable) hostname of the primary host
- `adminconsole_root_password`: The adminconsole root password


## Role Tags

The following tags are available to limit the execution, due to the nature of tags in ansible you should only use `--skip-tags` with these to skip certain parts instead of using `--tags` to limit the execution.

- `base` Determines the execution of all tasks that setup the system (everything except the actual installation of Elastic Cloud Enterprise)
    - `setup_filesystem` If system tasks are executed, this determines if the filesystem tasks should get executed - includes creating the partitions for xfs and mount points
    - `install_docker` If system tasks are executed, this determines if existing docker packages should get removed and the current, supported version should get installed and configured
- `destructive` This tag indicates whether a task is potentially destructive, like removing packages or doing filesystem partitioning
- `ece` Determines if Elastic Cloud Enterprise should get installed
- `vmimage` Prepare the system for building a Virtual Machine Image (Amazon AMI, ...). This will install a cloud-init script which will auto-discover and mount disk selected when an instance is launched with this image.
- `bootstrap` This tags should be picked for only installing Elastic Cloud Entreprise itself (no prerequistes)

By default, all tags are applied, except `vmimage`, which means that it will install all prerequisites and Elastic Cloud Entreprise.
In order to use this ansible playbook for building a VM image, the following tags should be selected: `--tags base,vmimage` (this won't install Elastic Cloud Enterprise)

## Examples and use cases

### Medium sized first installation of Elastic Cloud Enterprise

This example installs Elastic Cloud Enterprise as detailed in "A medium installation with separate management services" [in the official documentation](https://www.elastic.co/guide/en/cloud-enterprise/current/ece-install-medium-cloud.html) and brings you up to *step 5 - Modify the first host you installed Elastic Cloud Enterprise on*

`site.yml`:
```yaml
- hosts: primary
  roles:
    - ansible-elastic-cloud-enterprise
  vars:
    ece_primary: true

- hosts: director_coordinator
  roles:
    - ansible-elastic-cloud-enterprise
  vars:
    ece_roles: [director, coordinator, proxy]

- hosts: allocator
  roles:
    - ansible-elastic-cloud-enterprise
  vars:
    ece_roles: [allocator]
```

Assuming all hosts have the device name in common the `inventory.yml` could look like this:
```yaml
all:
  vars:
    ansible_become: yes
    device_name: sdb
  children:
    primary:
      hosts:
        host1:
          availability_zone: zone-1
    director_coordinator:
      hosts:
        host2:
          availability_zone: zone-2
        host3:
          availability_zone: zone-3
    allocator:
      hosts:
        host4:
          availability_zone: zone-1
        host5:
          availability_zone: zone-2
        host6:
          availability_zone: zone-3
```

### Adding hosts to an existing installation

Assuming you already have an existing installation of Elastic Cloud Enterprise and you want to add more allocators to it you need to specify two additional variables:
- `primary_hostname`: The (reachable) hostname of the primary host
- `adminconsole_root_password`: The adminconsole root password

The corresponding `site.yml` could then look like:

```yaml
- hosts: allocator
  roles:
    - ansible-elastic-cloud-enterprise
  vars:
    ece_roles: [allocator]
    primary_hostname: host1
    adminconsole_root_password: secret_password
```

With the `inventory.yml`
```yaml
all:
  vars:
    ansible_become: yes
    device_name: sdb
  children:
    allocator:
      hosts:
        host7:
          availability_zone: zone-1
        host8:
          availability_zone: zone-2
        host9:
          availability_zone: zone-3
```

### Performing an upgrade

You only need to run the upgrade on a single host, it will then automatically propagate to all other hosts.
An upgrade is usually performed on the first host you installed Elastic Cloud Enterprise on, but it can also be run from any host that holds the director role.

Assuming you have an installation of Elastic Cloud Enterprise 2.1.0 and want to upgrade to 2.2.0 `site.yml` could then look like:
```yaml
- hosts: upgradehost
  roles:
    - ansible-elastic-cloud-enterprise
  vars:
    ece_version: 2.2.0
```

with `inventory.yml`
```yaml
all:
  children:
    upgradehost:
      hosts:
        host1:
```

It is important that you then specify `--tags bootstrap` when you run the playbook in order to only perform the Elastic Cloud Enterprise update and no other tasks, especially when the initial installation was not done with this role.
```bash
ansible-playbook -i inventory.yml site.yml --tags bootstrap
```

### Building a base Virtual Machine Image
Building a Virtual Machine Images depends on the tools and platform you are using. Once a base instance is running, you can use a playbook like the following:
```yaml
- hosts: all
  become: true
  roles:
    - ansible-elastic-cloud-enterprise
```

And ansible should be run with `--tags base,vmimage`, this will install prerequisites for Elastic Cloud Entreprise, but not Elastic Cloud Entreprise.
Finally, you will be able to save the instance as VM image (depending on your cloud provider)

Once the image is ready, you can use it as a base to install Elastic Cloud Entreprise, either from the boostraper script, or with ansible, using `--tags bootstrap` (this will install only Elastic Cloud Entreprise)

## Extending and Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details on how to contribute and extend the Elastic Cloud Enterprise role.
