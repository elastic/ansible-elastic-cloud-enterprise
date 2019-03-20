# ansible-elastic-cloud-enterprise

Ansible role for installing [Elastic Cloud Enterprise](https://www.elastic.co/products/ece) and preparing hosts for it.

## Contents of this role

A minimal example of a playbook might look like this:

```yaml
---
- hosts: primary
  gather_facts: true
  roles:
    - elastic-cloud-enterprise
  vars:
    ece_primary: true

- hosts: secondary
  gather_facts: true
  roles:
    - elastic-cloud-enterprise
  vars:
    ece_roles: [director, coordinator, proxy]
```

At least two hosts are needed for this example, a primary and a secondary host. The example above would execute the following high level steps on the defined hosts:
- On all hosts:
  - Remove an existing docker installation
  - Install required general packages
  - Install a current, supported docker version
  - Create required users and set limits for them
  - Create a xfs partition and configure it
  - Configure docker
- On the primary host:
  - Make the primary installation of Elastic Cloud Enterprise 
- On the secondary host:
  - Install Elastic Cloud Enterprise to join the existing installation with the given ece_roles

There is a set of variables and tags available to further define the behaiviour of this role, or exclude certain steps.


## Role Variables

The following variables are avaible:

- `device_name`: The name of the device on which the xfs partition should be created
    - **Required** unless filestystem tasks are skipped via tags
    - Default: xvdb
- `ece_primary`: Whether this host should be the primary (first) host where Elastic Cloud Enterprise is installed
    - **Required** on a single host
- `ece_roles`: Elastic Cloud Enterprise roles that successive hosts should assume
    - Default: [director, coordinator, proxy, allocator]
- `availability_zone`: The availability zone this group of hosts belongs to
- `ece_version`: The Elastic Cloud Enterprise version that should get installed
    - Default: 2.1.0
- `ece_docker_registry`: The docker registry from where to pull the Elastic Cloud Enterprise images. This is only relevant if you have a private mirror 
    - Default: docker.elastic.co
- `ece_docker_repository`: The docker repository in the given registry. This is only relevant if you have a private mirror
    - Default: cloud-enterprise
- `docker_config`: If specified as a path to a docker config, copies it to the target hosts

If more hosts should join an Elastic Cloud Enterpise installation when a primary host was already installed previously there are two more variables that are required:
- `primary_hostname`: The (reachable) hostname of the primary host
- `adminconsole_root_password`: The adminconsole root password


## Role Tags

The following tags are available to limit the execution:
- `system` Determines the execution of all tasks that setup the system (everything except the actual installation of Elastic Cloud Enterprise) 
    - `setup_filesystem` If system tasks are executed, this determines if the filesystem tasks should get executed - includes creating the partitions for xfs and mount points 
    - `install_docker` If system tasks are executed, this determines if existing docker packages should get removed and the current, supported version should get installes
- `ece` Determines if Elastic Cloud Enterprise should get installed


## Examples and use cases

### Medium sized first installation of Elastic Cloud Enterprise

This example installs Elastic Cloud Enterprise as detailed in "A medium installation with separate management services" [in the official documentation](https://www.elastic.co/guide/en/cloud-enterprise/current/ece-topology-example2.html) and brings you up to *step 5 - Modify the first host you installed Elastic Cloud Enterprise on*

`site.yml`:
```yaml
- hosts: primary
  roles:
    - elastic-cloud-enterprise
  vars:
    ece_primary: true

- hosts: director_coordinator
  roles:
    - elastic-cloud-enterprise
  vars:
    ece_roles: [director, coordinator, proxy]

- hosts: allocator
  roles:
    - elastic-cloud-enterprise
  vars:
    ece_roles: [allocator]
```

Assuming all hosts have the device name in common the `inventory.yml` could look like this:
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
    - elastic-cloud-enterprise
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
