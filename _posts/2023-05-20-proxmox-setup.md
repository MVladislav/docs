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

create a new file and past the **no-subscription**-repo into it (**[INFO](https://pve.proxmox.com/wiki/Package_Repositories#sysadmin_no_subscription_repo)**):

```sh
$echo 'deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription' \
> /etc/apt/sources.list.d/pve.list
```

commit the existing **enterprise**-repo (**[INFO](https://pve.proxmox.com/wiki/Package_Repositories#sysadmin_enterprise_repo)**):

```sh
$sed -i '1 s/^[^#]/#$1 /' /etc/apt/sources.list.d/pve-enterprise.list
```

remove the popup for non existing subscription ('No valid sub'):

```sh
$sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" \
/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js \
&& systemctl restart pveproxy.service
```

## \\\\ ZFS config's

> _Check for values you need, this change is mostly for smaller env. needed
> where less RAM is available or less RAM with a bigger hard-drive size._
>
> _Especially we can reduce the RAM usage for ARC on proxmox it self,
> because we for example are not a file server._
>
> > The size of the ARC, which is managed by ZFS, depends on the available RAM in the system.
> > A larger ARC can hold more data in memory, thereby reducing the number of disk accesses
> > required for read operations. This caching mechanism can greatly improve the overall
> > performance of a ZFS system.
> >
> > While RAM size influences the ARC's capacity and the amount of data that can be cached,
> > it's essential to consider the disk size as well. The overall storage capacity of the
> > disks in a ZFS system determines the amount of data that can be stored persistently.
> > Although ZFS is capable of compressing and deduplicating data to optimize disk space
> > utilization, the physical capacity of the disks plays a significant role in determining
> > the maximum amount of data that can be stored in the system.

### // ARC

create a file under **modprobe** and set **arc** `min` & `max`:

> _This example is for available RAM of 64GB
> to only allow a max usage of 8G of RAM for ARC_
>
> **_do not set less than 8G_**
>
> > - zfs_arc_min:
> >   Specifies the minimum size of the ARC, ensuring a baseline cache for performance during memory pressure.
> > - zfs_arc_max:
> >   Sets the maximum size of the ARC. Useful for managing memory resources and optimizing cache size for specific workloads.

```sh
# calc: 4 * 1024 * 1024 * 1024 = 4294967296
$echo 'options zfs zfs_arc_min=4294967296' > /etc/modprobe.d/zfs.conf
# calc: 8 * 1024 * 1024 * 1024 = 8589934592
$echo 'options zfs zfs_arc_max=8589934592' >> /etc/modprobe.d/zfs.conf

# on-disk checksum verification during the pool import process, helping to ensure data integrity
#options zfs zfs_flags=0x10
```

run refresh command to update modprobe changes to system:

```sh
$update-initramfs -u
$pve-efiboot-tool refresh
```

### // KSM

update in the **ksmtuned** file the line `KSM_THRES_COEF`:

> _Possible example for 64GB of RAM_
>
> > The `KSM_THRES_COEF` parameter controls the level of memory sharing and deduplication
> > performed by the Kernel Samepage Merging (KSM) feature in the Linux kernel.
> >
> > By adjusting `KSM_THRES_COEF`, you can specify the threshold for memory page merging.
> > Higher values encourage more aggressive merging, resulting in increased memory savings,
> > but potentially higher CPU usage. Lower values reduce merging, conserving CPU resources
> > but potentially reducing memory savings.
>
> > Please note that opting for KSM results in a trade-off wherein
> > the attack surface for **potential side channel exploits** is heightened.
> > To avoid you can also disable it by run: `systemctl disable ksmtuned`

```sh
$sed -i 's/KSM_THRES_COEF=.*/KSM_THRES_COEF=35/' /etc/ksmtuned.conf
```

restart service to perform the change:

```sh
$systemctl restart ksmtuned.service
```

## \\\\ SWAP remove

for proxmox we do not need swap usage, so we will disable it, if it not always disabled.

open `/etc/fstab` and comment the line where **swap** is defined, for example:

```properties
...
# /dev/mapper/cryptoswap none    swap    sw      0       0
...
```

also disable the current used swap on runtime:

```sh
$swapoff -a
```

## \\\\ SMTP Configuration

> Since version `> 8.1` it is possible to setup SMTP over gui under `Datacenter > Notifications`.
> Manual config below is not anymore needed.

### // GUI Setup

over the gui set up email addresses for each users
and define default options for sending emails from.

set up the default email address from which mails will be sent from:

- open page under `Datacenter > Options`
- edit the field `Email from address`

specify individual email addresses for each user to receive mail-related notifications:

- open page under `Datacenter > Permissions > Users`
- edit each user and set the field `E-Mail`

### // Terminal Setup

install **dependencies**:

```sh
$apt install libsasl2-modules mailutils postfix-pcre
```

**open** the file `/etc/postfix/main.cf` and **configure** the **Postfix main configuration**, for example like follow:

> replace:
>
> > - `<SERVER_HOSTNAME_OR_IP>`
> > - `<YOUR_SMPT_HOST>`

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

# TLS protocol versions
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, TLSv1.1, TLSv1.2

# TLS ciphers
smtp_tls_ciphers = high

# CA file path
smtp_tls_CAfile = /etc/ssl/certs/Entrust_Root_Certification_Authority.pem

# Enable SMTP TLS session caching
smtp_tls_session_cache_database = btree:/var/lib/postfix/smtp_tls_session_cache
smtp_tls_session_cache_timeout = 3600s
```

**create** a new file for storing the **SASL password**:

```sh
$nano /etc/postfix/sasl_passwd
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
$chmod 600 /etc/postfix/sasl_passwd
$postmap hash:/etc/postfix/sasl_passwd
```

**restart** the **daemon** and **Postfix** service to apply the changes:

```sh
$systemctl daemon-reload
$postfix reload && systemctl restart postfix
```

**verify** by send a test mail:

> replace:
>
> > - `<SENDER_ADDRESS>`
> > - `<RECIPIENT_ADDRESS>`

```sh
$echo "Test mail from postfix" | mail -r <SENDER_ADDRESS> -s "Test Postfix" <RECIPIENT_ADDRESS>
```

## \\\\ SSH

SSH hardening is crucial for maintaining the security and integrity of your system.
It provides stronger authentication, protects against brute-force attacks, ensures encryption
and data integrity, allows for granular access control, helps meet security compliance requirements,
and defends against vulnerabilities. By implementing SSH hardening practices, you can significantly
reduce the risk of unauthorized access and protect your sensitive information.

upload an **ssh-public-key** into `/root/.ssh/authorized_keys` for future logins.
This will allow you to login using your public key once the subsequent hardening steps are in place.

update the **root** `/root/.ssh/config` file, like follow:

```properties
# Read more about SSH config files: https://linux.die.net/man/5/ssh_config
# ~/.ssh/config

# EXAMPLE: Generate an RSA key (4096 bits)
# ssh-keygen -t rsa -b 4096 -o -f ~/.ssh/id_rsa_<type>_<purpose>_$(date +%Y_%m_%d) -C "<type>_<purpose>_$(date +%Y_%m_%d)"
#
# EXAMPLE: Generate an ED25519 key (modern & fast)
# ssh-keygen -t ed25519 -o -f ~/.ssh/id_ed25519_<type>_<purpose>_$(date +%Y_%m_%d) -C "<type>_<purpose>_$(date +%Y_%m_%d)"
#
# EXAMPLE: Generate an ED25519-SK key (hardware-backed, e.g., YubiKey)
# ssh-keygen -t ed25519-sk -o -f ~/.ssh/id_ed25519_sk_<type>_<purpose>_$(date +%Y_%m_%d) -C "<type>_<purpose>_$(date +%Y_%m_%d)"
#
# EXAMPLE: Generate an ECDSA key (P-384 curve)
# ssh-keygen -t ecdsa -b 384 -o -f ~/.ssh/id_ecdsa_p384_<type>_<purpose>_$(date +%Y_%m_%d) -C "<type>_<purpose>_$(date +%Y_%m_%d)"
#
# PLACEHOLDER INFO:
#   - <type>   : e.g., infra, service, server
#   - <purpose>: e.g., nas, hetzner, test

# ------------------------------------------------------------------------------
# Ensure KnownHosts are unreadable if leaked - it is otherwise easier to know which hosts your keys have access to.
HashKnownHosts yes

# Host keys the client accepts - order here is honored by OpenSSH
HostKeyAlgorithms ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa,ecdsa-sha2-nistp521-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp521,ecdsa-sha2-nistp384,ecdsa-sha2-nistp256

KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
MACs hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com
Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# GENERIC ----------------------------------------------------------------------
Host *
  SetEnv TERM=xterm-256color
  User root
  Port 22
  LogLevel INFO
  Compression yes
  SendEnv LANG LC_*
  HashKnownHosts yes
  GSSAPIAuthentication yes
  IdentitiesOnly yes
  AddressFamily inet
  # Preferredauthentications keyboard-interactive,password,publickey,hostbased,gssapi-with-mic
  Protocol 2
  ServerAliveInterval 60
  # DynamicForward <PORT>
```

harden the SSH configuration by open `/etc/ssh/sshd_config` and setup like follow:

> _Note: the property `PermitRootLogin` is **not** setup as **recommended** because we not create a non root user_

```properties
Include /etc/ssh/sshd_config.d/*.conf
KbdInteractiveAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp  /usr/lib/ssh/sftp-server -f AUTHPRIV -l INFO
Banner /etc/issue.net
Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
ClientAliveInterval 15
ClientAliveCountMax 3
DisableForwarding yes
GSSAPIAuthentication no
HostbasedAuthentication no
IgnoreRhosts yes
KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
LoginGraceTime 60
LogLevel VERBOSE
MACs hmac-sha2-512,hmac-sha2-256,hmac-sha1,umac-128@openssh.com
MaxAuthTries 4
MaxSessions 10
MaxStartups 10:30:60
PermitEmptyPasswords no
PermitRootLogin yes
PermitUserEnvironment no
Port 22
AddressFamily inet
ListenAddress 0.0.0.0
AuthenticationMethods publickey
StrictModes yes
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
GSSAPICleanupCredentials yes
AllowAgentForwarding no
AllowTcpForwarding no
TCPKeepAlive no
UseDNS no
AuthorizedKeysFile .ssh/authorized_keys
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_rsa_key
```

restart the ssh service to ensuring that the modifications take effect:

```sh
$systemctl restart ssh
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
#vm.nr_hugepages=128
vm.nr_hugepages=2048
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

# Disable IPv6 if not required.
# Recommended for systems without IPv6 dependencies for security and performance reasons.
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

# Prevent sending ICMP redirects.
# Improves security for non-router devices to avoid man-in-the-middle attacks.
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0

# Disable IP forwarding to prevent the system from routing packets, increasing security.
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

# Disable Path MTU Discovery to reduce the risk of attackers manipulating MTU values.
net.ipv4.ip_no_pmtu_disc=1

# Disable TCP timestamps to improve security against timing-based attacks. (RFC1323/RFC7323)
net.ipv4.tcp_timestamps=0

# Protect Against TCP Time-Wait to mitigate DoS attack attempts.
net.ipv4.tcp_rfc1337=1

# Enable temporary IPv6 addresses for better privacy (anonymizing address information).
net.ipv6.conf.all.use_tempaddr=2
net.ipv6.conf.default.use_tempaddr=2

# Enable source address verification for IPv6.
# This makes it more difficult for an attacker to spoof their IP address
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0

# Clear routing cache to ensure routing decisions are made based on up-to-date information.
net.ipv4.route.flush=1
net.ipv6.route.flush=1

# Enable TCP Fast Open for faster connections, enhancing performance for both clients and servers.
# - 0: Disable TCP Fast Open (default if not explicitly set).
# - 1: Enable TCP Fast Open for outgoing connections (clients).
# - 2: Enable TCP Fast Open for incoming connections (servers).
# - 3: Enable TCP Fast Open for both outgoing and incoming connections.
net.ipv4.tcp_fastopen=3

# Set congestion control algorithm for better throughput and latency.
net.ipv4.tcp_congestion_control=bbr
#net.ipv4.tcp_congestion_control=htcp
#net.ipv4.tcp_congestion_control=cubic

# Default queuing discipline (reduces latency under load).
net.core.default_qdisc=fq_codel
#net.core.default_qdisc=fq

# Enable TCP window scaling for larger buffers, useful in high-bandwidth or high-latency networks.
# Increase Linux autotuning TCP buffer limit to 128MB (64MB).
net.ipv4.tcp_window_scaling=3

# Enable MTU Probing (recommended for hosts with jumbo frames enabled).
net.ipv4.tcp_mtu_probing=1

# Enable auto-tuning of the receive buffer size for better performance in high-throughput networks.
net.ipv4.tcp_moderate_rcvbuf=1

# Don't cache the slow start threshold from previous connections for more consistent performance.
net.ipv4.tcp_no_metrics_save=1

# Enable low-latency TCP connections for time-sensitive applications.
net.ipv4.tcp_low_latency=1

# Disable netfilter on bridge devices for improved performance in virtualized environments.
net.bridge.bridge-nf-call-iptables=0
net.bridge.bridge-nf-call-arptables=0
net.bridge.bridge-nf-call-ip6tables=0

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
# Backuped optional values: 86400 (24h)
net.ipv6.conf.all.temp_prefered_lft=3600
net.ipv6.conf.default.temp_prefered_lft=3600
# Set valid lifetime to 2 hours (time before the old address is invalidated)
# Backuped optional values: 604800 (168h)
net.ipv6.conf.all.temp_valid_lft=7200
net.ipv6.conf.default.temp_valid_lft=7200

###################################################################
# ==> Networking (Performance Parameters)

# Increase maximum receive/send socket buffer sizes for handling large data streams.
# Backuped optional values: 212992 | 67108864 | 134217728
net.core.rmem_max=134217728
net.core.wmem_max=134217728

# Increase input queue size for better handling of high traffic volumes.
# Backuped optional values: 1000 | 3000
#net.core.netdev_max_backlog=1000

# Increase maximum number of pending connections to support high traffic loads.
# Backuped optional values: 4096 | 65535
#net.core.somaxconn=4096

# Number of flow entries for Receive Packet Steering (RPS).
# Backuped optional values: 0 | 32768
#net.core.rps_sock_flow_entries=32768

# Optimize TCP buffers for high throughput connections (low, pressure, high).
# Backuped optional values: 4096 131072 6291456 | 4096 87380 67108864 | 4096 87380 134217728
#net.ipv4.tcp_rmem=4096 87380 134217728
# Backuped optional values: 4096 16384 4194304 | 4096 87380 67108864 | 4096 87380 134217728
#net.ipv4.tcp_wmem=4096 87380 134217728

# Maximum number of queued SYN requests, higher values prevent SYN flood attacks.
# Backuped optional values: 512 | 4096
#net.ipv4.tcp_max_syn_backlog=4096

# Define memory pressure thresholds for TCP memory management (low, pressure, high).
# Backuped optional values: 93222 124299 186444 | 4194304 4194304 4194304 | 8388608 12582912 16777216
#net.ipv4.tcp_mem=8388608 12582912 16777216

###################################################################
# ==> Filesystem Parameters

# Increase maximum number of open file descriptors system-wide, supporting applications with many files open.
# Backuped optional values: 2097152 | 262144 | 4194304 | 9223372036854775807
fs.file-max=9223372036854775807

# Increase maximum virtual memory map count for applications using large amounts of virtual memory.
vm.max_map_count=1048576

###################################################################
# Notes and Optional Settings

# ###################################################################
# Enabling TCP Timestamps and PMTU Discovery can improve certain network performance metrics
# but may expose systems to specific types of attacks:
net.ipv4.tcp_timestamps=1
net.ipv4.ip_no_pmtu_disc=0
net.ipv4.tcp_fastopen=1

# ###################################################################
# If IPv6 is required, enable it with the following settings
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.default.disable_ipv6=0
net.ipv6.conf.lo.disable_ipv6=0
```

run following command to perform the changes:

```sh
$sysctl --system
```

## \\\\ Grub Optimizing & PCI Passthrough

Unlocking the Power of **GPU** and **USB-PCI** Card **Passthrough** in Proxmox

### // Setup BIOS Boot Options

> _These steps ensure that the necessary boot parameters are properly configured for PCI passthrough in Proxmox._

**SVM (Secure Virtual Machine)** `ENABLED`:

SVM is AMD's version of Intel VT-x. It provides support for virtualization, allowing multiple operating systems to run concurrently on a single AMD processor.
Enable SVM in the BIOS if you plan to use virtualization technologies such as AMD-V for running virtual machines on your system.

**SMT (Simultaneous Multithreading)** `AUTO`:

SMT is a technology that allows multiple threads to run on a single CPU core. It is AMD's equivalent to Intel's Hyper-Threading Technology.
Enabling SMT improves multitasking performance by allowing each CPU core to handle multiple threads simultaneously. This is beneficial for applications that can utilize multiple threads.

**Above 4G Decoding** `ENABLED`:

This option allows the system to decode memory above the 4-gigabyte boundary. It's essential for systems with more than 4 GB of RAM and also relevant for devices that require memory-mapped I/O above 4 GB.
Enable this option when your system has more than 4 GB of RAM or when you are using devices that require access to memory above the 4 GB limit, such as certain types of high-performance GPUs or RAID controllers.

**RE-SIZE BAR** `DISABLED`:

Resizable BAR is a feature that allows the CPU to access the entire GPU memory directly, enhancing data transfer speeds between the CPU and GPU.
Enable Resizable BAR for improved gaming performance and faster data transfers, especially with modern GPUs and compatible CPUs.

**IOMMU (Input-Output Memory Management Unit)** `ENABLED`:

IOMMU is a memory management unit that is used to manage memory transfers between devices and the system's memory. It is crucial for virtualization, allowing hardware devices to be assigned directly to virtual machines.
Enable IOMMU for virtualization setups, especially when using GPU passthrough, allowing virtual machines direct access to specific hardware components.

**ACS (Access Control Services)** `ENABLED`:

ACS allows finer control over PCIe devices, ensuring that devices in the same IOMMU group can be separated for better virtualization support.
Enabling ACS is often essential for more advanced virtualization setups, especially when GPU passthrough is used, to prevent conflicts between devices and ensure proper isolation for virtual machines.

**ARI support (Alternative Routing-ID Interpretation Support)** `AUTO`:

ARI is a PCIe feature that provides additional capability to address more devices on the PCIe bus.
Enabling ARI support allows systems to address more PCIe devices efficiently, which is particularly relevant in high-performance computing environments where numerous PCIe devices are used.

**ARI enumeration (Alternative Routing-ID Interpretation Enumeration (ARI Forwarding Support))** `AUTO`:

ARI Enumeration is the ability of the BIOS to detect and support PCIe devices that use ARI.
Enabling ARI Enumeration ensures that PCIe devices using ARI are properly recognized and utilized by the system, ensuring efficient addressing and communication with these devices.

### // Setup Grub Boot Parameters

> _These steps ensure that the necessary boot parameters are properly configured for in general PCI passthrough and specific for GPU passthrough in Proxmox._

determine whether the system is using Grub or systemd as the bootloader:

```sh
$efibootmgr -v | grep -q 'File(\\EFI\\SYSTEMD\\SYSTEMD-BOOTX64.EFI)' && echo "systemd" || echo "grub"
```

depends on the result, use one of the two next sub topics (_Grub Configuration or Systemd Configuration_)
to setup the correct configuration.

#### Grub Configuration

open the grub configuration file:

```sh
$nano /etc/default/grub
```

locate the line starting with `GRUB_CMDLINE_LINUX_DEFAULT` and modify it as follows:

TODO: `consoleblank=0 systemd.show_status=true console=tty1 console=ttyS0`

```properties
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt amd_pstate=passive amd_pstate.shared_mem=1 cpufreq.default_governor=schedutil processor.max_cstate=4"

# (optional GPU) extend for better GPU support with:
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt amd_pstate=passive amd_pstate.shared_mem=1 cpufreq.default_governor=schedutil processor.max_cstate=4 amdgpu.sg_display=0 pcie_acs_override=downstream,multifunction initcall_blacklist=sysfb_init"
```

update the changes:

```sh
#$update-grub
$proxmox-boot-tool refresh
```

verify the changes written correct and exist after restart:

```sh
$cat /proc/cmdline
```

#### Systemd Configuration

edit the kernel command line by running the following command:

> _Note: Before running the command, verify the first information `root=ZFS=rpool/ROOT/pve-1 boot=zfs` and update it if necessary._

```sh
$echo 'root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet amd_iommu=on iommu=pt amd_pstate=passive amd_pstate.shared_mem=1 cpufreq.default_governor=schedutil processor.max_cstate=4' > /etc/kernel/cmdline

# (optional GPU) extend for better GPU support with:
$echo 'root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet amd_iommu=on iommu=pt amd_pstate=passive amd_pstate.shared_mem=1 cpufreq.default_governor=schedutil processor.max_cstate=4 amdgpu.sg_display=0 pcie_acs_override=downstream,multifunction initcall_blacklist=sysfb_init' > /etc/kernel/cmdline
```

update the changes:

```sh
$proxmox-boot-tool refresh
```

verify the changes written correct and exist after restart:

```sh
$cat /proc/cmdline
```

#### Parameter Explanation

| Topic                             | Key                        | Good Value                          | Optional Value                | Purpose                                                                   |
| :-------------------------------- | :------------------------- | :---------------------------------- | :---------------------------- | :------------------------------------------------------------------------ |
| **AMD-Specific Tweaks**           |                            |                                     |                               |                                                                           |
|                                   | `amd_iommu`                | `on`                                | `force_enable`                | Enables AMD-Vi (IOMMU) for PCI passthrough (required for GPU/VFIO).       |
|                                   | `amd_pstate`               | `passive`                           | `active` (if kernel supports) | Uses AMD's P-State driver for dynamic CPU scaling (Zen 3/4+).             |
|                                   | `amd_pstate.shared_mem`    | `1`                                 | -                             | Enables shared memory mode for Zen 4 CPUs.                                |
|                                   | `amdgpu.sg_display`        | `0`                                 | `1` (default)                 | Disables scatter-gather display for APUs to fix flickering/artifacts.     |
| **CPU Power Management**          |                            |                                     |                               |                                                                           |
|                                   | `cpufreq.default_governor` | `schedutil` or `performance` (home) | `ondemand` (business)         | Controls CPU frequency scaling (performance vs. power efficiency).        |
|                                   | `cpuidle.governor`         | `teo`                               | `menu` (legacy)               | Optimizes idle states for AMD CPUs (low latency).                         |
|                                   | `processor.max_cstate`     | `5` or `4` or `3`                   | `1` or `2` (business)         | Limits deep sleep states (C-states) to reduce VM stuttering.              |
| **Memory Optimization**           |                            |                                     |                               |                                                                           |
|                                   | `default_hugepagesz`       | `1G` (if supported)                 | `2M`                          | Sets default hugepage size (improves VM memory efficiency).               |
|                                   | `hugepages`                | `8192` (16GB of 2MB pages)          | Adjust based on RAM           | Preallocates static hugepages for VMs/containers.                         |
|                                   | `hugepagesz`               | `1G` or `2M`                        | -                             | Explicitly defines hugepage size (required if not using default).         |
|                                   | `transparent_hugepage`     | `never` (home)                      | `madvise` (business)          | Disables auto hugepage allocation for manual control.                     |
| **IOMMU/PCI Passthrough**         |                            |                                     |                               |                                                                           |
|                                   | `iommu`                    | `pt`                                | `on`                          | Configures IOMMU in passthrough mode (isolates devices for VMs).          |
|                                   | `pcie_acs_override`        | `downstream,multifunction`          | -                             | Bypasses PCIe ACS checks (unsafe but fixes passthrough on some hardware). |
| **Kernel/Graphics Fixes**         |                            |                                     |                               |                                                                           |
|                                   | `initcall_blacklist`       | `sysfb_init`                        | -                             | Fixes AMD GPU/framebuffer conflicts during boot.                          |
|                                   | `nofb`                     | -                                   | _Add if boot stalls_          | Disables framebuffer to resolve GPU passthrough conflicts.                |
|                                   | `nomodeset`                | -                                   | _Add temporarily_             | Skips GPU driver loading at boot (debugging passthrough).                 |
| **Legacy/Intel (Ignore for AMD)** |                            |                                     |                               |                                                                           |
|                                   | `intel_pstate`             | `disable`                           | -                             | Disables Intel's P-State driver (irrelevant for AMD CPUs).                |

Extended Descriptions `amd_iommu`:

- **Purpose**: Enables AMD's **IOMMU** (Input-Output Memory Management Unit), a hardware feature required for PCI passthrough.
- **Details**:
  - `force_enable` overrides BIOS settings if IOMMU is disabled.
  - Required for GPU passthrough (e.g., assigning an AMD GPU to a VM).

Extended Descriptions `iommu`:

- **Purpose**: Configures IOMMU behavior.
- **Details**:
  - `pt` (passthrough mode) isolates devices into separate IOMMU groups for direct VM assignment.
  - `on` enables full IOMMU but may group devices together (less flexible).

Extended Descriptions `pcie_acs_override`:

- **Purpose**: Bypasses PCIe ACS checks for passthrough.
- **Details**:
  - ⚠️ **Security Risk**: Weakens isolation between devices. Use only in trusted environments.
  - `downstream`: Targets devices behind PCIe switches.
  - `multifunction`: Splits multi-function devices (e.g., dual NICs).

Extended Descriptions `nofb`:

- **Purpose**: Disables framebuffer to resolve GPU conflicts.
- **Details**:
  - Useful if the host OS interferes with GPU passthrough (e.g., error `vfio-pci: Cannot reset device`).

Extended Descriptions `nomodeset`:

- **Purpose**: Prevents the kernel from initializing GPU drivers.
- **Details**:
  - Forces the system to use basic video modes (helpful for debugging passthrough).

Extended Descriptions `initcall_blacklist`:

- **Purpose**: Skips problematic kernel functions during boot.
- **Details**:
  - `sysfb_init`: Fixes conflicts when AMD GPUs and firmware framebuffers clash.

Extended Descriptions `default_hugepagesz` / `hugepagesz` / `hugepages`:

- **Purpose**: Optimizes memory for VMs.
- **Details**:
  - **Hugepages** reduce memory fragmentation and TLB misses (critical for databases/VMs).
  - Use `1G` pages if your CPU supports them (check with `grep pdpe1gb /proc/cpuinfo`).
  - Allocate `hugepages` **before** starting VMs to avoid host OOM errors.
  - Verify with `cat /proc/meminfo | grep HugePages`

Extended Descriptions `amdgpu.sg_display`:

- **Purpose**: Fixes APU display issues.
- **Details**:
  - `0` disables scatter-gather display (fixes flickering on APUs like Ryzen 5xxxG/7xxxG).

Extended Descriptions `amd_pstate`:

- **Purpose**: AMD's CPU frequency scaling driver.
- **Details**:
  - `passive`: Balances power and performance (uses CPPC for Zen 3/4).
  - `active`: Aggressive scaling (requires kernel ≥6.3).

Extended Descriptions `cpufreq.default_governor`:

- **Purpose**: Controls the selection of CPU idle states (C-states) to balance power saving and performance.
- **Details**:
  - `performance`: Locks CPU at max frequency (best for VMs).
  - `schedutil`: Balances performance/power using kernel scheduler hints (modern alternative to `ondemand`).

Extended Descriptions `cpuidle.governor`:

- **Purpose**: Controls how the CPU selects idle states (C-states) to balance power saving and performance.
- **Details**:
  - `teo`: is optimized for intermittent workloads on AMD systems.
  - `menu`: dynamically selects the optimal idle state (common default).
  - `ladder`: is simpler and may benefit older or real-time systems.
  - `haltpoll`: is tailored for virtual machine environments (KVM).
  - Check current governor `cat /sys/devices/system/cpu/cpuidle/current_governor`
  - List available governors `cat /sys/devices/system/cpu/cpuidle/available_governors`

Extended Descriptions `processor.max_cstate`:

- **Purpose**: Limits the deepest CPU idle state to reduce latency and minimize VM stuttering.
- **Details**:
  - Higher values (e.g., 3–5) allow deeper sleep states for more power saving.
  - Lower values (e.g., 1–2) restrict sleep depth for better responsiveness.

### // Setup VFIO Framework

> _Verify the content in `/etc/modules`,
> the first command will clear the file_
>
> > Ensure that the VFIO framework and its necessary components are loaded automatically during system startup.
> > This is essential for successful GPU passthrough and PCI device passthrough in Proxmox.
> >
> > - vfio:
> >   - The VFIO module is the core component of the VFIO framework, providing the infrastructure for PCI device passthrough.
> > - vfio-pci:
> >   - The VFIO PCI module provides support for PCI devices within the VFIO framework, enabling the passthrough
> >     of PCI devices to virtual machines.
> > - vfio_iommu_type1:
> >   - This module enables the VFIO IOMMU (Input-Output Memory Management Unit) driver, allowing the virtual
> >     machines to directly access hardware resources.

```sh
$echo 'vfio' > /etc/modules
$echo 'vfio_pci' >> /etc/modules
$echo 'vfio_iommu_type1' >> /etc/modules
```

### // Setup pve-blacklist.conf

> _Verify the content in `/etc/modprobe.d/pve-blacklist.conf`,
> the first command will clear the file_
>
> > Blacklisting these drivers, such as `nouveau`, `amdgpu`, `radeon`, `nvidiafb`, `nvidia`, and `nvidia-gpu`,
> > prevents them from loading during system startup. This can help avoid conflicts and ensure a smoother
> > GPU passthrough experience.

```sh
$echo 'blacklist nouveau' > /etc/modprobe.d/pve-blacklist.conf
$echo 'blacklist amdgpu' >> /etc/modprobe.d/pve-blacklist.conf
$echo 'blacklist radeon' >> /etc/modprobe.d/pve-blacklist.conf
$echo 'blacklist nvidia*' >> /etc/modprobe.d/pve-blacklist.conf
# $echo 'blacklist nvidiafb' >> /etc/modprobe.d/pve-blacklist.conf
# $echo 'blacklist nvidia' >> /etc/modprobe.d/pve-blacklist.conf
# $echo 'blacklist nvidia-gpu' >> /etc/modprobe.d/pve-blacklist.conf
```

### // Setup iommu_unsafe_interrupts.conf

> Enabling unsafe interrupts through "iommu_unsafe_interrupts.conf" **improves device performance** but poses **security risks**.
> It allows the VFIO driver to process **device interrupts without safety checks**, benefiting certain devices.
> However, use caution and assess the risks before enabling it. **GPU passthrough** dedicates a physical GPU to a VM for
> **better graphics performance**. Enabling unsafe interrupts with "iommu_unsafe_interrupts.conf" enhances GPU passthrough
> by **reducing latency and improving responsiveness**, **bypassing some safety checks**.

```sh
$echo 'options vfio_iommu_type1 allow_unsafe_interrupts=1' \
> /etc/modprobe.d/iommu_unsafe_interrupts.conf
```

### // Setup kvm.conf

> Adding options to the KVM configuration in Proxmox ignores and avoids reporting specific Model
> Specific Registers (MSRs). This improves compatibility and prevents conflicts, especially for GPU passthrough.
> By ignoring problematic MSR requests from virtual machines, it enhances stability and performance.

```sh
$echo 'options kvm ignore_msrs=1 report_ignored_msrs=0' \
> /etc/modprobe.d/kvm.conf
```

### // Setup softdep.conf

> The command configures a soft dependency between the defined driver and the VFIO PCI driver in Proxmox.
> This ensures the correct driver initialization order for defined driver passthrough and other PCI device passthrough
> scenarios like the defined drivers below for amdgpu, usb-pci-devices, ...

```sh
$echo 'softdep amdgpu pre: vfio-pci' >> /etc/modprobe.d/softdep.conf
$echo 'softdep snd_hda_intel pre: vfio-pci' >> /etc/modprobe.d/softdep.conf
$echo 'softdep xhci_hcd pre: vfio-pci' >> /etc/modprobe.d/softdep.conf
```

### // Setup vfio modprobe :: GPU

To passthrough a GPU to a virtual machine, the device must not be used by the Proxmox host.  
This can be achieved by binding the GPU and its audio device to the `vfio-pci` driver during boot.  
Once configured, the GPU is hidden from the host system and becomes available for passthrough.

List all GPU devices and identify the one to be assigned to a VM.  
Record the PCI address (e.g. `2b:00.0`). For later use, only the part before the dot is required (`2b:00`):

```sh
$lspci | grep -iE "VGA"
```

Display detailed information about the selected device, including its related audio function.  
**Replace `2b:00`** with the PCI address **obtained above**.  
In the output, the **PCI IDs** are shown inside **latest square brackets** `[vendor:device]`.  
Record both the **GPU and audio PCI IDs**, for example:

- GPU: `10de:1b81`
- Audio: `10de:10f0`

```sh
$lspci -nn -s 2b:00
```

Create a configuration file for `modprobe` with the recorded **PCI IDs**.  
Replace `<GPU>` and `<AUDIO>` with the recorded **PCI IDs**:

```sh
$echo 'options vfio-pci ids=<GPU>,<AUDIO> disable_vga=1' > /etc/modprobe.d/vfio-gpu.conf
```

### // Setup vfio modprobe :: SAS

For passthrough of SAS controllers, the device must likewise be bound to the `vfio-pci` driver.  
This prevents the host from initializing it and makes it available for a virtual machine.

List all SAS controllers and identify the one to be assigned to a VM.  
The required **PCI ID** is shown inside **latest square brackets** `[vendor:device]`.  
Example output may include `1000:0097` for an LSI controller:

```sh
$lspci -nn | grep -iE "SAS"
```

Create a configuration file for `modprobe` with the recorded **PCI ID**.  
Replace `<PCI_ID>` with the recorded **PCI ID**:

```sh
$echo 'options vfio-pci ids=<PCI_ID>' > /etc/modprobe.d/vfio-sas.conf
```

### // Update and Reboot

> Updates the initramfs (initial RAM file system) for all installed kernels on your system,
> to ensures that the changes made to the configuration files are reflected in the initramfs

```sh
$update-initramfs -u -k all
$reboot
```

---

## \\\\ Additional Configurations

### // Create a Cloud-Init Template

> _Example for setup ubuntu-23.04 cloud-init template_
>
> > - NOTE: change **img** `noble-server-cloudimg-amd64.img` as you needed (also the url for download)
> > - NOTE: change **vm-id** `9999` as you needed
> > - NOTE: check **storage-name** `local-zfs` for your needs (maybe your's is local-lvm)

download the ubuntu-23.04 image:

```sh
$wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img \
-O /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img
```

verify the sha256 hash:

```sh
$cd /var/lib/vz/template/iso && \
curl -s https://cloud-images.ubuntu.com/noble/current/SHA256SUMS | \
grep "noble-server-cloudimg-amd64.img" | \
sha256sum -c - ; cd --
```

create a new VM:

```sh
$qm create 9999 --name "template-s-ubuntu-noble" --memory 2048 --net0 virtio,bridge=vmbr0 \
--cpu cputype=x86-64-v2-AES --sockets 1 --cores 2 --numa 0
```

add cloud img as drive or empty drive:

```sh
# import the downloaded disk to local-zfs storage
$qm importdisk 9999 /var/lib/vz/template/iso/noble-server-cloudimg-amd64.img local-zfs
# finally attach the new disk to the VM as scsi drive
$qm set 9999 --scsihw virtio-scsi-single --scsi0 local-zfs:vm-9999-disk-0,ssd=1,discard=on,iothread=1
```

setup additional VM properties:

```sh
# add cloud-init cd-rom drive
$qm set 9999 --balloon 0
$qm set 9999 --scsi2 local-zfs:cloudinit
$qm set 9999 --boot order='scsi0'
#$qm set 9999 --serial0 socket --vga serial0
$qm set 9999 --agent 1
$qm set 9999 --hotplug disk,network,usb
$qm set 9999 --bios ovmf
$qm set 9999 --efidisk0 local-zfs:0,efitype=4m,pre-enrolled-keys=0
$qm set 9999 --machine q35
$qm set 9999 --tablet 0
$qm set 9999 --ostype l26
```

cloud init custom config:

```sh
# add cloud init config to install guest agent on first start
$mkdir -p /var/lib/vz/snippets
$cat <<'EOF' >/var/lib/vz/snippets/ubuntu.yaml
#cloud-config
keyboard:
  layout: "de"
  variant: ""

runcmd:
    - apt update
    - apt install -y qemu-guest-agent
    - systemctl start qemu-guest-agent
EOF
$qm set 9999 --cicustom "vendor=local:snippets/ubuntu.yaml"
```

convert VM as template:

```sh
$qm template 9999
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
$wget https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso \
-O /var/lib/vz/template/iso/ubuntu-24.04.1-live-server-amd64.iso
```

verify the sha256 hash:

```sh
$cd /var/lib/vz/template/iso && \
curl -s https://releases.ubuntu.com/24.04/SHA256SUMS | \
grep "ubuntu-24.04.1-live-server-amd64.iso" | \
sha256sum -c - ; cd --
```

create a new VM:

```sh
$qm create 9998 --name "template-c-ubuntu-noble" --memory 2048 --net0 virtio,bridge=vmbr0 \
--cpu cputype=x86-64-v2-AES --sockets 1 --cores 2 --numa 0
```

add empty drive and iso:

```sh
$qm set 9998 --scsihw virtio-scsi-single --scsi0 local-zfs:32,ssd=1,discard=on,iothread=1
$qm set 9998 --scsi1 local-zfs:iso/ubuntu-24.04.1-live-server-amd64.iso,media=cdrom
```

setup additional VM properties:

```sh
# add cloud-init cd-rom drive
$qm set 9998 --balloon 0
$qm set 9998 --vga virtio
$qm set 9998 --agent 1
$qm set 9998 --hotplug disk,network,usb
$qm set 9998 --bios ovmf
$qm set 9998 --efidisk0 local-zfs:0,efitype=4m,pre-enrolled-keys=0
$qm set 9998 --machine q35
$qm set 9998 --tablet 0
$qm set 9998 --ostype l26
```

cloud init custom autoinstall config:

```sh
# add cloud init config to install guest agent and ubuntu client desktop on first start
$mkdir -p /var/lib/vz/snippets
$touch /var/lib/vz/snippets/meta-data
$cat <<'EOF' >/var/lib/vz/snippets/user-data
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
      # change afterwards with: `$sudo cryptsetup luksChangeKey /dev/... -S 0`
      password: <LUKS_PLAIN_PASSPHRASE>  # pragma: allowlist secret
  identity:
    hostname: EttNjUIgCrVStbNpGTmz
    username: groot
    # create with: `$mkpasswd -m sha-512`
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

```sh
$cd /var/lib/vz/snippets && \
mkisofs -input-charset 'utf-8' -V cidata -lJR -o /var/lib/vz/template/iso/cloud-init.iso user-data meta-data && \
cd --

$qm set 9998 --scsi2 local-zfs:iso/cloud-init.iso,media=cdrom
$qm set 9998 --boot order='scsi0;scsi1'
```

remove not needed sources after install finished:

```sh
$qm set 9998 --delete scsi1
$qm set 9998 --delete scsi2
```

after you not need anymore the installers remove them as credentials are else stored on server:

```sh
$rm /var/lib/vz/snippets/user-data
$rm /var/lib/vz/template/iso/cloud-init.iso
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
$qm rescan --vmid <VM-ID>
```

### // qm unlock

if vm is locked for example after an power outage

```sh
$qm unlock <VM-ID>
```

### // assign complete drivers to a VM

search for **disk-id**:

```sh
$lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,UUID --exclude 7
```

add **disk** to **vm**:

```sh
$qm set <VM-ID> -scsi<NUMBER> /dev/disk/by-id/<DISK-ID/UUID>
```

---

## \\\\ TODO later

### Base firewall rules

```sh
pvesh create cluster/firewall/rules --type in --action ACCEPT --proto tcp --dport 8006 --log nolog --enable 0
pvesh create cluster/firewall/rules --type in --action ACCEPT --proto tcp --dport 22 --log nolog --enable 0
```

---

## \\\\ Resources & More information's

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
