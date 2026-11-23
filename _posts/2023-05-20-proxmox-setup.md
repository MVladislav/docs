---
layout: post
title: Proxmox Setup
categories:
  - Infrastructure
  - Proxmox
tags:
  - security
  - hardening
  - linux
  - proxmox
image: /assets/img/headers/proxmox.png
---

## \\\\ Information - Proxmox

Proxmox is an open-source virtualization management platform that combines the power of virtualization
and containerization. It allows you to run and manage virtual machines (VMs) and containers on a single
server, providing a flexible and efficient infrastructure for hosting and managing your applications.

At its core, Proxmox is built on two key components:

- KVM (Kernel-based Virtual Machine) for hardware-based virtualization and
- LXC (Linux Containers) for lightweight containerization.

This combination offers a versatile environment where you can create and deploy different types
of workloads, whether they require full isolation and dedicated resources (VMs) or share the underlying
operating system (containers).

Proxmox provides a web-based interface that makes it easy to manage your virtualization infrastructure.
Through the intuitive interface, you can create, configure, and monitor VMs and containers, allocate resources,
and perform live migrations between hosts without service interruptions. The platform also offers a rich
set of features, including high availability clustering, backup and restore capabilities, and comprehensive
monitoring tools to ensure the reliability and performance of your virtualized environment.

One of the significant advantages of Proxmox is its open-source nature, which means it is freely available
for use and can be customized and extended to meet specific requirements. This makes it an ideal choice for
small to medium-sized businesses, educational institutions, and even enthusiasts who want to set up their
own virtualization infrastructure without incurring high costs.

Proxmox is useful in a variety of scenarios, including server consolidation, development and testing
environments, cloud hosting, and building private or hybrid cloud infrastructures. Its ability to efficiently
manage both VMs and containers provides flexibility and enables you to choose the most appropriate
approach for your specific workloads.

In summary, Proxmox is a powerful and user-friendly virtualization management platform that offers the
benefits of both virtual machines and containers. With its extensive feature set, ease of use, and
open-source nature, Proxmox provides an efficient and cost-effective solution for organizations and
individuals seeking to leverage the benefits of virtualization in their computing environments.

---

> Before making any changes to software, systems, or devices,
> it's **important to thoroughly read and understand the configuration options**,
> and verify that the proposed changes align with your requirements.
> This can help avoid unintended consequences and ensure the software, system, or device operates as intended.
> {: .prompt-warning }

---

## \\\\ Change Subscription Mode & Updatable Repo

> _Add/Change to **no-subscription**-repo if you need,
> else use the enterprise-repo when you have a subscription_
>
> _Since **Proxmox VE 9** (Debian 13 "trixie") repositories are managed in the
> modern **deb822** `.sources` format, the legacy one-line `.list` format is no
> longer created. Run `apt modernize-sources` to migrate old repositories._
>
> _The easiest way is the GUI under `Datacenter > <Node> > Updates > Repositories`:
> **Disable** the `enterprise` repository (returns `401` without a subscription key)
> and **Add** the `No-Subscription` repository._

### // Terminal Setup :: Proxmox VE 8 (bookworm, `.list`)

```sh
# add the no-subscription repo (INFO: https://pve.proxmox.com/wiki/Package_Repositories#sysadmin_no_subscription_repo)
echo 'deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' \
  > /etc/apt/sources.list.d/pve-no-subscription.list

# disable the enterprise repo (INFO: https://pve.proxmox.com/wiki/Package_Repositories#sysadmin_enterprise_repo)
sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/pve-enterprise.list
```

### // Terminal Setup :: Proxmox VE 9 (trixie, deb822 `.sources`)

```sh
# disable the enterprise-repo
echo 'Enabled: false' >> /etc/apt/sources.list.d/pve-enterprise.sources

# add the no-subscription-repo
cat > /etc/apt/sources.list.d/pve-no-subscription.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```

> _For **Proxmox Backup Server** the component is **`pbs-no-subscription`**
> (e.g. `deb http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription`)
> and the enterprise file is `pbs-enterprise.list` / `pbs-enterprise.sources`._

verify the repositories and install the updates:

```sh
apt update
apt full-upgrade    # use full-upgrade: PVE packages need it for dependency changes
```

## \\\\ Automatic Security Updates

> _Proxmox itself should **not** be updated automatically, because `unattended-upgrades`
> cannot perform `apt full-upgrade`. Therefore we only let **Debian security updates**
> run unattended and install **`needrestart`** to restart services which require it
> after library updates (it is interactive on SSH, so it won't restart unexpectedly)._
>
> _Since **Proxmox VE 8.1** there is also a GUI under
> `Datacenter > <Node> > Updates > Automatic Updates` for this._

### // Setup

install the needed components:

```sh
apt install unattended-upgrades needrestart
dpkg-reconfigure -plow unattended-upgrades
```

> _The `dpkg-reconfigure` asks "Automatically download and install stable updates?",
> answer **Yes** - it only takes care of the two files shown below._

configure the automatic update schedule in `/etc/apt/apt.conf.d/20auto-upgrades`:

```sh
nano /etc/apt/apt.conf.d/20auto-upgrades
```

```properties
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
```

check and adjust the important options in `/etc/apt/apt.conf.d/50unattended-upgrades`:

> > - `Unattended-Upgrade::Origins-Pattern`:
> >   allow only `${distro_id}:${distro_codename}-security`
> >   and **both** security-origin patterns:
> >   `origin=Debian,codename=${distro_codename},label=Debian-Security` and
> >   and `origin=Debian,codename=${distro_codename}-security,label=Debian-Security`
> >   (the security archive uses `n=trixie-security`), so **only Debian security
> >   updates** get applied. Use `#clear Unattended-Upgrade::Origins-Pattern;`
> >   in a later config file to replace the defaults instead of appending.
> > - `Unattended-Upgrade::Package-Blacklist`:
> >   block the Proxmox packages (`proxmox-ve`, `proxmox-backup-server`, `pve-*`,
> >   `pbs-*`, `libproxmox-*`) - they must be upgraded manually with `apt full-upgrade`.
> > - `Unattended-Upgrade::Remove-Unused-Kernel-Packages`: `true`
> >   (keeps the ESP small, see the **Fix ESP** helper further down).
> > - `Unattended-Upgrade::Automatic-Reboot`: `false`
> >   (reboot never automatically, `needrestart` will ask instead).

test the setup in dry-run mode and start it, logs are under `/var/log/unattended-upgrades/unattended-upgrades.log`:

```sh
unattended-upgrade --dry-run
unattended-upgrade
```

## \\\\ ZFS configs

> _ZFS sizes the ARC automatically (up to about half of the installed RAM). Only
> limit it on small hosts, or when the host must keep RAM free for VMs. Values
> are in **bytes**: `GiB * 1024^3` (4 GiB = `4294967296`). Leave everything else
> at the default._

### // ARC

> **`zfs_arc_min`** - lower bound of the ARC. Once the ARC has grown it will not
> shrink below this value. Keep it large enough that VM memory, ZFS metadata and
> hot blocks stay cached under memory pressure (1-4 GiB is a common floor), but
> not so large that the host has no RAM left for its guests.
>
> **`zfs_arc_max`** - upper bound of the ARC. Without it, ZFS may use up to half
> of the RAM. Set it when VMs/containers need a guaranteed amount of memory, or
> when the machine is a hypervisor rather than a file server.
>
> **When to use:** only when `arc_summary` or `arcstat` shows the ARC is crowding
> out guest memory, or on hosts with less RAM than the working set. Do **not** set
> a very small maximum - an ARC that is too small causes constant disk reads
> instead of caching them.

```sh
cat > /etc/modprobe.d/zfs.conf <<'EOF'
# ARC limits: 4 GiB minimum / 8 GiB maximum (example for a 64 GiB host)
options zfs zfs_arc_min=4294967296
options zfs zfs_arc_max=8589934592
EOF

update-initramfs -u
proxmox-boot-tool refresh
```

> _Leave at least as much RAM for the host and its VMs as the ARC maximum
> (`zfs_arc_max`). `proxmox-boot-tool refresh` is only needed on systems where
> `proxmox-boot-tool status` lists ESPs - on plain GRUB systems `update-grub`
> is enough._

### // KSM

> _KSM (Kernel Samepage Merging) scans guest memory and merges identical pages.
> It saves RAM when many VMs run the same OS image, but costs CPU time and
> increases the **side-channel attack surface** - so only enable it when you
> actually need the memory density._

> **`KSM_THRES_COEF`** in `/etc/ksmtuned.conf` is the free-memory threshold as a
> percentage of total RAM. `ksmtuned` starts merging when free RAM drops below
> `total * VALUE / 100`, and backs off again when memory is free. Lower values
> start merging **later** (less aggressive), higher values start **earlier** and
> merge more pages (more CPU, more savings). The default is `20`; `35` is a good
> value for a dense, memory-bound host.

```sh
apt install -y ksmtuned
sed -i 's/^KSM_THRES_COEF=.*/KSM_THRES_COEF=35/' /etc/ksmtuned.conf
systemctl restart ksmtuned
```

> _Disable it with `systemctl disable --now ksmtuned` and
> `echo 0 > /sys/kernel/mm/ksm/run` when RAM is not the bottleneck. Enabling KSM
> is a deliberate trade-off, not a hardening default._

## \\\\ SWAP remove

> _Proxmox keeps VM/container memory in RAM. Swapping it to disk adds latency and
> makes guest performance unpredictable, and a host that starts swapping under
> memory pressure can become unresponsive. On a dedicated hypervisor with enough
> RAM, disable swap. On a small host where an OOM kill would hurt more than slow
> swap, keep a small swap file/partition and skip this section._

open `/etc/fstab` and comment the line where **swap** is defined, for example:

```properties
...
# /dev/mapper/cryptoswap none    swap    sw      0       0
...
```

also disable the currently used swap at runtime, and verify it is gone:

```sh
swapoff -a
swapon --show      # should print nothing
```

> _Commenting `/etc/fstab` makes the change persistent across reboots;
> `swapoff -a` only affects the running system._

## \\\\ SMTP Configuration

> _Proxmox VE 8.1+ can send notifications through the GUI. Use the terminal
> configuration only on older releases or when you need a custom relay._

### // GUI Setup

1. **Datacenter > Options** → set `Email from address`.
2. **Datacenter > Permissions > Users** → set the `E-Mail` for every user that
   should receive notifications.
3. **Datacenter > Notifications** → add a notification target and test it.

### // Terminal Setup (custom relay)

install **dependencies**:

```sh
apt install libsasl2-modules mailutils postfix-pcre
```

**open** the file `/etc/postfix/main.cf` and **configure** the **Postfix main configuration**, for example like follow:

> replace:
>
> > - `<SERVER_HOSTNAME_OR_IP>`
> > - `<YOUR_SMTP_HOST>`

```properties
# See /usr/share/postfix/main.cf.dist for a commented, more complete version

# Set the SMTP server hostname or IP address
myhostname = <SERVER_HOSTNAME_OR_IP>

smtpd_banner = $myhostname ESMTP $mail_name (Debian/GNU)
biff = no

# Do not append .domain to local addresses
append_dot_mydomain = no

# Uncomment the next line to generate "delayed mail" warnings
delay_warning_time = 4h

alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
mynetworks = 127.0.0.0/8
inet_interfaces = loopback-only
recipient_delimiter = +

compatibility_level = 2
inet_protocols = ipv4

# Specify the relay host and its port
relayhost = [<YOUR_SMTP_HOST>]:465

# SMTP authentication settings
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_sasl_tls_security_options = noanonymous

# Use TLS for SMTP connections
smtp_use_tls = yes

# Enable the SMTPS wrapper mode
smtp_tls_wrappermode = yes

# Set the required TLS security level for SMTPS
smtp_tls_security_level = encrypt

# TLS protocol versions (TLSv1.0 and TLSv1.1 are deprecated and removed in modern OpenSSL)
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1

# TLS ciphers
smtp_tls_ciphers = high

# CA path (use the system trust store instead of a hard-coded single CA)
smtp_tls_CApath = /etc/ssl/certs

# Enable SMTP TLS session caching
smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_tls_session_cache
smtp_tls_session_cache_timeout = 3600s
```

**create** a new file for storing the **SASL password**:

```sh
nano /etc/postfix/sasl_passwd
```

**add** the following line to the file with your **SMTP server details**:

> replace:
>
> > - `<SMTP_HOST>`
> > - `<SMTP_USERNAME>`
> > - `<SMTP_PASSWORD>`

```properties
[<SMTP_HOST>]:465    <SMTP_USERNAME>:<SMTP_PASSWORD>
```

**hash** the **sasl_passwd** file by running the following command:

```sh
chmod 600 /etc/postfix/sasl_passwd
postmap hash:/etc/postfix/sasl_passwd
```

**reload** Postfix to apply `main.cf` changes (a full restart is not needed):

```sh
systemctl daemon-reload
postfix reload
```

**verify** by send a test mail:

> replace:
>
> > - `<SENDER_ADDRESS>`
> > - `<RECIPIENT_ADDRESS>`

```sh
echo "Test mail from postfix" | mail -r '<SENDER_ADDRESS>' -s "Test Postfix" '<RECIPIENT_ADDRESS>'
```

## \\\\ SSH

Upload your public key **before** disabling password authentication, then verify a
second session works while the first one stays open:

```sh
# on the client: generate a key (ed25519, modern and fast)
ssh-keygen -t ed25519 -o -a 100 \
  -f ~/.ssh/id_ed25519_infra_pve_$(date +%Y_%m_%d) \
  -C "infra_pve_$(date +%Y_%m_%d)"

# copy it to the Proxmox host
ssh-copy-id -i ~/.ssh/id_ed25519_infra_pve_*.pub root@<PVE_HOST>
```

Client configuration (`~/.ssh/config`, applied to every host):

```sshconfig
################################################################################
# Host-specific configuration
################################################################################
# Per-host entry (optional) ----------------------------------------------------
# Host pve
#     HostName pve.example.com
#     User root
#     Port 22
#     IdentityFile ~/.ssh/id_ed25519_infra_pve_<date>
#     Preferredauthentications publickey

################################################################################
# Default configuration
################################################################################
Host *
    HashKnownHosts yes
    User groot
    Port 22
    AddressFamily any
    HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256
    KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
    IdentitiesOnly yes
    ForwardAgent no
    ForwardX11 no
    Compression no
    ServerAliveInterval 60
    ServerAliveCountMax 3
    SendEnv LANG LC_*
```

Harden the server in `/etc/ssh/sshd_config` and write it as one copy-paste block:

> _This guide does not create a non-root user, so `root` stays available with
> **key-only** login (`prohibit-password`, enforced by `AuthenticationMethods publickey`).
> On a cluster, prefer a dedicated non-root user with 2FA instead._
>
> _`Include` is placed **last** on purpose: cloud-init or vendor drop-ins in
> `sshd_config.d/` must not be able to re-enable password login._

```sshconfig
# OpenSSH server hardening configuration.
# Global configuration must remain before Match blocks.
PermitRootLogin prohibit-password

Port 22
AddressFamily any
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com,curve25519-sha256@libssh.org,diffie-hellman-group18-sha512
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256
PubkeyAcceptedAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-ed25519
RekeyLimit default none
RequiredRSASize 3072
LoginGraceTime 30s
StrictModes yes
MaxAuthTries 3
MaxSessions 10
MaxStartups 10:30:60
PubkeyAuthentication yes
AuthenticationMethods publickey
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PermitUserEnvironment no
PermitUserRC no
UsePAM yes
HostbasedAuthentication no
IgnoreRhosts yes
GSSAPIAuthentication no
GSSAPICleanupCredentials yes
DisableForwarding yes
AllowAgentForwarding no
AllowTcpForwarding no
AllowStreamLocalForwarding no
GatewayPorts no
PermitTunnel no
X11Forwarding no
PermitTTY yes
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
Compression no
SyslogFacility AUTHPRIV
LogLevel VERBOSE
AcceptEnv LANG LC_*
Banner /etc/issue.net
Subsystem sftp internal-sftp -f AUTHPRIV -l INFO
Include /etc/ssh/sshd_config.d/*.conf
```

Verify the configuration and reload (keep the current session open until a new
login succeeds):

```sh
sshd -t
systemctl reload ssh
```

```sh
# in a second terminal
ssh -o PreferredAuthentications=publickey root@<PVE_HOST>
```

## \\\\ Kernel and Network Tunings

open the file `/etc/sysctl.conf` and replace with following content:

> _make sure the defined values fits your needs or change them for your needs_

```properties
#
# /etc/sysctl.conf - Configuration file for setting system variables
# See /etc/sysctl.d/ for additional system variables.
# See sysctl.conf (5) for information.
#
# To apply changes: `sudo sysctl -p --system`
#

###################################################################
# ==> Kernel Parameters

# Control kernel logging to console (severity levels).
# See: https://en.wikipedia.org/wiki/Syslog#Severity_levels
# - CUR: Current message level (default: 3, "error").
# - DEF: Default level for messages without a specified level.
# - MIN: Minimum CUR level allowed.
# - BTDEF: Boot-time default for CUR.
# |     |               | CUR | DEF | MIN | BTDEF |
# | :-- | :------------ | :-- | :-- | :-- | :---- |
# | 0   | emergency     | x   | x   | x   | x     |
# | 1   | alert         | x   | x   | x   | x     |
# | 2   | critical      | x   | x   |     | x     |
# | 3   | error         | x   | x   |     | x     |
# | 4   | warning       |     | x   |     |       |
# | 5   | notice        |     |     |     |       |
# | 6   | informational |     |     |     |       |
# | 7   | debug         |     |     |     |       |
kernel.printk=3 4 1 7

# Enable Address Space Layout Randomization (ASLR) for process memory.
# Enhances security by making it more difficult for attackers to predict memory addresses.
kernel.randomize_va_space=2
# Restrict access to dmesg for non-root users, preventing potential leakage of sensitive system information.
kernel.dmesg_restrict=1
# Controls access to kernel pointer addresses in /proc files.
# Restricting this prevents unauthorized users from reading kernel addresses.
kernel.kptr_restrict=1

# Disable core dumps for setuid programs to prevent sensitive data leaks.
fs.suid_dumpable=0

# Max inotify instances and watches per user (for applications that require more file monitoring).
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288

# Restrict ptrace() debugging to parent processes only.
# Prevents exploitation of ptrace by malicious processes.
kernel.yama.ptrace_scope=1

###################################################################
# ==> Magic SysRq Key Configuration

# Enable SysRq key functions selectively.
# See https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html
# - 0: Disable completely.
# - 1: Enable all.
# - 176: Allow only reboot, remount, kill, sync, etc.
kernel.sysrq=176
#kernel.sysrq=438

###################################################################
# ==> Virtual Memory

# Prevent null-pointer dereference attacks by restricting minimum address mappable via mmap().
vm.mmap_min_addr=65536

# Memory overcommit handling:
# - 0: Default overcommit handling.
# - 1: Always overcommit.
# - 2: No overcommit beyond set ratio.
vm.overcommit_memory=0
# In case overcommit ratio needs to be manually set (in percent).
#vm.overcommit_ratio=100

# Set swappiness value. Lower values reduce swap usage and prefer keeping data in RAM.
vm.swappiness=1

# Transparent Huge Pages (THP) can be enabled for memory allocation efficiency if necessary.
# Static hugepages reserve RAM at boot (2048 x 2MB = 4GB) and are useless unless
# VMs are explicitly configured with hugepages. Prefer the boot parameter
# `hugepages=N` if you need them; sysctl allocation is fragmentation-prone.
#vm.nr_hugepages=2048
#vm.nr_hugepages_mempolicy=1

# Controls when dirty data (modified pages) is written to disk.
# See https://lonesysadmin.net/2013/12/22/better-linux-disk-caching-performance-vm-dirty_ratio/
# The `dirty_background_ratio` defines the threshold when background processes start flushing dirty pages.
# The `dirty_ratio` is the maximum percentage of RAM that can be "dirty" before the system forces a write.
# Example:
# For a system with 64GB of RAM:
# - dirty_background_ratio=5: Around 3.2GB will start flushing.
# - dirty_ratio=10: Around 6.4GB can be dirty before a forced write.
# Adjust these values depending on system load and disk performance requirements.
#vm.dirty_background_ratio=5
#vm.dirty_ratio=10

###################################################################
# ==> Networking (Functional Parameters)

# Disable IPv6 if not required. Leave enabled if the guests/network use it:
# disabling it makes the bridge ip6tables setting below irrelevant.
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

# Prevent sending ICMP redirects.
# Improves security for non-router devices to avoid man-in-the-middle attacks.
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0

# Disable IP forwarding if the host is not a router/NAT gateway. Set these to 1
# if guests use NAT on a vmbr or the host routes between networks.
net.ipv4.ip_forward=0
net.ipv4.conf.all.forwarding=0
net.ipv6.conf.all.forwarding=0

# Disable source routing to protect against spoofing attacks, which can be used to bypass security mechanisms.
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0

# Prevent acceptance of ICMP redirects, mitigating spoofing attacks.
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0

# Do not accept ICMP redirects only for gateways listed in our default.
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0

# Log Martian Packets (better to have enabled for security, but can cause log spam).
net.ipv4.conf.all.log_martians=0
net.ipv4.conf.default.log_martians=0

# Ignore broadcast ICMP pings and erroneous error responses to enhance security.
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.icmp_echo_ignore_all=0

# Enable source address validation to prevent spoofing.
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.lo.rp_filter=0

# Enable TCP SYN cookies to mitigate SYN flood attacks.
net.ipv4.tcp_syncookies=1

# Enable TCP Selective Acknowledgements (SACK), improving throughput and robustness.
net.ipv4.tcp_sack=1

# Keep Path MTU Discovery enabled - disabling it creates MTU black holes
# (SSH works, large HTTPS/VPN transfers hang). Allow ICMP type 3/code 4 instead.
net.ipv4.ip_no_pmtu_disc=0

# Keep TCP timestamps enabled: they are needed for RTT estimation, PAWS and
# SYN-cookie MSS encoding. The security gain from disabling them is negligible.
net.ipv4.tcp_timestamps=1

# Protect Against TCP Time-Wait to mitigate DoS attack attempts.
net.ipv4.tcp_rfc1337=1

# Ignore IPv6 router advertisements on the host (privacy addresses are set below).
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0

# Enable TCP Fast Open for faster connections, enhancing performance for both clients and servers.
# - 0: Disable TCP Fast Open (default if not explicitly set).
# - 1: Enable TCP Fast Open for outgoing connections (clients).
# - 2: Enable TCP Fast Open for incoming connections (servers).
# - 3: Enable TCP Fast Open for both outgoing and incoming connections.
net.ipv4.tcp_fastopen=3

# Congestion control: the kernel default (cubic) is fine for most hosts.
# BBR pairs best with the `fq` qdisc below; it is not required for virtualization.
#net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_congestion_control=cubic
#net.ipv4.tcp_congestion_control=htcp

# Default queuing discipline (reduces latency under load).
net.core.default_qdisc=fq_codel
#net.core.default_qdisc=fq

# Enable TCP window scaling for larger buffers, useful in high-bandwidth or high-latency networks.
# Increase Linux autotuning TCP buffer limit to 128MB (64MB).
# NOTE: boolean - only 0 or 1 is valid!
net.ipv4.tcp_window_scaling=1

# Enable MTU Probing (only if you use jumbo frames on a non-segmented L2).
#net.ipv4.tcp_mtu_probing=1

# Enable auto-tuning of the receive buffer size for better performance in high-throughput networks.
net.ipv4.tcp_moderate_rcvbuf=1

# Cached connection metrics usually improve overall performance - keep the default.
#net.ipv4.tcp_no_metrics_save=1

# Keep netfilter on bridge devices ENABLED, otherwise the **Proxmox firewall**
# (and host iptables rules, e.g. for NAT) silently stops working for the guests!
# pve-firewall manages these itself on rule updates - do not disable them.
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
# arptables is not used by the Proxmox firewall
#net.bridge.bridge-nf-call-arptables=0

# IPv6 Privacy Extensions (RFC 4941)
# ---
# IPv6 typically uses a device's MAC address when choosing an IPv6 address
# to use in autoconfiguration. Privacy extensions allow using a randomly
# generated IPv6 address, which increases privacy.
#
# Acceptable values:
#    0 - don’t use privacy extensions.
#    1 - generate privacy addresses
#    2 - prefer privacy addresses and use them over the normal addresses.
net.ipv6.conf.all.use_tempaddr=2
net.ipv6.conf.default.use_tempaddr=2

# Set preferred lifetime to 1 hour (time before a new address is preferred)
# Backed up optional values: 86400 (24h)
net.ipv6.conf.all.temp_prefered_lft=3600
net.ipv6.conf.default.temp_prefered_lft=3600
# Set valid lifetime to 2 hours (time before the old address is invalidated)
# Backed up optional values: 604800 (168h)
net.ipv6.conf.all.temp_valid_lft=7200
net.ipv6.conf.default.temp_valid_lft=7200

###################################################################
# ==> Networking (Performance Parameters)

# Increase maximum receive/send socket buffer sizes for handling large data streams.
# Backed up optional values: 212992 | 67108864 | 134217728
net.core.rmem_max=134217728
net.core.wmem_max=134217728

# Increase input queue size for better handling of high traffic volumes.
# Backed up optional values: 1000 | 3000
#net.core.netdev_max_backlog=1000

# Increase maximum number of pending connections to support high traffic loads.
# Backed up optional values: 4096 | 65535
#net.core.somaxconn=4096

# Number of flow entries for Receive Packet Steering (RPS).
# Backed up optional values: 0 | 32768
#net.core.rps_sock_flow_entries=32768

# Optimize TCP buffers for high throughput connections (low, pressure, high).
# Backed up optional values: 4096 131072 6291456 | 4096 87380 67108864 | 4096 87380 134217728
#net.ipv4.tcp_rmem=4096 87380 134217728
# Backed up optional values: 4096 16384 4194304 | 4096 87380 67108864 | 4096 87380 134217728
#net.ipv4.tcp_wmem=4096 87380 134217728

# Maximum number of queued SYN requests, higher values prevent SYN flood attacks.
# Backed up optional values: 512 | 4096
#net.ipv4.tcp_max_syn_backlog=4096

# Define memory pressure thresholds for TCP memory management (low, pressure, high).
# Backed up optional values: 93222 124299 186444 | 4194304 4194304 4194304 | 8388608 12582912 16777216
#net.ipv4.tcp_mem=8388608 12582912 16777216

###################################################################
# ==> Filesystem Parameters

# Increase maximum number of open file descriptors system-wide, supporting applications with many files open.
# Backed up optional values: 2097152 | 262144 | 4194304 | 9223372036854775807
fs.file-max=2097152

# Raise async I/O limit for hosts with many VMs/disks (Proxmox recommendation).
fs.aio-max-nr=1048576

# Increase maximum virtual memory map count for applications using large amounts of virtual memory.
vm.max_map_count=1048576
```

Apply the settings:

```sh
sysctl --system
```

## \\\\ Grub Optimizing & PCI Passthrough

Unlocking the Power of **GPU** and **USB-PCI** Card **Passthrough** in Proxmox

### // Setup BIOS Boot Options

Set these in the BIOS/UEFI before configuring passthrough:

| Setting                               | Value      | Why                                         |
| :------------------------------------ | :--------- | :------------------------------------------ |
| **SVM** (Secure Virtual Machine)      | `Enabled`  | AMD-V virtualization                        |
| **SMT** (Simultaneous Multithreading) | `Auto`     | Exposes all CPU threads to VMs              |
| **Above 4G Decoding**                 | `Enabled`  | Lets PCIe devices map memory above 4 GB     |
| **IOMMU**                             | `Enabled`  | Required for PCI passthrough                |
| **ACS** (Access Control Services)     | `Enabled`  | Better IOMMU group isolation                |
| **ARI support**                       | `Auto`     | More addressable PCIe devices               |
| **ARI enumeration**                   | `Auto`     | Detects ARI-capable devices                 |
| **RE-SIZE BAR**                       | `Disabled` | Avoids passthrough conflicts on some boards |

- **SVM (Secure Virtual Machine):** AMD's CPU virtualization extension (AMD-V).
  Required for KVM - if it is off, VMs run unaccelerated or fail to start.
- **SMT (Simultaneous Multithreading):** exposes two threads per core. `Auto`
  usually means enabled; disabling it lowers performance and slightly reduces
  some side-channel exposure. Fine for a homelab to leave it on.
- **Above 4G Decoding:** lets the firmware map PCIe BARs above the 4 GB boundary.
  Required for GPUs with more than 4 GB VRAM and for large passthrough devices.
- **IOMMU:** the memory management unit for devices. It is mandatory for PCI
  passthrough and for keeping devices isolated from each other.
- **ACS (Access Control Services):** controls whether devices behind a PCIe
  switch can be isolated into their own IOMMU groups. Enable it; if the board
  does not support it, `pcie_acs_override` may be needed (unsafe, see below).
- **ARI support / enumeration:** lets the firmware address more PCIe functions.
  `Auto` is fine; enable it if a device or function does not show up at all.
- **RE-SIZE BAR:** gives the GPU access to its full VRAM window. It can help
  native GPU workloads but breaks passthrough on some boards and guests, so keep
  it disabled until passthrough works, then test enabling it.

### // Setup Boot Parameters

#### Determine the Bootloader

Do this before editing the kernel command line:

```sh
# UEFI or legacy BIOS?
[ -d /sys/firmware/efi ] && echo "UEFI" || echo "Legacy BIOS"

# Official method: look at the active EFI boot entry
efibootmgr -v
#   \EFI\proxmox\grubx64.efi          -> GRUB (UEFI)
#   \EFI\proxmox\shimx64.efi          -> GRUB (UEFI, Secure Boot)
#   \EFI\systemd\systemd-bootx64.efi  -> systemd-boot
#   "EFI variables are not supported" -> GRUB (legacy BIOS)

# Which file holds the kernel command line?
test -f /etc/kernel/cmdline && cat /etc/kernel/cmdline   # systemd-boot
grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub        # GRUB

# Shows whether proxmox-boot-tool manages the ESPs and with which loader
proxmox-boot-tool status
```

> _Proxmox VE defaults: **ZFS root on UEFI without Secure Boot → systemd-boot**;
> everything else (ext4/xfs, legacy BIOS, Secure Boot) → **GRUB**._
>
> _Use the matching subsection below._

#### GRUB Configuration

Edit the kernel command line:

```sh
nano /etc/default/grub
```

Set the line starting with `GRUB_CMDLINE_LINUX_DEFAULT`:

```properties
GRUB_CMDLINE_LINUX_DEFAULT="quiet iommu=pt amd_pstate=passive cpufreq.default_governor=schedutil processor.max_cstate=4"

# (optional GPU) extend for better GPU support with:
GRUB_CMDLINE_LINUX_DEFAULT="quiet iommu=pt amd_pstate=passive cpufreq.default_governor=schedutil processor.max_cstate=4 amdgpu.sg_display=0 pcie_acs_override=downstream,multifunction initcall_blacklist=sysfb_init"
```

> _The GPU extras are **conditional**: `initcall_blacklist=sysfb_init` is only
> needed when passing through the boot GPU, `amdgpu.sg_display=0` only for
> specific AMD APU/ReBAR issues, and `pcie_acs_override` weakens IOMMU isolation
> (last resort only). Keep the first line unless you need them._

Apply and verify (on proxmox-boot-tool systems `update-grub` also triggers `proxmox-boot-tool refresh`):

```sh
update-grub
cat /proc/cmdline      # verify after the next reboot
```

#### systemd-boot Configuration

systemd-boot reads the kernel command line from `/etc/kernel/cmdline`. **Keep the
existing `root=` and `boot=` parameters** and append the new ones:

```sh
cat /etc/kernel/cmdline
nano /etc/kernel/cmdline
```

```properties
root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet iommu=pt amd_pstate=passive cpufreq.default_governor=schedutil processor.max_cstate=4

# (optional GPU) extend for better GPU support with:
root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet iommu=pt amd_pstate=passive cpufreq.default_governor=schedutil processor.max_cstate=4 amdgpu.sg_display=0 pcie_acs_override=downstream,multifunction initcall_blacklist=sysfb_init
```

> _Same conditional GPU extras as in the GRUB section above - keep the first
> line unless you actually need them._

Apply and verify:

```sh
proxmox-boot-tool refresh
cat /proc/cmdline      # verify after the next reboot
```

#### Parameter Explanation

| Topic                             | Key                        | Good Value                          | Optional Value                | Purpose                                                                   |
| :-------------------------------- | :------------------------- | :---------------------------------- | :---------------------------- | :------------------------------------------------------------------------ |
| **AMD-Specific Tweaks**           |                            |                                     |                               |                                                                           |
|                                   | `amd_iommu`                | _not needed_                        | `force_enable`                | AMD-Vi is on by default; `on` is not a valid value. Use `iommu=pt`.       |
|                                   | `amd_pstate`               | `passive`                           | `active` (if kernel supports) | Uses AMD's P-State driver for dynamic CPU scaling (Zen 3/4+).             |
|                                   | `amdgpu.sg_display`        | `0`                                 | `1` (default)                 | Disables scatter-gather display for APUs to fix flickering/artifacts.     |
| **CPU Power Management**          |                            |                                     |                               |                                                                           |
|                                   | `cpufreq.default_governor` | `schedutil` or `performance` (home) | `ondemand` (business)         | Controls CPU frequency scaling (performance vs. power efficiency).        |
|                                   | `cpuidle.governor`         | `teo`                               | `menu` (legacy)               | Optimizes idle states for AMD CPUs (low latency).                         |
|                                   | `processor.max_cstate`     | `5` or `4` or `3`                   | `1` or `2` (business)         | Limits deep sleep states (C-states) to reduce VM stuttering.              |
| **Memory Optimization**           |                            |                                     |                               |                                                                           |
|                                   | `default_hugepagesz`       | `1G` (if supported)                 | `2M`                          | Sets default hugepage size (improves VM memory efficiency).               |
|                                   | `hugepages`                | `16` (1G) or `8192` (2M)            | Adjust based on RAM           | Preallocates static hugepages for VMs/containers.                         |
|                                   | `hugepagesz`               | `1G` or `2M`                        | -                             | Explicitly defines hugepage size (required if not using default).         |
|                                   | `transparent_hugepage`     | `madvise`                           | `never` (manual control)      | Automatic hugepage allocation; `madvise` only on request.                 |
| **IOMMU/PCI Passthrough**         |                            |                                     |                               |                                                                           |
|                                   | `iommu`                    | `pt`                                | `on`                          | Configures IOMMU in passthrough mode (isolates devices for VMs).          |
|                                   | `pcie_acs_override`        | `downstream,multifunction`          | -                             | Bypasses PCIe ACS checks (unsafe but fixes passthrough on some hardware). |
| **Kernel/Graphics Fixes**         |                            |                                     |                               |                                                                           |
|                                   | `initcall_blacklist`       | `sysfb_init`                        | -                             | Fixes AMD GPU/framebuffer conflicts during boot.                          |
|                                   | `nofb`                     | -                                   | _Add if boot stalls_          | Disables framebuffer to resolve GPU passthrough conflicts.                |
|                                   | `nomodeset`                | -                                   | _Add temporarily_             | Skips GPU driver loading at boot (debugging passthrough).                 |
| **Legacy/Intel (Ignore for AMD)** |                            |                                     |                               |                                                                           |
|                                   | `intel_pstate`             | `disable`                           | -                             | Disables Intel's P-State driver (irrelevant for AMD CPUs).                |

> **How to read the table:** _Good Value_ is what this guide uses, _Optional Value_
> lists realistic alternatives. Every entry is optional tuning - keep the
> kernel default unless you hit the described problem.

**AMD-specific**

- `amd_iommu` - enables AMD-Vi (the IOMMU). Modern kernels/firmware enable it by
  default, so no boot option is needed. There is no `on` value; `force_enable`
  forces AMD-Vi even when the BIOS reports it as disabled, and `off` disables it
  (which breaks passthrough). Use `force_enable` only when the BIOS setting is
  on but `dmesg | grep -i iommu` still reports the IOMMU as disabled.
- `amd_pstate` - AMD's CPU frequency-scaling driver (Zen 3/4+ with CPPC).
  `passive` uses the kernel governor and is the safe default; `active` lets the
  CPU scale itself and needs kernel >= 6.3 plus CPPC support; `disable` falls
  back to `acpi-cpufreq`. Check the active mode with
  `cat /sys/devices/system/cpu/amd_pstate/status`.
- `amdgpu.sg_display=0` - disables scatter-gather display in the `amdgpu`
  driver. It fixes flickering/artifacts on some Ryzen APUs (5xxxG/7xxxG) and is
  irrelevant on a host without an AMD iGPU. Revert to `1` if the console breaks.

**CPU power management**

- `cpufreq.default_governor` - selects the CPU frequency governor.
  `performance` keeps clocks high (lowest latency, highest power - good for
  latency-sensitive VMs), `schedutil` balances performance and power using
  scheduler hints, `ondemand` is the older conservative choice. Check the
  running governor with
  `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`.
- `cpuidle.governor` - decides which idle (C) state the CPU enters. `teo` is
  tuned for intermittent workloads and is a good default on AMD, `menu` is the
  generic default, `ladder` is simpler/older, `haltpoll` is meant for virtualized
  guests. Check with
  `cat /sys/devices/system/cpu/cpuidle/current_governor`.
- `processor.max_cstate` - limits the deepest C-state the CPU may enter. `1`/`2`
  keep the CPU responsive at a higher power draw; `3`-`5` allow deeper sleep for
  more savings but can add VM latency and wake-up jitter. Use a lower value if
  guests stutter or USB/audio passthrough glitches; `4` is a reasonable balance.

**Hugepages**

- `default_hugepagesz` - default hugepage size (`1G` when
  `grep pdpe1gb /proc/cpuinfo` reports support, otherwise `2M`).
- `hugepagesz` - explicitly declares the size used by the following
  `hugepages` reservation; needed when mixing `1G` and `2M` pages.
- `hugepages` - number of pages reserved at boot: `8192` x 2 MB = 16 GiB or
  `16` x 1 GB = 16 GiB. Reserved pages are unavailable to the host, so size
  them for the VMs that will use them, and verify with
  `grep HugePages /proc/meminfo`. Prefer this boot parameter over
  `vm.nr_hugepages` in sysctl - runtime allocation is fragmentation-prone.
- `transparent_hugepage=never` - disables automatic THP. `madvise` (default on
  many distros) only uses THP when an application asks for it; `always` gives
  the memory savings but can add latency spikes. On a hypervisor host, `madvise`
  is the usual compromise.

**IOMMU / PCI passthrough**

- `iommu=pt` - "passthrough" mode: only devices actually assigned to a VM are
  translated, which keeps host I/O fast. `on` enables full IOMMU translation for
  all devices (slower host I/O, stricter isolation). Use `pt` for passthrough,
  `on` only when you need full isolation of host devices.
- `pcie_acs_override` - pretends PCIe ACS is supported so devices behind a
  switch can be split into separate IOMMU groups. `downstream` applies to devices
  behind a PCIe switch, `multifunction` splits functions of a multi-function
  device (e.g. a dual-NIC card). ⚠️ It **weakens isolation** - a malicious VM can
  then reach other devices in the same group. Use it only in a trusted
  environment and as a last resort.

**Kernel / graphics fixes**

- `initcall_blacklist=sysfb_init` - skips the firmware-framebuffer handover,
  which is needed when the **boot GPU** is passed through and the host otherwise
  keeps the framebuffer and prevents `vfio-pci` from binding. Not needed for a
  secondary GPU.
- `nofb` - disables the kernel framebuffer entirely. Add it only if the boot
  stalls or the GPU cannot be reset during passthrough; you lose the visible
  console output.
- `nomodeset` - stops the kernel from loading GPU mode-setting drivers at boot.
  Useful temporarily to get a console for debugging passthrough; not a permanent
  setting (no GPU acceleration/framebuffer).

**Intel-only**

- `intel_pstate=disable` - disables Intel's P-state driver and falls back to
  `acpi-cpufreq` (useful on older Intel systems for consistent governor
  behaviour). Irrelevant on AMD.

### // Setup VFIO Framework

> _VFIO is the kernel framework that hands a PCI device to a VM. The modules are
> loaded at boot, before the normal drivers can claim the device:_
>
> - **`vfio`** - the core framework and `/dev/vfio/*` character devices.
> - **`vfio_pci`** - the PCI bus driver that binds the device to VFIO.
> - **`vfio_iommu_type1`** - the IOMMU driver that gives the VM a translated,
>   isolated DMA window for the passed-through device.
>
> _On PVE 9 (and Debian 13) modules are loaded through `/etc/modules-load.d/`._

```sh
cat > /etc/modules-load.d/vfio.conf <<'EOF'
vfio
vfio_pci
vfio_iommu_type1
EOF
```

### // Setup pve-blacklist.conf

> _Blacklisting a driver prevents the host from claiming the GPU before
> `vfio-pci` can bind it. The normal drivers have to be kept away from the device,
> otherwise the host keeps using it (and may reset it at the wrong time)._
>
> _`amdgpu`/`radeon` are the AMD drivers, `nouveau` is the open NVIDIA driver. The
> NVIDIA entries are commented out because they are only needed when you pass an
> NVIDIA GPU through - uncomment all of them then. Module globs (`nvidia*`) are
> **not** supported in blacklist files._
>
> _Do not blacklist the driver for the GPU you use as the host console. On a
> headless passthrough host that is fine; otherwise keep the console on another
> GPU, serial console or IPMI/BMC._

```sh
cat > /etc/modprobe.d/pve-blacklist.conf <<'EOF'
blacklist nouveau
blacklist amdgpu
blacklist radeon
#blacklist nvidia
#blacklist nvidiafb
#blacklist nvidia_drm
#blacklist nvidia_modeset
#blacklist nvidia_uvm
EOF
```

### // Setup iommu_unsafe_interrupts.conf

> ⚠️ `allow_unsafe_interrupts=1` bypasses interrupt remapping safety checks. Only
> use it if your platform has **no interrupt remapping** (otherwise VFIO fails
> with `Interrupt remapping hardware not found`); it can make the system
> unstable and weakens isolation. Prefer not to set it.
>
> _Check whether the platform supports remapping with
> `dmesg | grep -i -e 'interrupt remapping' -e 'DMAR' -e 'AMD-Vi'`. If the IOMMU
> reports remapping support, do **not** create this file - fix the firmware/IOMMU
> setup instead. If it reports none, this option is the fallback._

```sh
echo 'options vfio_iommu_type1 allow_unsafe_interrupts=1' > /etc/modprobe.d/iommu_unsafe_interrupts.conf
```

### // Setup kvm.conf

> **`ignore_msrs=1`** - when a guest reads/writes a model-specific register
> (MSR) that KVM does not emulate, return `0` instead of injecting a fault. Some
> GPU drivers (especially NVIDIA) probe MSRs blindly, so this is what makes them
> work in a VM.
>
> **`report_ignored_msrs=0`** - stop logging every ignored MSR. With reporting
> enabled, a misbehaving guest can flood `dmesg` and waste CPU.
>
> **When to use:** keep both as shown when doing GPU passthrough. If you are
> debugging a guest, set `report_ignored_msrs=1` temporarily - the log tells you
> which MSRs the guest tried to access.

```sh
echo 'options kvm ignore_msrs=1 report_ignored_msrs=0' > /etc/modprobe.d/kvm.conf
```

### // Setup softdep.conf

> _`softdep` only orders module loading; it does not unbind a driver. Prefer
> per-device binding (`driverctl set-override <BDF> vfio-pci`) for USB
> controllers, because binding the wrong xHCI controller disables the host's
> keyboard and mouse._

```sh
cat > /etc/modprobe.d/softdep.conf <<'EOF'
softdep amdgpu pre: vfio-pci
softdep snd_hda_intel pre: vfio-pci
#optional: softdep xhci_pci pre: vfio-pci
EOF
```

### // Setup vfio modprobe :: GPU

To passthrough a GPU to a virtual machine, the device must not be used by the Proxmox host.  
This can be achieved by binding the GPU and its audio device to the `vfio-pci` driver during boot.  
Once configured, the GPU is hidden from the host system and becomes available for passthrough.

List all GPU devices and identify the one to be assigned to a VM.  
Record the PCI address (e.g. `2b:00.0`). For later use, only the part before the dot is required (`2b:00`):

```sh
lspci | grep -iE "VGA"
```

Display detailed information about the selected device, including its related audio function.  
**Replace `2b:00`** with the PCI address **obtained above**.  
In the output, the **PCI IDs** are shown inside **latest square brackets** `[vendor:device]`.  
Record both the **GPU and audio PCI IDs**, for example:

- GPU: `10de:1b81`
- Audio: `10de:10f0`

```sh
lspci -nn -s 2b:00
```

Create a configuration file for `modprobe` with the recorded **PCI IDs**.  
Replace `<GPU>` and `<AUDIO>` with the recorded **PCI IDs**:

```sh
echo 'options vfio-pci ids=<GPU>,<AUDIO> disable_vga=1' > /etc/modprobe.d/vfio-gpu.conf
```

> **`disable_vga=1`** stops the passed GPU from being used as the host's legacy
> VGA device. Without it the host keeps VGA arbitration on the GPU and `vfio-pci`
> may fail to bind, or the VM's GPU stays uninitialized. Leave it off only if the
> host has no other display output and you still need the console on that card.

### // Setup vfio modprobe :: SAS

For passthrough of SAS controllers, the device must likewise be bound to the `vfio-pci` driver.  
This prevents the host from initializing it and makes it available for a virtual machine.

List all SAS controllers and identify the one to be assigned to a VM.  
The required **PCI ID** is shown inside **latest square brackets** `[vendor:device]`.  
Example output may include `1000:0097` for an LSI controller:

```sh
lspci -nn | grep -iE "SAS"
```

Create a configuration file for `modprobe` with the recorded **PCI ID**.  
Replace `<PCI_ID>` with the recorded **PCI ID**:

```sh
echo 'options vfio-pci ids=<PCI_ID>' > /etc/modprobe.d/vfio-sas.conf
```

### // Update and Reboot

> The `modprobe.d` and `modules-load.d` files are read early in boot, so the
> changes must be written into the initramfs: `-u` updates the existing image,
> `-k all` rebuilds it for **every installed kernel**. Without this, boot may
> still use the old module ordering and let the host drivers claim the device.

```sh
update-initramfs -u -k all
reboot
```

> _If you run into `No space left on device` while updating kernels,
> see the **Fix ESP "No space left on device"** section under **Helpful Functions**._

---

## \\\\ Additional Configurations

### // Create a Cloud-Init Template

> _Example for setup ubuntu-24.04 (noble) cloud-init template_
>
> > - NOTE: change **img** `noble-server-cloudimg-amd64.img` as you needed (also the url for download)
> > - NOTE: change **vm-id** `9999` as you needed
> > - NOTE: check **storage-name** `local-zfs` for your needs (maybe your's is local-lvm)

download the ubuntu-24.04 (noble) image:

```sh
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img \
-O /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img
```

verify the sha256 hash:

```sh
cd /var/lib/vz/template/iso && \
curl -s https://cloud-images.ubuntu.com/noble/current/SHA256SUMS | \
grep "noble-server-cloudimg-amd64.img" | \
sha256sum -c - ; cd ~
```

create a new VM:

```sh
qm create 9999 --name "template-s-ubuntu-noble" --memory 2048 --net0 virtio,bridge=vmbr0 \
--cpu cputype=x86-64-v2-AES --sockets 1 --cores 2 --numa 0
```

add cloud img as drive or empty drive:

```sh
# import the downloaded disk to local-zfs storage
qm importdisk 9999 /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img local-zfs
# finally attach the new disk to the VM as scsi drive
qm set 9999 --scsihw virtio-scsi-single --scsi0 local-zfs:vm-9999-disk-0,ssd=1,discard=on,iothread=1
```

setup additional VM properties:

```sh
# add cloud-init cd-rom drive
qm set 9999 --balloon 0
qm set 9999 --scsi2 local-zfs:cloudinit
qm set 9999 --boot order='scsi0'
#qm set 9999 --serial0 socket --vga serial0
qm set 9999 --agent 1
qm set 9999 --hotplug disk,network,usb
qm set 9999 --bios ovmf
qm set 9999 --efidisk0 local-zfs:0,efitype=4m,pre-enrolled-keys=0
qm set 9999 --machine q35
qm set 9999 --tablet 0
qm set 9999 --ostype l26
```

cloud init custom config:

> _Prerequisite: `local` storage must include the `snippets` content type, e.g.
> `pvesm set local --content iso,vztmpl,backup,snippets` - keep your existing
> content list and just add `snippets`._

```sh
# add cloud init config to install guest agent on first start
mkdir -p /var/lib/vz/snippets
cat <<'EOF' >/var/lib/vz/snippets/ubuntu.yaml
#cloud-config
keyboard:
  layout: "de"
  variant: ""
packages:
  - qemu-guest-agent
EOF
qm set 9999 --cicustom "vendor=local:snippets/ubuntu.yaml"
```

convert VM as template:

```sh
qm template 9999
```

### // Create a Cloud-Init autoinstall Template

> _Example for setup ubuntu-24.04-live-server cloud-init template over autoinstall,
> which installs in this example for as client usage 'ubuntu-desktop-minimal'_
>
> > - NOTE: change **iso** `ubuntu-24.04.1-live-server-amd64.iso` as you needed (also the url for download)
> > - NOTE: change **vm-id** `9998` as you needed
> > - NOTE: check **storage-name** `local-zfs` for your needs (maybe your's is local-lvm)
> > - NOTE: check **SHA512_PASSPHRASE** and **LUKS_PASSPHRASE** to be updated with your credentials

download the ubuntu-server-24.04 live image:

```sh
wget https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso \
-O /var/lib/vz/template/iso/ubuntu-24.04.1-live-server-amd64.iso
```

verify the sha256 hash:

```sh
cd /var/lib/vz/template/iso && \
curl -s https://releases.ubuntu.com/24.04/SHA256SUMS | \
grep "ubuntu-24.04.1-live-server-amd64.iso" | \
sha256sum -c - ; cd ~
```

create a new VM:

```sh
qm create 9998 --name "template-c-ubuntu-noble" --memory 2048 --net0 virtio,bridge=vmbr0 \
--cpu cputype=x86-64-v2-AES --sockets 1 --cores 2 --numa 0
```

add empty drive and iso:

```sh
qm set 9998 --scsihw virtio-scsi-single --scsi0 local-zfs:32,ssd=1,discard=on,iothread=1
qm set 9998 --scsi1 local-zfs:iso/ubuntu-24.04.1-live-server-amd64.iso,media=cdrom
```

setup additional VM properties:

```sh
# add cloud-init cd-rom drive
qm set 9998 --balloon 0
qm set 9998 --vga virtio
qm set 9998 --agent 1
qm set 9998 --hotplug disk,network,usb
qm set 9998 --bios ovmf
qm set 9998 --efidisk0 local-zfs:0,efitype=4m,pre-enrolled-keys=0
qm set 9998 --machine q35
qm set 9998 --tablet 0
qm set 9998 --ostype l26
```

cloud init custom autoinstall config:

```sh
# add cloud init config to install guest agent and ubuntu client desktop on first start
mkdir -p /var/lib/vz/snippets
touch /var/lib/vz/snippets/meta-data
cat <<'EOF' >/var/lib/vz/snippets/user-data
#cloud-config

# skip interactive question "Continue with autoinstall?"
runcmd:
  - [eval, 'echo $(cat /proc/cmdline) "autoinstall" > /root/cmdline']
  - [eval, 'mount -n --bind -o ro /root/cmdline /proc/cmdline']
  - [eval, 'snap restart subiquity.subiquity-server']
  - [eval, 'snap restart subiquity.subiquity-service']

autoinstall:
  version: 1
  locale: en_US
  keyboard:
    layout: de
  refresh-installer:
    update: yes
  source:
    id: ubuntu-server-minimal
    search_drivers: true
  storage:
    layout:
      name: lvm # lvm | zfs
      sizing-policy: all
      # NOTE: the `password` (LUKS) parameter only works with the `lvm` layout,
      # the guided `zfs` layout has no LUKS support - use a custom `storage.config` instead!
      # change afterwards with: `sudo cryptsetup luksChangeKey /dev/... -S 0`
      password: <LUKS_PLAIN_PASSPHRASE>  # pragma: allowlist secret
  identity:
    hostname: <HOSTNAME>
    username: <USERNAME>
    # create with: `mkpasswd -m sha-512`
    password: '<SHA512_PASSPHRASE>' # pragma: allowlist secret
  ssh:
    install-server: yes
    authorized-keys:
      - <AUTH_KEY>
    allow-pw: no
  packages:
    - qemu-guest-agent
    - vim
    - ubuntu-desktop-minimal
  late-commands:
    # Update GRUB configuration
    - curtin in-target --target=/target -- sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
    - curtin in-target --target=/target -- sed -i 's/^GRUB_CMDLINE_LINUX=".*"/GRUB_CMDLINE_LINUX=""/' /etc/default/grub
    # Run update-grub after making changes
    - curtin in-target --target=/target -- update-grub
    - curtin in-target --target=/target -- systemctl disable systemd-networkd-wait-online.service
    - curtin in-target --target=/target -- systemctl stop systemd-networkd-wait-online.service
EOF
```

> _`mkisofs` is provided by `xorriso` on current Debian/Ubuntu
> (`apt install xorriso`) - it is not installed by default._

```sh
cd /var/lib/vz/snippets && \
mkisofs -input-charset 'utf-8' -V cidata -lJR -o /var/lib/vz/template/iso/cloud-init.iso user-data meta-data && \
cd ~

qm set 9998 --scsi2 local-zfs:iso/cloud-init.iso,media=cdrom
qm set 9998 --boot order='scsi0;scsi1'
```

remove not needed sources after install finished:

```sh
qm set 9998 --delete scsi1
qm set 9998 --delete scsi2
```

after you not need anymore the installers remove them as credentials are else stored on server:

```sh
rm /var/lib/vz/snippets/user-data
rm /var/lib/vz/template/iso/cloud-init.iso
```

---

## \\\\ Helpful Functions

### // qm re-scan

if a vm is:

- not load correct
- shows not correct values
- not assign volumes correct
- ...

you can re-scan and fix vm's by run:

```sh
qm rescan --vmid <VM-ID>
```

### // qm unlock

if vm is locked for example after an power outage

```sh
qm unlock <VM-ID>
```

### // assign complete drivers to a VM

search for **disk-id**:

```sh
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,UUID --exclude 7
```

add **disk** to **vm**:

```sh
qm set <VM-ID> --scsi<NUMBER> /dev/disk/by-id/<DISK-ID/UUID>
```

### // Fix ESP "No space left on device" on kernel upgrade

> _Symptom: on `apt` install/upgrade of kernels the `zz-proxmox-boot` hook fails with
> `Failed to write data: No space left on device` and the kernel is not bootable.
> Reason: the ESPs (512MB by default) are full of old kernel files.
> The ESPs are **not** mounted by default, they only get mounted under
> `/var/tmp/espmounts/<UUID>` during boot operations._
>
> > _Baseline information:_
> >
> > - `proxmox-boot-tool status` shows the configured ESPs (see `/etc/kernel/proxmox-boot-uuids`)
> > - systemd-boot layout: kernels live in `EFI/proxmox/<version>/` + `loader/entries/`
> > - grub layout: kernels live as `vmlinuz-*`/`initrd.img-*` in the ESP **root**
> > - newer kernels are called `proxmox-kernel-<version>`, older ones `pve-kernel-<version>`

first check the current state:

```sh
proxmox-boot-tool status
dpkg -l | grep -E "proxmox-kernel|pve-kernel"
uname -r   # the running kernel, this one stays!
```

> _`proxmox-boot-tool clean` removes orphaned files, e.g. if an old UUID is still listed:
> `WARN: /dev/disk/by-uuid/<UUID> does not exist - clean '/etc/kernel/proxmox-boot-uuids'!`_

```sh
proxmox-boot-tool clean
```

purge the old kernel series (this also removes their files from the ESPs), replace `<MAJOR.MINOR>` with the series you want to remove, e.g. `6.17`:

```sh
apt purge 'proxmox-kernel-<MAJOR.MINOR>.*' 'pve-kernel-<MAJOR.MINOR>.*'
apt autoremove --purge
```

if the ESP is still full, mount the ESPs manually and delete the old kernel files (adjust the paths per the layout from above):

```sh
# mount every UUID listed in the file under /var/tmp (or use /mnt)
mkdir -p /var/tmp/esp && mount /dev/disk/by-uuid/<UUID> /var/tmp/esp
# systemd-boot layout:
rm -rf /var/tmp/esp/EFI/proxmox/<OLD_KERNEL_VERSION>
# grub layout:
rm -f /var/tmp/esp/vmlinuz-<OLD_KERNEL_VERSION> /var/tmp/esp/initrd.img-<OLD_KERNEL_VERSION>
umount /var/tmp/esp
```

> _If a mount fails with "busy" or the fs is 100% full, a `reboot` helps._

finally re-sync the ESPs and finish the pending upgrade:

```sh
update-initramfs -u -k all
proxmox-boot-tool refresh
apt full-upgrade
```

> _Prevention: after every kernel upgrade run `apt autoremove --purge` (it is enough to keep
> the running kernel + the two latest, done by `/etc/apt/apt.conf.d/76pveconf`) and set
> `Unattended-Upgrade::Remove-Unused-Kernel-Packages "true"` in `50unattended-upgrades`
> to clean up old kernels automatically._

---

## \\\\ Firewall

> _Enable the cluster firewall under `Datacenter > Firewall > Options` (Firewall: **Yes**),
> the default policy is **DROP** so nothing is reachable before you add rules._
>
> > _Make sure `net.bridge.bridge-nf-call-iptables=1` from the sysctl section above is active,
> > otherwise the firewall can not see the guest traffic!_
>
> _Set the rules once under `Datacenter > Firewall > Rules` (datacenter level applies to
> all nodes and guests), host-only rules go under `Datacenter > <Node> > Firewall > Rules`.
> PVE's **default rules already allow** TCP 22/8006 from management hosts, VNC
> 5900–5999, migration 60000–60050 and corosync **UDP 5405–5412**.
> They allow only ICMP types 3/4/11 - **not echo request**, so add an ICMP rule
> if you want guests/hosts to answer pings._

### // Host rules (SSH + Web-UI)

> _Replace `<YOUR_MGMT_NETWORK/CIDR>` with your management network/VPN (max. `/24`),
> without a `--source` all IPs are allowed (not recommended for the Web-UI!)_

```sh
pvesh create cluster/firewall/rules -type in -action ACCEPT -proto tcp -dport 8006 -source <YOUR_MGMT_NETWORK/CIDR> -log nolog -enable 1
pvesh create cluster/firewall/rules -type in -action ACCEPT -proto tcp -dport 22 -source <YOUR_MGMT_NETWORK/CIDR> -log nolog -enable 1

# allow pings (scope to a network or configure per guest instead of cluster-wide)
pvesh create cluster/firewall/rules -type in -action ACCEPT -proto icmp -source <YOUR_MGMT_NETWORK/CIDR> -log nolog -enable 1
```

---

## \\\\ Additional Security

### // Two-Factor Authentication (TFA)

> _Since Proxmox VE 8.1 you can configure TFA (TOTP or Webauthn) per user over the
> GUI under `Datacenter > Permissions > Users > <USER> > TFA`._
>
> _Use it for the `root@pam` user (and all privileged users) - it is also
> automatically applied to the **API** (tickets) once enabled._

### // Time synchronization

Proxmox VE 7+ ships **chrony** as the default NTP daemon, so there is normally
nothing to install. Verify it is active and syncing:

```sh
timedatectl set-timezone Europe/Berlin
systemctl enable --now chrony
systemctl status chrony --no-pager
chronyc tracking
```

> _Do not use `timedatectl set-ntp true` here: it starts `systemd-timesyncd`,
> which conflicts with chrony._

If chrony is missing (minimal Debian install), install it - and do **not** run
`ntp`, `openntpd` or `systemd-timesyncd` in parallel:

```sh
apt install chrony
```

Adjust the upstream servers in `/etc/chrony/chrony.conf`, then restart:

```sh
systemctl restart chrony
```

> _Use the same time sources on all nodes and on the backup server. Accurate time
> is required for TFA/WebAuthn, cluster quorum, backups and TLS._

### // ZFS health & backups

```sh
zpool status
zpool list -v
```

> _Schedule regular `zpool scrub` runs and SMART checks, and alert on degraded
> pools. Back up the host config (above) **and** the VMs/CTs with PBS (or an
> equivalent) - a ZFS snapshot on the same host is not a backup._

### // Brute-force protection (optional)

`fail2ban` can ban repeated failures against SSH and the PVE Web UI (`proxmox`
jail). Keep it behind the management-network firewall rules above.

### // CPU Microcode & Firmware updates

> _Install the microcode updates for your host CPU, they get applied on reboot
> and close known CPU vulnerabilities (e.g. Spectre/Meltdown):_

```sh
# for AMD CPUs:
apt install amd64-microcode
# for Intel CPUs:
apt install intel-microcode
```

> _`pve-firmware` (already installed by default) provides the rest of the firmware
> updates (GPU, NIC, ...)._

### // Backup the host configuration

> _Besides the VMs/CTs also backup the host configuration - a lot changes under
> `/etc` (and `/etc/pve` for the cluster config, synced between nodes)._
>
> _`etckeeper` tracks `/etc` in a git repository, handy to review and restore changes
> and to include it into your backup strategy (e.g. Proxmox Backup Server host backups):_

```sh
apt install etckeeper
```

### // CIS Benchmark

> _There is **no official CIS benchmark for Proxmox VE** - apply the **CIS Debian**
> benchmark to the host OS instead. Community guides exist, e.g.
> <https://github.com/HomeSecExplorer/Proxmox-Hardening-Guide>{:target="\_blank"},
> with the following deviations for a PVE host:_
>
> > - **root login** stays enabled with key-only auth (`PermitRootLogin prohibit-password`)
> > - `DisableForwarding yes` blocks local port-forwarding (`ssh -L`) from the host -
> >   usually fine on a PVE host
> > - the **`fuse` kernel module is required** by Proxmox (do not disable it)
> > - the **Proxmox firewall** replaces some iptables hardening on the host
> > - install **Debian first, then Proxmox on top**, for the most CIS-compliant install

---

## \\\\ Resources & more information

- <https://pve.proxmox.com/wiki/Package_Repositories>{:target="\_blank"}
- <https://pve.proxmox.com/pve-docs/pve-admin-guide.html#system_software_updates>{:target="\_blank"}
- <https://pve.proxmox.com/wiki/Host_Bootloader>{:target="\_blank"}
- <https://wiki.debian.org/UnattendedUpgrades>{:target="\_blank"}
- <https://www.proxmox.com/de/downloads>{:target="\_blank"}
- <https://pve.proxmox.com/pve-docs/pve-admin-guide.pdf>{:target="\_blank"}
- <https://pve.proxmox.com/wiki/Performance_Tweaks>{:target="\_blank"}
- <https://pve.proxmox.com/wiki/ZFS:_Tips_and_Tricks#Install_on_a_high_performance_system>{:target="\_blank"}
- <https://www.servethehome.com/how-to-pass-through-pcie-nics-with-proxmox-ve-on-intel-and-amd>{:target="\_blank"}
- <https://pve.proxmox.com/wiki/PCI_Passthrough>{:target="\_blank"}
- <https://www.dlford.io/memory-tuning-proxmox-zfs>{:target="\_blank"}
- <https://www.reddit.com/r/VFIO/comments/11mqtna/successful_passthrough_of_an_rx_7900_xt/>{:target="\_blank"}
- <https://forum.level1techs.com/t/vfio-passthrough-in-2023-call-to-arms/199671/101?page=4>{:target="\_blank"}
- <https://docs.kernel.org/gpu/amdgpu/module-parameters.html>{:target="\_blank"}
- <https://bbs.archlinux.org/viewtopic.php?pid=2070655#p2070655>{:target="\_blank"}
- <https://forum.manjaro.org/t/cannot-isolate-gpu-for-vfio/139292/5>{:target="\_blank"}
- <https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF>{:target="\_blank"}
- <https://www.wundertech.net/how-to-set-up-gpu-passthrough-on-proxmox/>{:target="\_blank"}
- <https://3os.org/infrastructure/proxmox/gpu-passthrough/gpu-passthrough-to-vm/#proxmox-configuration-for-gpu-passthrough>{:target="\_blank"}
- <https://pve.proxmox.com/wiki/PCI(e)_Passthrough>{:target="\_blank"}
- <https://docs.renderex.ae/posts/Enabling-hugepages/>{:target="\_blank"}
- <https://forum.proxmox.com/threads/hey-proxmox-community-lets-talk-about-resources-isolation.124256/>{:target="\_blank"}
- <https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html>{:target="\_blank"}
- <https://canonical-subiquity.readthedocs-hosted.com/en/latest/howto/autoinstall-quickstart.html>{:target="\_blank"}
- kernel-parameters
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=amd_iommu>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=iommu>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=pcie_acs_override>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=nofb>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=nomodeset>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=initcall_blacklist>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=default_hugepagesz>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=hugepagesz>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=hugepages>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=amdgpu.sg_display>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=amd_pstate>{:target="\_blank"}
  - <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=amd_pstate.shared_mem>{:target="\_blank"}
