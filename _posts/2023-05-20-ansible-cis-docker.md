---
layout: post
title: CIS - Docker (ansible)
categories:
  - CIS
  - Docker
  - Ansible
tags:
  - security
  - hardening
  - linux
  - ubuntu
  - docker
  - cis
  - ansible
image: /assets/img/headers/docker.png
---

## \\\\ Description

This entry shows how to install Docker and apply the **CIS Docker Benchmark v1.9.0**
with the Ansible role [`ansible-docker`](https://github.com/MVladislav/ansible-docker).
The role installs Docker CE, writes a hardened `daemon.json`, configures audit
rules and applies the CIS controls from the benchmark.

> _The role is a **remediation** tool, not an audit tool. It is developed against a
> clean install and supports Ubuntu 22.04, 23.04, 24.04, 25.04 and 26.04.
> Review its tasks before running it against an existing host._

---

## \\\\ Information - CIS & Docker

CIS (Center for Internet Security) benchmarks are guidelines developed by
cybersecurity experts to help organizations improve the security of their systems
and networks. They provide recommendations for configuring systems and devices to
mitigate cybersecurity risks and threats. By following these guidelines,
organizations can improve their security, ensure consistency, comply with
regulatory requirements, and save costs.

Docker is an open-source platform that allows developers to build, ship and run
applications in containers. Containers are isolated environments that include all
the necessary components to run an application, such as code, libraries and
system tools.

By setting up Docker and implementing CIS controls on client machines,
organizations can achieve several benefits:

- **Security:** Docker containers isolate applications from the host system, and
  the CIS controls harden the host and the Docker daemon against attacks.
- **Portability:** containers can be moved between environments, which makes it
  easier to deploy applications across multiple machines.
- **Efficiency:** containers are lightweight and need fewer resources than
  traditional virtual machines.
- **Consistency:** the same container image runs the same way across
  environments, which reduces errors and compatibility issues.

---

> Before making any changes to software, systems, or devices,
> it's **important to thoroughly read and understand the configuration options**,
> and verify that the proposed changes align with your requirements.
> This can help avoid unintended consequences and ensure the software, system, or device operates as intended.
> {: .prompt-warning }

---

## \\\\ Prepare - Target Systems

- **SSH access:** Ansible communicates with the target systems over SSH, so SSH
  must be reachable and you need a working login (key or password).
- **Python:** Ansible requires Python 3 on the targets. Ubuntu ships it by
  default; if it is missing, install `python3` before running the role.
- **Privilege escalation:** the role needs root, so the SSH user must be able to
  `sudo` (the playbook uses `become: true`).
- **Clean host:** the role assumes a fresh Ubuntu install. Snapshot the VM or
  test in a staging environment first.

## \\\\ Prepare - Host System

The role needs **Ansible >= 2.16**. Use a Python virtual environment so the
distribution's Python stays clean - Debian/Ubuntu block system-wide `pip`
installs (PEP 668), and `--break-system-packages` is avoidable:

```sh
sudo apt install python3 python3-venv python3-pip sshpass

python3 -m venv ~/.venvs/ansible
source ~/.venvs/ansible/bin/activate
python -m pip install --upgrade pip
python -m pip install "ansible>=2.16"
ansible --version
```

> _`sshpass` is only needed when you log in with a password (`-k`). If you use SSH
> keys, you can omit it. If Ansible >= 2.16 is already installed system-wide, skip
> the virtual environment._

## \\\\ Prepare - Ansible on Host System

### // clone the project

Ansible looks for roles in a `roles/` directory next to the playbook, so clone the
role there:

```sh
mkdir -p cis-docker/roles
cd cis-docker
git clone https://github.com/MVladislav/ansible-docker.git roles/ansible-docker
```

Install the collections the role needs:

```sh
ansible-galaxy collection install -r roles/ansible-docker/requirements.yml
```

### // prepare your inventory

Create `inventory.yml` and change the host variables to your needs:

```sh
vim inventory.yml
```

```yaml
all:
  children:
    clients:
      hosts:
        host1:
          ansible_user: groot
          ansible_host: 192.168.1.10
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519
          cis_docker_rule_2_1: false # false = rootful install, true = rootless
          cis_docker_is_swarm_mode: true # true = allow swarm mode
        host2:
          ansible_user: groot
          ansible_host: 192.168.1.11
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519
          cis_docker_rule_2_1: false
          cis_docker_is_swarm_mode: false
  vars:
    ansible_python_interpreter: /usr/bin/python3
```

> _Host variables override the role defaults, so the per-host `cis_docker_*`
> values above are picked up without repeating them in the playbook._

### // prepare your playbook

Create `playbook.yml`:

```sh
vim playbook.yml
```

{% raw %}

```yaml
- name: DOCKER | CIS | install on clients
  become: true
  remote_user: "{{ ansible_user }}"
  hosts:
    - clients
  roles:
    - role: ansible-docker
      cis_docker_user_shell: /bin/bash
      cis_docker_users_to_add_group:
        - name: "{{ ansible_user }}"
      cis_docker_storage_driver: overlay2
      # -------------------------
```

{% endraw %}

Check the role defaults and the README before changing more options. The most
important switches:

| Variable                         | Default    | Effect                                                                                    |
| :------------------------------- | :--------- | :---------------------------------------------------------------------------------------- |
| `cis_docker_rule_2_1`            | `false`    | `false` = rootful daemon, `true` = **rootless** install (per-user daemon, no swarm mode)  |
| `cis_docker_is_swarm_mode`       | `false`    | `true` allows Docker swarm; disables rule 2.16 (`live-restore` cannot be used with swarm) |
| `cis_docker_rule_2_2`            | `false`    | `true` blocks traffic between containers on the default bridge                            |
| `cis_docker_rule_2_10`           | `false`    | `true` enables user-namespace isolation                                                   |
| `cis_docker_users_to_add_group`  | `[]`       | users added to the `docker` group                                                         |
| `cis_docker_storage_driver`      | `overlay2` | storage driver (`overlay2`, `vfs`, `btrfs`, `zfs`)                                        |
| `cis_docker_apparmor_workaround` | `false`    | sets `runc` to `unconfined` (only for AppArmor problems)                                  |
| `cis_docker_ufw_fix`             | `false`    | adds a Docker rule to `/etc/ufw/after.rules`                                              |

> _Adding a user to the `docker` group is effectively root access on that host.
> Prefer `cis_docker_rule_2_1: true` (rootless) when you can. Rootless Docker
> cannot run swarm mode, so do not enable both._

### // run the role

Check connectivity first, then test the playbook, then apply it:

```sh
ansible -i inventory.yml clients -m ping

# dry run: shows what would change, changes nothing
ansible-playbook -i inventory.yml playbook.yml --ask-become-pass --check --diff

# apply
ansible-playbook -i inventory.yml playbook.yml --ask-become-pass
```

> _Options:_
>
> - `-k` - prompt for the SSH password (omit it when using keys)
> - `--ask-become-pass` - prompt for the sudo password on the target
> - `--check --diff` - dry run and show the file diffs

### // verify

```sh
ansible -i inventory.yml clients -m shell -a 'docker version'
ansible -i inventory.yml clients -m shell -a 'docker info'
ansible -i inventory.yml clients -m shell -a 'docker run --rm hello-world'
```

---

## \\\\ Resources & More information

- <https://github.com/MVladislav/ansible-docker>{:target="\_blank"}
- <https://downloads.cisecurity.org>{:target="\_blank"}
- <https://docs.docker.com/engine/security/>{:target="\_blank"}
