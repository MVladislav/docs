---
layout: post
title: OPNsense Setup
categories:
  - Infrastructure
  - OPNsense
tags:
  - security
  - hardening
  - linux
  - opnsense
  - firewall
image: /assets/img/headers/firewall.png
---

## \\\\ Information - OPNsense

OPNsense is a free and open-source firewall and routing platform based on FreeBSD.
It is designed to provide network security and services like VPN and DNS,
with a web-based graphical interface for easy configuration and management.

OPNsense offers a wide range of features and capabilities, such as:

- Firewall: Stateful packet filtering with support for NAT, port forwarding,
  and traffic shaping to block unwanted traffic and protect your network.
- VPN: OPNsense supports various VPN protocols, such as OpenVPN and IPsec,
  for secure remote access to the network.
- Intrusion Detection and Prevention System (IDPS): OPNsense includes Suricata,
  an open-source IDPS that can detect and prevent network intrusions.
- Web Filtering: OPNsense offers web filtering capabilities that can block access
  to specific websites and content categories. It also includes Sensei/ZenArmor:
  Optional add-ons that extend web filtering and security features with cloud-based
  threat intelligence and traffic analytics.
- DNS and DHCP: OPNsense can act as a DNS and DHCP server, providing these network services
  to devices on the network.
- High Availability: OPNsense supports high availability configurations,
  allowing for redundancy and failover in case of hardware or network failures.
- ZenArmor: ZenArmor is an add-on to OPNsense that provides advanced
  threat intelligence and security analytics capabilities.
  It uses machine learning algorithms to detect and prevent cyber attacks in real time.

OPNsense is typically used by organizations of all sizes to protect their networks and
ensure secure access to their resources. It is popular among IT professionals and
network administrators for its flexibility, ease of use, and community support.
With the addition of Sensei and ZenArmor, OPNsense provides even more
advanced security capabilities to protect against modern cyber threats.

---

> Before making any changes to software, systems, or devices,
> it's **important to thoroughly read and understand the configuration options**,
> and verify that the proposed changes align with your requirements.
> This can help avoid unintended consequences and ensure the software, system, or device operates as intended.
>
> ⚠️ A default OPNsense installation is functional but not hardened.  
> This guide helps you establish a **secure baseline configuration** before applying customizations.  
> {: .prompt-warning }

---

## \\\\ System > \*

### // Access

> Always create **individual admin accounts** and protect them with **TOTP**.  
> {: .prompt-tip }

1. Go to **System > Access > Servers** and create a new service for **TOTP**.
   - After creation, select it under **System > Settings > Administration > Authentication > Server**.
   - ![TOTP Service](/assets/img/posts/opnsense/TOTP_Service_1683906505312_0.png)
2. For each user, generate a seed under **OTP seed** and pair it with an authenticator app.

### // Firmware > Plugins

> Recommended plugins for a secure and manageable OPNsense setup.  
> {: .prompt-info }

- **[ZenArmor (formerly Sensei)](#-zenarmor--) `[RECOMMENDED]`** - Next-Generation Firewall
  - **os-sensei**
  - **os-sensei-updater**
  - **os-sunnyvalley**
- **os-q-feeds-connector `[RECOMMENDED]`** - Threat-Intel
- **[os-acme-client](#-acme) `[RECOMMENDED]`** - Valid TLS-Certificates.
- **[os-ddclient](#-dynamic-dns) `[OPTIONAL]`** - Dynamic DNS support.
- **os-qemu-guest-agent `[OPTIONAL]`** - For Proxmox/VM integration.
- **os-net-snmp `[OPTIONAL]`** - SNMP-Monitoring.
- **[os-theme-vicuna](#general) `[OPTIONAL]`** - Dark mode theme.
  > **!!!** Highly recommended to install for dark mode, **bugs love light** **!!!**  
  > {: .prompt-danger }

### // Gateways > Configuration

1. Configure the **WAN interface** first.
   > This is normally done during OPNsense installation.
2. For each gateway:
   - **Disable Gateway Monitoring:** _unchecked_
   - **Monitor IP:** `9.9.9.9` (Quad9) or your ISP gateway IP.
     - For IPv6: use `2620:fe::fe` or another reliable IPv6 address.

### // Settings \*

#### Administration

- **Web GUI**
  - Protocol: `HTTPS`
  - SSL Certificate: _needs to be created first as described in section [internal CA](#-trust--) or [ACME](#-acme)_
  - HTTP Strict Transport Security: _enabled_
  - Access Log: _enabled_
  - Server Log: _enabled_
  - Listen Interfaces: _Restrict to admin/management subnet_
- **Secure Shell**
  - Secure Shell Server: _Disabled by default (enable only if needed)_
  - Listen Interfaces: _Restrict to admin/management subnet_
- **Authentication**
  - Server: _Choose TOTP service ([Access](#-access))_

#### General

- Hostname: `opnsense` (or any name you prefer)
- Domain: `home.local` (or your own domain - _[internal CA](#-trust--) or [ACME](#-acme)_)
- Time zone: `Europe/Berlin`
- Theme: `vicuna`
  > **!!!** Highly recommended using dark mode, **bugs love light** **!!!**  
  > {: .prompt-danger }
- Prefer IPv4 over IPv6: _unchecked_
- DNS Servers: _leave empty; we will use Unbound_
- DNS Server Options: _both unchecked_
- Gateway Switching: _unchecked_

#### Logging

Adjust log retention and log level as needed. The defaults are usually sufficient.

![Logging Settings System](/assets/img/posts/opnsense/Logging_Settings_System_1683907923484_0.png)

#### Tunables

| Key                               | Value       | Description                                                             |
| :-------------------------------- | :---------- | :---------------------------------------------------------------------- |
| `hw.ibrs_disable`                 | `1`         | Disable Indirect Branch Restricted Speculation                          |
| `net.isr.maxthreads`              | `-1`        | Use at most this many CPUs for netisr processing                        |
| `net.isr.bindthreads`             | `1`         | Bind netisr threads to CPUs                                             |
| `net.isr.dispatch`                | `deferred`  | netisr dispatch policy                                                  |
| `net.inet.rss.enabled`            | `1`         | RSS enabled                                                             |
| `net.inet.rss.bits`               | `3`         | `<CORES>/4=<VALUE>` RSS bits                                            |
| `kern.ipc.maxsockbuf`             | `614400000` | `614400000=100Gbps` `16777216=10Gbps` Maximum socket buffer size        |
| `net.inet.tcp.recvbuf_max`        | `4194304`   | Max size of automatic receive buffer                                    |
| `net.inet.tcp.recvspace`          | `65536`     | Initial receive socket buffer size                                      |
| `net.inet.tcp.sendspace`          | `65536`     | Initial send socket buffer size                                         |
| `net.inet.tcp.sendbuf_inc`        | `65536`     | Incrementor step size of automatic send buffer                          |
| `net.inet.tcp.sendbuf_max`        | `4194304`   | Max size of automatic send buffer                                       |
| `net.inet.tcp.soreceive_stream`   | `1`         | Using soreceive_stream for TCP sockets                                  |
|                                   |             |                                                                         |
| `net.inet.tcp.mssdflt`            | `1240`      | Default TCP Maximum Segment Size                                        |
| `net.inet.tcp.abc_l_var`          | `52`        | Cap the max cwnd increment during slow-start to this number of segments |
| `net.inet.tcp.minmss`             | `536`       | Minimum TCP Maximum Segment Size                                        |
| `net.isr.defaultqlimit`           | `2048`      | Default netisr per-protocol, per-CPU queue limit if not set by protocol |
|                                   |             |                                                                         |
| `kern.random.fortuna.minpoolsize` | `128`       | Minimum pool size necessary to cause a reseed                           |
|                                   |             |                                                                         |
| `net.pf.source_nodes_hashsize`    | `1048576`   |                                                                         |
|                                   |             |                                                                         |
| `kern.hz`                         | `1000`      | Number of clock ticks per second (improve for shaper on vm's)           |

### // Trust > \*

#### Authorities

Create an **internal root CA** and an **intermediate CA** to sign internal certificates. (You can skip this part if you want to use [ACME](#-trust--) only.)

- **Root CA**: `internal-ca` (kept offline if possible)
  - ![Authorities Trust System :: Root CA](/assets/img/posts/opnsense/Authorities_Trust_System_1683909084329_0.png)
- **Intermediate CA**: `intermediate-ca` (used for daily certs)
  - ![Authorities Trust System :: Intermediate CA](/assets/img/posts/opnsense/Authorities_Trust_System_1683909045392_0.png)

#### Certificates

- For quick and unsigned certificate: generate an **OPNsense certificate** signed by your **intermediate CA**.
- For a signed certificate: use **os-acme-client ([ACME](#-trust--))** to issue a **valid, auto-renewed certificate** for the OPNsense GUI (e.g., `opnsense.example.com`).

![Certificates Trust System](/assets/img/posts/opnsense/Certificates_Trust_System_1683909316305_0.png)

## \\\\ Interfaces > \*

- **Assignments**
  - Assign your physical or virtual network ports as interfaces.
    > Rename interfaces to meaningful names like `WAN`, `LAN`, `DMZ`, or `MGMT` for easier management.  
    > {: .prompt-tip }
  - Edit your assigned interfaces (e.g., configure WAN as `PPPoE`).
    - ![7_WAN Interfaces](/assets/img/posts/opnsense/7_WAN_Interfaces_1684545473693_0.png)
- **Settings**
  - Disable most **hardware offload** options to avoid driver or stability issues.
  - ![Settings Interfaces](/assets/img/posts/opnsense/Settings_Interfaces_1683910123930_0.png)

## \\\\ Firewall > \*

### // Aliases > GeoIP settings

Add the following URL (replace `<LICENSE-KEY>`):

```plain
https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country-CSV&license_key=<LICENSE-KEY>&suffix=zip
```

### // Aliases > Aliases

| Type                | Name                       | Content                                                                                                                                                                                       | Description                                                                          | Statistics    | Refresh Frequency |
| ------------------- | -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------- | ----------------- |
| **Host(s)**         |                            |                                                                                                                                                                                               |                                                                                      |               |                   |
|                     | IP_S_DNS_NTP_INTERN        | `192.168.1.1, fd00:affe:affe:1::1`                                                                                                                                                            | IP: service internal DNS+NTP (IPv4+IPv6)                                             | **_checked_** |                   |
|                     | IP_S_MDNS_SSDP             | `ff02::fb, 224.0.0.251, 239.255.255.250`                                                                                                                                                      | IP: MDNS and SSDP hosts                                                              | **_checked_** |                   |
|                     | IP_S_PUBLIC_DNS            | `1.1.1.1, 8.8.8.8, 101.101.101.101`                                                                                                                                                           | IP: default public DNS servers                                                       | **_checked_** |                   |
| **Network(s)**      |                            |                                                                                                                                                                                               |                                                                                      |               |                   |
|                     | SUB_PRIV4                  | `10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16`                                                                                                                                                   | SUB: RFC1918 IPv4 private net                                                        | **_checked_** |                   |
|                     | SUB_SITE_MC                | `239.254.0.0/16`                                                                                                                                                                              | SUB: site-local multicast (RFC2365)                                                  | **_checked_** |                   |
|                     | SUB_PRIV_BOGON             | `10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8, 224.0.0.0/4, 255.255.255.255, fe80::/10, ::1/128, ff00::/8, fc00::/7, ff02::1, ff02::2, 2001:db8::/32, ::/128, 2002::/16, 3ffe::/16` | SUB: RFC1918 + Bogon + Local + Multicast + Additional (Unspecified, 6to4, Old 6bone) | **_checked_** |                   |
|                     | SUB_PRIV6                  | `fd00:affe:affe:0::0/48`                                                                                                                                                                      | SUB: RFC4193 IPv6 ULA                                                                | **_checked_** |                   |
|                     | SUB_MULTI_BROAD            | `ff00::/8, 224.0.0.0/4, 255.255.255.255, ff02::1, ff02::c, ff02::fb, ff02::1:2`                                                                                                               | SUB: multicast + broadcast (IPv4+IPv6)                                               | **_checked_** |                   |
|                     | SUB_GLOBAL6                | `2000::/3`                                                                                                                                                                                    | SUB: IPv6 global unicast                                                             | **_checked_** |                   |
|                     | SUB_RFC1918_IPV6_RIPE_2A00 | `2a00::/16`                                                                                                                                                                                   | SUB: RFC 1918 IPv6 - RIPE '2a00:' block                                              | **_checked_** |                   |
|                     | SUB_ULA6                   | `fd00::/8`                                                                                                                                                                                    | SUB: IPv6 unique local address                                                       | **_checked_** |                   |
|                     | SUB_LINK_LOCAL6            | `fe80::/10`                                                                                                                                                                                   | SUB: IPv6 link local                                                                 | **_checked_** |                   |
| **Port(s)**         |                            |                                                                                                                                                                                               |                                                                                      |               |                   |
|                     | PORT_DNS_BLOCK             | `53, 853, 2853, 9953`                                                                                                                                                                         | PORT: DNS block ports (for outside connections)                                      |               |                   |
| **URL Table (IPs)** |                            |                                                                                                                                                                                               |                                                                                      |               |                   |
|                     | URL_BLOCK_LIST             | `https://ipv64.net/blocklists/ipv64_blocklist_all.txt`                                                                                                                                        |                                                                                      | **_checked_** | `1D 0H`           |
| **GeoIP**           |                            |                                                                                                                                                                                               |                                                                                      |               |                   |
|                     | GEO_BLOCK_BAD              | **_Choose regions you want block_**                                                                                                                                                           | GEO: block bad countries                                                             | **_checked_** |                   |
|                     | GEO_ALLOW_VPN              | **_Choose regions you want allow_**                                                                                                                                                           | GEO: allow vpn access                                                                | **_checked_** |                   |

### // Groups

> Create groups as needed, e.g. default public net access groups.

| Name         | Sequence | (no) GUI groups | Members                                                | Description                      |
| ------------ | -------- | --------------- | ------------------------------------------------------ | -------------------------------- |
| G_PUB_NET4_D | `5`      | **_checked_**   | **_add interfaces which should have internet access_** | default public net access (IPv4) |
| G_PUB_NET6_D | `6`      | **_checked_**   | **_add interfaces which should have internet access_** | default public net access (IPv6) |

### // NAT > Destination NAT

> Forward NTP/DNS traffic to the firewall instead of blocking it.

| Description                              | Interface               | Version | Protocol  | Invert Source   | Source      | Invert Destination | Destination           | Destination Port | Redirect target IP    | Redirect Target Port | Log           | Filter rule association |
| ---------------------------------------- | ----------------------- | ------- | --------- | --------------- | ----------- | ------------------ | --------------------- | ---------------- | --------------------- | -------------------- | ------------- | ----------------------- |
| PF:: forward NTP to local Service [IPv4] | **_select interfaces_** | `IPv4`  | `UDP`     | **_unchecked_** | `SUB_PRIV4` | **_checked_**      | `IP_S_DNS_NTP_INTERN` | `123`            | `IP_S_DNS_NTP_INTERN` | `123`                | **_checked_** | `Manual`                |
| PF:: forward NTP to local Service [IPv6] | **_select interfaces_** | `IPv6`  | `UDP`     | **_unchecked_** | **any**     | **_checked_**      | `IP_S_DNS_NTP_INTERN` | `123`            | `IP_S_DNS_NTP_INTERN` | `123`                | **_checked_** | `Manual`                |
| PF:: forward DNS to local Service [IPv4] | `G_PUB_NET4_D`          | `IPv4`  | `TCP/UDP` | **_unchecked_** | `SUB_PRIV4` | **_checked_**      | `IP_S_DNS_NTP_INTERN` | `53`             | `IP_S_DNS_NTP_INTERN` | `53`                 | **_checked_** | `Manual`                |
| PF:: forward DNS to local Service [IPv6] | `G_PUB_NET6_D`          | `IPv6`  | `TCP/UDP` | **_unchecked_** | **any**     | **_checked_**      | `IP_S_DNS_NTP_INTERN` | `53`             | `IP_S_DNS_NTP_INTERN` | `53`                 | **_checked_** | `Manual`                |

### // Rules

#### Floating

| Description                                           | Interface  | Quick           | Action  | Direction | Version | Protocol  | Invert Source   | Source                                             | Invert Destination | Destination                                  | Destination Port | Log             |
| ----------------------------------------------------- | ---------- | --------------- | ------- | --------- | ------- | --------- | --------------- | -------------------------------------------------- | ------------------ | -------------------------------------------- | ---------------- | --------------- |
| BLOCK:: F: restrict access by bad block list (out)    | **_none_** | **_checked_**   | `Block` | `in`      | **any** | **any**   | **_unchecked_** | **any**                                            | **_unchecked_**    | `URL_BLOCK_LIST`                             | **any**          | **_checked_**   |
| BLOCK:: F: restrict access by bad geo countries (out) | **_none_** | **_checked_**   | `Block` | `in`      | **any** | **any**   | **_unchecked_** | **any**                                            | **_unchecked_**    | `GEO_BLOCK_BAD`                              | **any**          | **_checked_**   |
| BLOCK:: F: restrict access by qfeeds list (out)       | **_none_** | **_checked_**   | `Block` | `in`      | **any** | **any**   | **_unchecked_** | **any**                                            | **_unchecked_**    | `__qfeeds_malware_ip`                        | **any**          | **_checked_**   |
| ALLOW:: F: NTP internal access                        | **_none_** | **_checked_**   | `Pass`  | `in`      | **any** | `UDP`     | **_unchecked_** | `SUB_PRIV4, SUB_PRIV6, SUB_RFC1918_IPV6_RIPE_2A00` | **_unchecked_**    | `IP_S_DNS_NTP_INTERN`                        | `123`            | **_checked_**   |
| ALLOW:: F: MLD internal access                        | **_none_** | **_checked_**   | `Pass`  | `in`      | `IPv6`  | `ICMP`    | **_unchecked_** | `SUB_LINK_LOCAL6`                                  | **_unchecked_**    | `ff02::16/128`                               | **any**          | **_checked_**   |
| BLOCK:: F: no rule wan [IPv4]                         | **_none_** | **_unchecked_** | `Block` | `in`      | `IPv4`  | **any**   | **_unchecked_** | **any**                                            | **_unchecked_**    | **any**                                      | **any**          | **_checked_**   |
| BLOCK:: F: no rule local [IPv4]                       | **_none_** | **_unchecked_** | `Block` | `in`      | `IPv4`  | **any**   | **_unchecked_** | **any**                                            | **_unchecked_**    | `SUB_PRIV_BOGON, SUB_MULTI_BROAD`            | **any**          | **_checked_**   |
| BLOCK:: F: no rule wan [IPv6]                         | **_none_** | **_unchecked_** | `Block` | `in`      | `IPv6`  | **any**   | **_unchecked_** | **any**                                            | **_unchecked_**    | **any**                                      | **any**          | **_checked_**   |
| BLOCK:: F: no rule local [IPv6]                       | **_none_** | **_unchecked_** | `Block` | `in`      | `IPv6`  | **any**   | **_unchecked_** | **any**                                            | **_unchecked_**    | `SUB_PRIV_BOGON, SUB_MULTI_BROAD, SUB_PRIV6` | **any**          | **_checked_**   |
| BLOCK:: F: DoT (flooding)                             | **_none_** | **_checked_**   | `Block` | `in`      | **any** | `TCP/UDP` | **_unchecked_** | `SUB_PRIV_BOGON`                                   | **_unchecked_**    | **any**                                      | `853`            | **_unchecked_** |
| BLOCK:: F: IGMP access (flooding)                     | **_none_** | **_unchecked_** | `Block` | `in`      | **any** | `IGMP`    | **_unchecked_** | **any**                                            | **_unchecked_**    | `SUB_MULTI_BROAD`                            | **any**          | **_unchecked_** |
| BLOCK:: F: SSDP on port 1900 (flooding)               | **_none_** | **_unchecked_** | `Block` | `in`      | **any** | `TCP/UDP` | **_unchecked_** | `SUB_PRIV_BOGON`                                   | **_unchecked_**    | `SUB_MULTI_BROAD`                            | `1900`           | **_unchecked_** |
| BLOCK:: F: DDDP on port 9131 (flooding)               | **_none_** | **_unchecked_** | `Block` | `in`      | **any** | `TCP/UDP` | **_unchecked_** | `SUB_PRIV_BOGON`                                   | **_unchecked_**    | `SUB_MULTI_BROAD`                            | `9131`           | **_unchecked_** |
| BLOCK:: F: WS-Discovery on port 3702 (flooding)       | **_none_** | **_unchecked_** | `Block` | `in`      | **any** | `TCP/UDP` | **_unchecked_** | `SUB_PRIV_BOGON`                                   | **_unchecked_**    | `SUB_MULTI_BROAD`                            | `3702`           | **_unchecked_** |
| BLOCK:: F: MDNS on port 5353 (flooding)               | **_none_** | **_unchecked_** | `Block` | `in`      | **any** | `TCP/UDP` | **_unchecked_** | `SUB_PRIV_BOGON`                                   | **_unchecked_**    | `SUB_MULTI_BROAD`                            | `5353`           | **_unchecked_** |
| BLOCK:: F: MDNS on port 5355 (flooding)               | **_none_** | **_unchecked_** | `Block` | `in`      | **any** | `TCP/UDP` | **_unchecked_** | `SUB_PRIV_BOGON`                                   | **_unchecked_**    | `SUB_MULTI_BROAD`                            | `5355`           | **_unchecked_** |
| BLOCK:: F: NetBIOS on port 137-139 (flooding)         | **_none_** | **_unchecked_** | `Block` | `in`      | **any** | `TCP/UDP` | **_unchecked_** | `SUB_PRIV_BOGON`                                   | **_unchecked_**    | `SUB_MULTI_BROAD`                            | `137-139`        | **_unchecked_** |

#### 00_WAN

| Description                                            | Interface | Quick         | Action  | Direction | Version | Protocol | Invert Source   | Source                | Invert Destination | Destination | Destination Port | Log           |
| ------------------------------------------------------ | --------- | ------------- | ------- | --------- | ------- | -------- | --------------- | --------------------- | ------------------ | ----------- | ---------------- | ------------- |
| BLOCK:: WAN: restrict access by bad block list (in)    | `00_WAN`  | **_checked_** | `Block` | `in`      | **any** | **any**  | **_unchecked_** | `URL_BLOCK_LIST`      | **_unchecked_**    | **any**     | **any**          | **_checked_** |
| BLOCK:: WAN: restrict access by bad geo countries (in) | `00_WAN`  | **_checked_** | `Block` | `in`      | **any** | **any**  | **_unchecked_** | `GEO_BLOCK_BAD`       | **_unchecked_**    | **any**     | **any**          | **_checked_** |
| BLOCK:: WAN: restrict access by qfeeds list (in)       | `00_WAN`  | **_checked_** | `Block` | `in`      | **any** | **any**  | **_unchecked_** | `__qfeeds_malware_ip` | **_unchecked_**    | **any**     | **any**          | **_checked_** |
| BLOCK:: WAN: no rule [IPv4]                            | `00_WAN`  | **_checked_** | `Block` | `in`      | `IPv4`  | **any**  | **_unchecked_** | **any**               | **_unchecked_**    | **any**     | **any**          | **_checked_** |
| BLOCK:: WAN: no rule [IPv6]                            | `00_WAN`  | **_checked_** | `Block` | `in`      | `IPv6`  | **any**  | **_unchecked_** | **any**               | **_unchecked_**    | **any**     | **any**          | **_checked_** |

#### G_PUB_NET4_D

| Description                              | Interface      | Quick         | Action  | Direction | Version | Protocol  | Invert Source   | Source         | Invert Destination | Destination           | Destination Port | Log           |
| ---------------------------------------- | -------------- | ------------- | ------- | --------- | ------- | --------- | --------------- | -------------- | ------------------ | --------------------- | ---------------- | ------------- |
| BLOCK:: GPN4D: DNS (outside) [IPv4+IPv6] | `G_PUB_NET4_D` | **_checked_** | `Block` | `in`      | **any** | `TCP/UDP` | **_unchecked_** | **any**        | **_checked_**      | `IP_S_DNS_NTP_INTERN` | `PORT_DNS_BLOCK` | **_checked_** |
| ALLOW:: GPN4D: DNS (inside) [IPv4+IPv6]  | `G_PUB_NET4_D` | **_checked_** | `Pass`  | `in`      | **any** | `TCP/UDP` | **_unchecked_** | `G_PUB_NET4_D` | **_unchecked_**    | `IP_S_DNS_NTP_INTERN` | `53`             | **_checked_** |
| ALLOW:: GPN4D: internet [IPv4]           | `G_PUB_NET4_D` | **_checked_** | `Pass`  | `in`      | `IPv4`  | **any**   | **_unchecked_** | `G_PUB_NET4_D` | **_checked_**      | `SUB_PRIV_BOGON`      | **any**          | **_checked_** |

#### G_PUB_NET6_D

| Description                              | Interface      | Quick         | Action  | Direction | Version | Protocol  | Invert Source   | Source         | Invert Destination | Destination           | Destination Port | Log           |
| ---------------------------------------- | -------------- | ------------- | ------- | --------- | ------- | --------- | --------------- | -------------- | ------------------ | --------------------- | ---------------- | ------------- |
| BLOCK:: GPN6D: DNS (outside) [IPv4+IPv6] | `G_PUB_NET6_D` | **_checked_** | `Block` | `in`      | **any** | `TCP/UDP` | **_unchecked_** | **any**        | **_checked_**      | `IP_S_DNS_NTP_INTERN` | `PORT_DNS_BLOCK` | **_checked_** |
| ALLOW:: GPN6D: DNS (inside) [IPv4+IPv6]  | `G_PUB_NET6_D` | **_checked_** | `Pass`  | `in`      | **any** | `TCP/UDP` | **_unchecked_** | `G_PUB_NET6_D` | **_unchecked_**    | `IP_S_DNS_NTP_INTERN` | `53`             | **_checked_** |
| ALLOW:: GPN6D: internet [IPv6]           | `G_PUB_NET6_D` | **_checked_** | `Pass`  | `in`      | `IPv6`  | **any**   | **_unchecked_** | `G_PUB_NET6_D` | **_checked_**      | `SUB_PRIV_BOGON`      | **any**          | **_checked_** |

### // Shaper

| direction          | config           | value                                                        |
| :----------------- | :--------------- | :----------------------------------------------------------- |
| **down :: Pipes**  | Bandwidth        | `XY Mbit/s`                                                  |
|                    | Queue            | _empty_                                                      |
|                    | Mask             | `none`                                                       |
|                    | Scheduler type   | `FlowQueue-CoDel`                                            |
|                    | (FQ-)CoDel ECN   | _checked_                                                    |
|                    | FQ-CoDel quantum | `300*(<Bandwidth>/100) = X` or `1514` _(Default)_ or _empty_ |
|                    | FQ-CoDel limit   | `1000`                                                       |
|                    | Description      | `WAN-Download-Pipe`                                          |
| **down :: Queues** | Pipe             | `WAN-Download-Pipe`                                          |
|                    | Weight           | `100`                                                        |
|                    | mask             | `none`                                                       |
|                    | (FQ-)CoDel ECN   | _unchecked_                                                  |
|                    | Description      | `WAN-Download-Queue`                                         |
| **down :: Rules**  | Sequence         | `5`                                                          |
|                    | Interface        | `00_WAN`                                                     |
|                    | Protocol         | `ip`                                                         |
|                    | Source           | `any`                                                        |
|                    | Src-port         | `any`                                                        |
|                    | Destination      | `any` or `192.168.0.0/16 2000::/3`                           |
|                    | Dst-port         | `any`                                                        |
|                    | Direction        | `in`                                                         |
|                    | Target           | `WAN-Download-Queue`                                         |
|                    | Description      | `WAN-Download-Rule`                                          |
| **up :: Pipes**    | Bandwidth        | `XY Mbit/s`                                                  |
|                    | Queue            | _empty_                                                      |
|                    | Mask             | `none`                                                       |
|                    | Scheduler type   | `FlowQueue-CoDel`                                            |
|                    | (FQ-)CoDel ECN   | _checked_                                                    |
|                    | FQ-CoDel quantum | `300*(<Bandwidth>/100) = X` or `1514`_(Default)_ or _empty_  |
|                    | FQ-CoDel limit   | `1000`                                                       |
|                    | Description      | `WAN-Upload-Pipe`                                            |
| **up :: Queues**   | Pipe             | `WAN-Upload-Pipe`                                            |
|                    | Weight           | `100`                                                        |
|                    | mask             | `none`                                                       |
|                    | (FQ-)CoDel ECN   | _unchecked_                                                  |
|                    | Description      | `WAN-Upload-Queue`                                           |
| **up :: Rules**    | Sequence         | `6`                                                          |
|                    | Interface        | `00_WAN`                                                     |
|                    | Protocol         | `ip`                                                         |
|                    | Source           | `any` or `192.168.0.0/16 2000::/3`                           |
|                    | Src-port         | `any`                                                        |
|                    | Destination      | `any`                                                        |
|                    | Dst-port         | `any`                                                        |
|                    | Direction        | `out`                                                        |
|                    | Target           | `WAN-Upload-Queue`                                           |
|                    | Description      | `WAN-Upload-Rule`                                            |

### // Settings > Advanced

| Section            | Key                   | Value                                                                                   |
| :----------------- | :-------------------- | :-------------------------------------------------------------------------------------- |
| **Bogon Networks** | Update Frequency      | `Weekly`                                                                                |
| **Logging**        | Default block         | _checked_                                                                               |
|                    | Default pass          | _checked_                                                                               |
|                    | Outbound NAT          | _checked_                                                                               |
|                    | Bogon networks        | _checked_                                                                               |
|                    | Private networks      | _checked_                                                                               |
| **Miscellaneous**  | Firewall Optimization | `conservative`                                                                          |
|                    | Disable anti-lockout  | _checked_ (_Only when you created relevant firewall rules, else you will lock you out_) |
|                    | Disable sshlockout    | _checked_ (_Only when you created relevant firewall rules, else you will lock you out_) |

## \\\\ Services > \*

### // Dnsmasq DNS & DHCP

> Verify `ISC DHCPv4/6` and `Kea DHCP` are **not auto-enabled** before configuration.  
> {: .prompt-info }

#### General

| Section                     | Key                                          | Value                                              |
| :-------------------------- | :------------------------------------------- | :------------------------------------------------- |
| **Default**                 | Enable                                       | _checked_                                          |
|                             | Interface                                    | _Select all interfaces where you want enable DHCP_ |
| **DNS**                     | Listen port                                  | `53053`                                            |
|                             | DNSSEC                                       | _unchecked_                                        |
|                             | No hosts lookup                              | _unchecked_                                        |
| **DNS Query Forwarding**    | Query DNS servers sequentially               | _unchecked_                                        |
|                             | Require domain                               | _unchecked_                                        |
|                             | Do not forward to system defined DNS servers | _checked_                                          |
|                             | Do not forward private reverse lookups       | _checked_                                          |
| **DHCP**                    | DHCP FQDN                                    | _checked_                                          |
|                             | DHCP default domain                          | _empty_                                            |
|                             | DHCP local domain                            | _checked_                                          |
|                             | DHCP authoritative                           | _checked_                                          |
|                             | DHCP reply delay                             | _empty_                                            |
|                             | DHCP register firewall rules                 | _checked_                                          |
|                             | Router advertisements                        | _checked_                                          |
|                             | Disable HA sync                              | _unchecked_                                        |
| **ISC / KEA DHCP (legacy)** | Register ISC DHCP4 leases                    | _unchecked_                                        |
|                             | DHCP domain override                         | _empty_                                            |
|                             | Register DHCP static mappings                | _unchecked_                                        |
|                             | Prefer DHCP                                  | _unchecked_                                        |

#### DHCP ranges

> Define your required DHCP ranges for the subnets you created in **[Interfaces](#-interfaces--)**.  
> {: .prompt-info }

#### DHCP options

> Remember we defined the **DNS server** under **[Aliases](#-aliases--aliases)** with the alias `IP_S_DNS_NTP_INTERN`.  
> {: .prompt-info }

| Entry (Description) | Key       | Value                   |
| :------------------ | :-------- | :---------------------- |
| Default DNS [IPv4]  | Interface | `Any`                   |
|                     | Type      | `Set`                   |
|                     | Option    | `dns-server [6]`        |
|                     | Option6   | _none_                  |
|                     | Value     | `192.168.1.1`           |
| Default DNS [IPv6]  | Interface | `Any`                   |
|                     | Type      | `Set`                   |
|                     | Option    | _none_                  |
|                     | Option6   | `dns-server [23]`       |
|                     | Value     | `[fd00:affe:affe:1::1]` |

### // Unbound DNS

#### General

| Key                                           | Value         |
| :-------------------------------------------- | :------------ |
| **Enable Unbound**                            | _checked_     |
| Listen Port                                   | `53`          |
| Network Interfaces                            | `All`         |
| Enable DNSSEC Support                         | _unchecked_   |
| Enable DNS64 Support                          | _unchecked_   |
| DNS64 Prefix                                  | _none_        |
| Enable AAAA-only mode                         | _unchecked_   |
| Register ISC DHCP4 Leases                     | _unchecked_   |
| DHCP Domain Override                          | _none_        |
| **Register DHCP Static Mappings**             | _checked_     |
| **Do not register IPv6 Link-Local addresses** | _checked_     |
| **Do not register system A/AAAA records**     | _checked_     |
| TXT Comment Support                           | _unchecked_   |
| **Flush DNS Cache during reload**             | _checked_     |
| Local Zone Type                               | `transparent` |
| Outgoing Network Interfaces                   | `00_WAN`      |

#### Query Forwarding

> Example with `home.local` when used as [internal domain](#general),  
> plus `example.com` when set up with [ACME](#-acme).  
> {: .prompt-info }

| Entry (Description)      | Key           | Value                  |
| :----------------------- | :------------ | :--------------------- |
| **Dnsmasq (local)**      | Enabled       | _checked_              |
|                          | Domain        | `home.local`           |
|                          | Server IP     | `127.0.0.1`            |
|                          | Server Port   | `53053`                |
|                          | Forward first | _unchecked_            |
| **Dnsmasq rev. (local)** | Enabled       | _checked_              |
|                          | Domain        | `168.192.in-addr.arpa` |
|                          | Server IP     | `127.0.0.1`            |
|                          | Server Port   | `53053`                |
|                          | Forward first | _unchecked_            |
| **Dnsmasq (pub.)**       | Enabled       | _checked_              |
|                          | Domain        | `example.com`          |
|                          | Server IP     | `127.0.0.1`            |
|                          | Server Port   | `53053`                |
|                          | Forward first | _checked_              |

#### Advanced

| Section                    | Key                                          | Value                          |
| :------------------------- | :------------------------------------------- | :----------------------------- |
| **General Settings**       | Hide Identity                                | _checked_                      |
|                            | Hide Version                                 | _checked_                      |
|                            | Prefetch DNS Key Support                     | _checked_                      |
|                            | Harden DNSSEC Data                           | _checked_                      |
|                            | Aggressive NSEC                              | _checked_                      |
|                            | Strict QNAME Minimisation                    |                                |
|                            | Outgoing TCP Buffers                         | `32`                           |
|                            | Incoming TCP Buffers                         | `64`                           |
|                            | Number of queries per thread                 | `512`                          |
|                            | Outgoing Range                               | `1024`                         |
|                            | Jostle Timeout                               | `200`                          |
|                            | Discard Timeout                              | `4000`                         |
|                            | Private Domains                              | `home.local,local,example.com` |
| **Serve Expired Settings** | Serve Expired Responses                      | _checked_                      |
|                            | Expired Record Reply TTL value               | _none_                         |
|                            | TTL for Expired Responses                    | _none_                         |
|                            | Reset Expired Record TTL                     | _unchecked_                    |
|                            | Client Expired Response Timeout              | _none_                         |
| **Logging Settings**       | Extended Statistics                          | _checked_                      |
|                            | Log Queries                                  | _unchecked_                    |
|                            | Log Replies                                  | _unchecked_                    |
|                            | Tag Queries and Replies                      | _unchecked_                    |
|                            | Log local actions                            | _unchecked_                    |
|                            | Log SERVFAIL                                 | _checked_                      |
|                            | Log Level Verbosity                          | `Level 1`                      |
|                            | Log validation level                         | `Level 0`                      |
| **Cache Settings**         | Prefetch Support                             | _checked_                      |
|                            | Unwanted Reply Threshold                     | _none_                         |
|                            | Message Cache Size                           | `50m`                          |
|                            | RRset Cache Size                             | `100m`                         |
|                            | Maximum TTL for RRsets and messages          | `86400`                        |
|                            | Maximum Negative TTL for RRsets and messages | `300`                          |
|                            | Minimum TTL for RRsets and messages          | `60`                           |
|                            | TTL for Host Cache entries                   | `900`                          |
|                            | Keep probing down hosts                      | _checked_                      |
|                            | Number of Hosts to cache                     | `2000`                         |

#### DNS over TLS

Use System Nameservers: **_unchecked_**

| Server IP      | Server Port | Verify CN     | Description                                                 |
| -------------- | ----------- | ------------- | ----------------------------------------------------------- |
| 9.9.9.10       | 853         | dns.quad9.net | QUAD9::Unsecured: No Malware blocking, no DNSSEC validation |
| 149.112.112.10 | 853         | dns.quad9.net | QUAD9::Unsecured: No Malware blocking, no DNSSEC validation |
| 2620:fe::10    | 853         | dns.quad9.net | QUAD9::Unsecured: No Malware blocking, no DNSSEC validation |
| 2620:fe::fe:10 | 853         | dns.quad9.net | QUAD9::Unsecured: No Malware blocking, no DNSSEC validation |

### // ACME

#### Settings

| Key           | Value     |
| :------------ | :-------- |
| Enable Plugin | _checked_ |
| Auto Renewal  | _checked_ |

#### Accounts

Let's Encrypt:

| Key            | Value                                    |
| :------------- | :--------------------------------------- |
| Enabled        | _checked_                                |
| Name           | `LEv2-Stage`                             |
| Description    | `Let's Encrypt - Staging (testing only)` |
| E-Mail Address | _add your email address_                 |
| ACME CA        | `Let's Encrypt Test CA`                  |

| Key            | Value                                  |
| :------------- | :------------------------------------- |
| Enabled        | _checked_                              |
| Name           | `LEv2`                                 |
| Description    | `Let's Encrypt - Production (default)` |
| E-Mail Address | _add your email address_               |
| ACME CA        | `Let's Encrypt [default]`              |

#### Challenge Types

IONOS:

| Key            | Value                                                                         |
| :------------- | :---------------------------------------------------------------------------- |
| Enabled        | _checked_                                                                     |
| Name           | `IONOS`                                                                       |
| Challenge Type | `DNS-01`                                                                      |
| DNS Service    | `IONOS domain`                                                                |
| DNS Sleep Time | `0`                                                                           |
| Prefix         | _create key at <https://developer.hosting.ionos.de/keys> ("Präfix")_          |
| Secret         | _create key at <https://developer.hosting.ionos.de/keys> ("Verschlüsselung")_ |

#### Automation

| Key         | Value                     |
| :---------- | :------------------------ |
| Enabled     | _checked_                 |
| Name        | `Restart OPNsense Web UI` |
| Run Command | `Restart OPNsense Web UI` |

#### Certificates

| Key            | Value                                      |
| :------------- | :----------------------------------------- |
| Enabled        | _checked_                                  |
| Common Name    | _your domain, e.g. `opnsense.example.com`_ |
| ACME Account   | `LEv2-Stage` (testing) / `LEv2` (prod)     |
| Challenge Type | `IONOS`                                    |
| Auto Renewal   | _checked_                                  |
| Key Length     | `ec-256`                                   |
| Automations    | `Restart OPNsense Web UI`                  |
| DNS Alias Mode | `Not using DNS alias mode`                 |

### // Dynamic DNS

#### Settings

Ionos Example [IPv6]:

> Replace `<IONOS_TOKEN>`

| Key                  | Value                                                                       |
| :------------------- | :-------------------------------------------------------------------------- |
| Enabled              | _checked_                                                                   |
| Description          | `IONOS IPv6`                                                                |
| Service              | `custom`                                                                    |
| Protocol             | `Custom GET`                                                                |
| Server               | `https://api.hosting.ionos.com/dns/v1/dyndns?q=<IONOS_TOKEN>&ipv6=__MYIP__` |
| Hostname(s)          | _full domain name (e.g. dyn.example.com)_                                   |
| Check ip method      | `Interface [IPv6]`                                                          |
| Interface to monitor | `00_WAN`                                                                    |
| Force SSL            | _checked_                                                                   |

Ionos Example [IPv4]:

> Replace `<IONOS_TOKEN>`

| Key                  | Value                                                         |
| :------------------- | :------------------------------------------------------------ |
| Enabled              | _checked_                                                     |
| Description          | `IONOS IPv4`                                                  |
| Service              | `custom`                                                      |
| Protocol             | `Custom GET`                                                  |
| Server               | `https://api.hosting.ionos.com/dns/v1/dyndns?q=<IONOS_TOKEN>` |
| Hostname(s)          | _full domain name (e.g. dyn.example.com)_                     |
| Check ip method      | `ipify-ipv4`                                                  |
| Interface to monitor | `00_WAN`                                                      |
| Force SSL            | _checked_                                                     |

#### General Settings

- Enable: **_checked_**
- Interval: **`300`**

### // Intrusion Detection

#### Settings

| Section          | Key                      | Value       |
| :--------------- | :----------------------- | :---------- |
| General Settings | Enabled                  | _checked_   |
|                  | IPS mode                 | _unchecked_ |
|                  | Promiscuous mode         | _checked_   |
|                  | Interfaces               | `00_WAN`    |
| Detection        | Pattern matcher          | `Hyperscan` |
| Logging          | Enable syslog alerts     | _checked_   |
|                  | Enable eve syslog output | _checked_   |
|                  | Rotate log               | `Weekly`    |
|                  | Save logs                | `4`         |

> IPS mode requires netmap support and may affect performance. Enable only if needed.  
> {: .prompt-warning }

#### Download

- Select **all** and click **Download & Update Rules**
- Select **all** and click **Enable selected**

#### Schedule

![Cron Settings System](/assets/img/posts/opnsense/Cron_Settings_System_1683913306303_0.png)

### // Monit

#### General Settings

Add your information and credentials.

#### Alert Settings

Create a new entry. Below is an example mail format to be added.

Mail format ([info](https://mmonit.com/monit/documentation/monit.html#Message-format)):

> Update `monit <no-reply@DOMAIN>` in **from** to your needs.

```yaml
from: monit <no-reply@DOMAIN>
subject: $SERVICE $EVENT at $DATE
message: Monit $ACTION $SERVICE at $DATE on $HOST:
  $DESCRIPTION

Yours sincerely,
Monit
```

## \\\\ Zenarmor > \*

### // Policies (Default)

#### Security

![Policies Zenarmor](/assets/img/posts/opnsense/Policies_Zenarmor_1683914462056_0.png)

#### App Controls

- Cloud Services
  - Apple Cloud
- Conferencing
  - Google Hangouts Meet
- Gaming
  - Facebook Games
  - Fortnite
  - Fortnite Tracker
  - Microsoft Xbox
  - Roblox Game
  - Samsung Games
- Instant Messaging
  - Facebook Chat
  - Facebook Messenger
  - Facebook Video call
  - Google Chat
  - Google Hangouts
- Media Streaming
  - Apple\*
- Mobile Applications
  - Amazon Firestick TV
- News
  - Apple News
  - Bild.de
- Online Shopping
  - Apple Appstore
  - Apple Store
  - Microsoft Wallet
- Online Utility
  - Apple\*
  - Microsoft Cortana
  - Microsoft MSDN
  - Microsoft Weather
  - Pivotal Tracker
- Proxy
  - iCloud Private Relay
- Remote Access
  - all except
    - Microsoft Continuum
    - Secure Shell
    - Teamviewer
- Search
  - Microsoft Bing
- Social Network
  - Facebook\*
  - Google\*
  - facebook.comment
  - facebook.statusUpdate
- Software Updates
  - Apple Pipeline
  - Apple Telemetry
  - Intel Telemetry
  - Malwarebytes Telemetry
  - Microsoft Telemetry
  - Mozilla Telemetry
  - Windows Problem Reporting
- Storage & Backup
  - all except
    - Google Drive
    - Microsoft OneDrive
- VOIP
  - Facebook Call

![Policies Zenarmor](/assets/img/posts/opnsense/Policies_Zenarmor_1683915468914_0.png)

#### Web Controls

![Policies Zenarmor](/assets/img/posts/opnsense/Policies_Zenarmor_1683914518793_0.png)

### // Configuration > \*

#### General

- choose: **Routed Mode (L3 Mode, Reporting + Blocking) with native netmap driver**
- select your **Interfaces Selection**
- define your needs for **Deployment**
- set your needs for **Logger**

#### Cloud Threat Intel

- Local Domains Name To Exclude From Cloud Queries: **`home.local,local`**

#### Updates & Health

- Help Sunny Valley Networks improve its products and services by sharing health and system utilization statistics: **unchecked**

#### Reporting & Data

- set your needs for **Reports Data Management**
- activate **Scheduled Reports** if needed

#### Privacy

![Configuration Zenarmor](/assets/img/posts/opnsense/Configuration_Zenarmor_1683914355203_0.png)

---

## \\\\ Resources & More information

- <https://docs.opnsense.org/>{:target="\_blank"}
- <https://en.wikipedia.org/wiki/Private_network>{:target="\_blank"}
- <https://ipgeolocation.io/resources/bogon.html>{:target="\_blank"}
- <https://forum.opnsense.org/index.php?PHPSESSID=ahi5e19a2tl303rir594sgmn88&topic=27394.msg160740#msg160740>{:target="\_blank"}
- tunings
  - <https://docs.opnsense.org/troubleshooting/performance.html>{:target="\_blank"}
  - <https://teklager.se/en/knowledge-base/opnsense-performance-optimization>{:target="\_blank"}
  - <https://binaryimpulse.com/2022/11/opnsense-performance-tuning-for-multi-gigabit-internet>{:target="\_blank"}
  - <https://www.reddit.com/r/OPNsenseFirewall/comments/b2uhpw/performance_tuning_help>{:target="\_blank"}
  - <https://calomel.org/freebsd_network_tuning.html>{:target="\_blank"}
  - <https://docs.opnsense.org/troubleshooting/performance.html>{:target="\_blank"}
  - <https://www.reddit.com/r/opnsense/comments/14li2c7/10gbps_speed/>{:target="\_blank"}
  - <https://www.reddit.com/r/opnsense/comments/17fjbbw/opnsense_on_proxmox_10gb_network_woes/>{:target="\_blank"}
  - <https://forum.opnsense.org/index.php?topic=31830.0>{:target="\_blank"}
  - <https://forum.opnsense.org/index.php?topic=18754.150>{:target="\_blank"}
  - <https://medium.com/@truvis.thornton/opnsense-firewall-configuration-performance-tuning-for-multi-gigabit-internet-and-better-speeds-in-cfc80c49c544>{:target="\_blank"}
  - <https://docs.opnsense.org/manual/shaping.html>{:target="\_blank"}
