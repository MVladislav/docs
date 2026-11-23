---
layout: post
title: CIS - Ubuntu 22.04 (ansible)
categories:
  - CIS
  - Ubuntu
  - Ansible
tags:
  - security
  - hardening
  - linux
  - ubuntu
  - cis
  - ansible
image: /assets/img/headers/ubuntu.png
---

## \\\\ Description

This entry shows how to run the **CIS Ubuntu Linux 22.04 LTS Benchmark v3.0.0**
with the Ansible role
[`ansible-cis-ubuntu-2204`](https://github.com/MVladislav/ansible-cis-ubuntu-2204).
The role applies the benchmark's sections 1-7 and is designed for a **clean
Ubuntu 22.04 install**.

> _For **Ubuntu 24.04** use the sibling role
> [`ansible-cis-ubuntu-2404`](https://github.com/MVladislav/ansible-cis-ubuntu-2404)
> (CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0) - the variable prefix is
> `cis_ubuntu2404_*`._
>
> _This is a **remediation** tool, not an audit tool. It changes SSH, PAM, mounts,
> services, firewall and package state, so snapshot the VM and test in staging
> before running it on a production host._

---

## \\\\ Information - CIS & Ubuntu

CIS (Center for Internet Security) benchmarks are guidelines developed by
cybersecurity experts to help organizations improve the security of their systems
and networks. They provide recommendations for configuring systems and devices to
mitigate cybersecurity risks and threats. By following these guidelines,
organizations can improve their security, ensure consistency, comply with
regulatory requirements, and save costs.

The CIS Benchmarks provide detailed recommendations for configuring Ubuntu systems
to mitigate common cybersecurity risks and threats. These recommendations cover a
wide range of security topics, such as filesystem modules, mount options, network
settings, logging, access control, authentication and user accounts.

By implementing these guidelines, organizations can reduce the risk of cyber
attacks and improve their security posture. This is important for protecting
sensitive data and complying with regulations.

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
- **Clean host:** the role expects a fresh Ubuntu 22.04 install. Snapshot the VM
  or test in a staging environment first.

## \\\\ Prepare - Host System

The role needs **Ansible >= 2.16** and **Python >= 3.12** on the controller. Use a
virtual environment so the distribution's Python stays clean - Debian/Ubuntu
block system-wide `pip` installs (PEP 668):

```sh
sudo apt install python3 python3-venv python3-pip sshpass

python3 -m venv ~/.venvs/ansible
source ~/.venvs/ansible/bin/activate
python -m pip install --upgrade pip
python -m pip install "ansible>=2.16" ansible-lint yamllint
ansible --version
```

> _`sshpass` is only needed when you log in with a password (`-k`). The linters
> are optional, but the role repository uses them in CI._

## \\\\ Prepare - Ansible on Host System

### // clone the project

Ansible looks for roles in a `roles/` directory next to the playbook, so clone the
role there:

```sh
mkdir -p cis-hardening/roles
cd cis-hardening
git clone https://github.com/MVladislav/ansible-cis-ubuntu-2204.git roles/ansible-cis-ubuntu-2204
```

Install the collections the role needs:

```sh
ansible-galaxy collection install -r roles/ansible-cis-ubuntu-2204/requirements.yml
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
          pl_a_host_default_ntp: 192.168.1.1
          pl_a_host_fallback_ntp: 192.168.1.1
          cis_setup_aide: true
          cis_ipv6_required: true
        host2:
          ansible_user: groot
          ansible_host: 192.168.1.11
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519
          pl_a_host_default_ntp: time.cloudflare.com
          pl_a_host_fallback_ntp: time.cloudflare.com
          cis_setup_aide: false
          cis_ipv6_required: false
  vars:
    ansible_python_interpreter: /usr/bin/python3
```

> _`cis_setup_aide` and `cis_ipv6_required` are plain host variables that the
> playbook below maps to the role options, so you only set them once per host.
> Use an `ntp.ubuntu.com` server as fallback when you do not run your own._

### // prepare your playbook

Create `playbook.yml`:

```sh
vim playbook.yml
```

{% raw %}

```yaml
- name: CIS | install on clients
  become: true
  remote_user: "{{ ansible_user }}"
  hosts:
    - clients
  roles:
    - role: ansible-cis-ubuntu-2204
      cis_ubuntu2204_section1: true
      cis_ubuntu2204_section2: true
      cis_ubuntu2204_section3: true
      cis_ubuntu2204_section4: true
      cis_ubuntu2204_section5: true
      cis_ubuntu2204_section6: true
      cis_ubuntu2204_section7: true
      # -------------------------
      # Prevent SSH lockout: the role removes password login and root login.
      # Use a user + real public key, or the rule is skipped.
      cis_ubuntu2204_rule_5_1_24: true
      cis_ubuntu2204_rule_5_1_24_ssh_user: "{{ ansible_user }}"
      cis_ubuntu2204_rule_5_1_24_ssh_pub_key: "<ADD_PUB_KEY>"
      # -------------------------
      # AppArmor: start in complain mode, switch to enforce after testing.
      cis_ubuntu2204_rule_1_3_1_3: true # complain mode
      cis_ubuntu2204_rule_1_3_1_4: false # enforce mode
      # -------------------------
      # GRUB password: keep it disabled for unattended hosts, otherwise set a password.
      cis_ubuntu2204_set_boot_pass: false
      cis_ubuntu2204_disable_boot_pass: true
      # -------------------------
      # Keep squashfs so snap packages keep working (CIS would disable it).
      cis_ubuntu2204_rule_1_1_1_7: false # squashfs (snap)
      # -------------------------
      # Keep USB storage and Bluetooth on client machines that need them.
      cis_ubuntu2204_rule_1_1_1_9: false # usb-storage
      cis_ubuntu2204_rule_3_1_3: false # bluetooth service
      cis_ubuntu2204_rule_3_1_3_remove: false
      # -------------------------
      cis_ubuntu2204_allow_gdm_gui: true
      cis_ubuntu2204_allow_autofs: true # true = keep autofs (do not disable)
      cis_ubuntu2204_allow_cups: true
      # -------------------------
      cis_ubuntu2204_time_synchronization_service: chrony # chrony | systemd-timesyncd
      cis_ubuntu2204_time_synchronization_time_server:
        - uri: "{{ pl_a_host_default_ntp | default('time.cloudflare.com') }}"
          config: iburst
        - uri: "{{ pl_a_host_fallback_ntp | default('ntp.ubuntu.com') }}"
          config: iburst
      # -------------------------
      cis_ubuntu2204_install_aide: "{{ cis_setup_aide | default(false) | bool }}"
      cis_ubuntu2204_config_aide: "{{ cis_setup_aide | default(false) | bool }}"
      cis_ubuntu2204_aide_cron:
        cron_user: root
        cron_file: aide
        aide_job: "/usr/bin/aide.wrapper --config /etc/aide/aide.conf --check"
        aide_minute: 0
        aide_hour: 5
        aide_day: "*"
        aide_month: "*"
        aide_weekday: "*"
      # -------------------------
      cis_ubuntu2204_journald_system_max_use: 4G
      cis_ubuntu2204_journald_system_keep_free: 8G
      cis_ubuntu2204_journald_runtime_max_use: 256M
      cis_ubuntu2204_journald_runtime_keep_free: 512M
      cis_ubuntu2204_journald_max_file_sec: 1month
      # -------------------------
      cis_ubuntu2204_preferred_capturing_log_method: journald # journald | rsyslog
      # -------------------------
      cis_ubuntu2204_required_ipv6: "{{ cis_ipv6_required | default(false) | bool }}"
      cis_ubuntu2204_firewall: ufw # ufw | nftables | iptables
      # -------------------------
      cis_ubuntu2204_cron_allow_users:
        - root
      cis_ubuntu2204_at_allow_users:
        - root
      # -------------------------
      cis_ubuntu2204_faillock_deny: 5
      cis_ubuntu2204_faillock_unlock_time: 900
      cis_ubuntu2204_faillock_minlen: 14
      cis_ubuntu2204_password_complexity:
        - key: "minclass"
          value: "3"
        - key: "dcredit"
          value: "-1"
        - key: "ucredit"
          value: "-1"
        - key: "ocredit"
          value: "-1"
        - key: "lcredit"
          value: "-1"
      # -------------------------
```

{% endraw %}

> _`<ADD_PUB_KEY>` must be replaced with a real `ssh-ed25519`/`ssh-rsa` public key.
> With the placeholder left in place the role cannot log you back in after it
> disables password authentication. Keep a console/IPMI session open for the first
> run._

Important switches and their defaults:

| Variable                                              | Default        | Effect                                                          |
| :---------------------------------------------------- | :------------- | :-------------------------------------------------------------- |
| `cis_ubuntu2204_rule_1_1_1_9`                         | `true`         | disables `usb-storage`; set `false` if USB storage is needed    |
| `cis_ubuntu2204_rule_1_1_1_7`                         | `true`         | disables `squashfs`; set `false` to keep snap packages working  |
| `cis_ubuntu2204_allow_gdm_gui`                        | `false`        | `false` purges the GUI; set `true` on desktops                  |
| `cis_ubuntu2204_allow_autofs`                         | `false`        | `true` keeps `autofs`, `false` disables it                      |
| `cis_ubuntu2204_allow_cups`                           | `false`        | `true` keeps CUPS printing                                      |
| `cis_ubuntu2204_required_ipv6`                        | `false`        | `true` keeps IPv6 enabled                                       |
| `cis_ubuntu2204_rule_1_3_1_3` / `_1_3_1_4`            | `true`/`false` | AppArmor complain vs enforce mode                               |
| `cis_ubuntu2204_set_boot_pass` / `_disable_boot_pass` | `false`/`true` | set or remove the GRUB password                                 |
| `cis_ubuntu2204_rule_3_1_3` / `_3_1_3_remove`         | `true`/`true`  | disable/remove Bluetooth (keep `false` on clients that need it) |
| `cis_ubuntu2204_firewall`                             | `ufw`          | `ufw`, `nftables` or `iptables` - pick the one you actually use |
| `cis_ubuntu2204_time_synchronization_service`         | `chrony`       | `chrony` or `systemd-timesyncd` - never both                    |
| `cis_ubuntu2204_faillock_minlen`                      | `14`           | minimum password length; CIS recommends `14`                    |

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
ansible -i inventory.yml clients -m shell -a 'sudo ufw status verbose'
ansible -i inventory.yml clients -m shell -a 'sudo aa-status'
ansible -i inventory.yml clients -m shell -a 'sudo systemctl status auditd --no-pager'
ansible -i inventory.yml clients -m shell -a "sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|kbdinteractiveauthentication'"
```

---

## \\\\ Resources & More information

- <https://github.com/MVladislav/ansible-cis-ubuntu-2204>{:target="\_blank"}
- <https://github.com/MVladislav/ansible-cis-ubuntu-2404>{:target="\_blank"}
- <https://downloads.cisecurity.org/>{:target="\_blank"}
