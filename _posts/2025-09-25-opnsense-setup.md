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

- **[ZenArmor (formerly Sensei)](#-zenarmor--):**
  - **os-sensei**
  - **os-sensei-updater**
  - **os-sunnyvalley**
- **[os-ddclient](#-dynamic-dns)** - Dynamic DNS support.
- **[os-acme-client](#-acme)** - Recommended for valid TLS certificates.
- **os-net-snmp** - For SNMP monitoring.
- **os-qemu-guest-agent** - For Proxmox/VM integration.
- **[os-theme-vicuna](#general)** - Dark mode theme.
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

- Type: **Host(s)**
  - IP_S_DNS_NTP_INTERN
    - Content: **`192.168.1.1,fd00:affe:affe:1::1`**
      > Example IPs for default DNS and NTP used in this documentation and allowed internal rules.
    - Statistics: **_checked_**
    - Description: **IP: service internal DNS+NTP (IPv4+IPv6)**
  - IP_S_MDNS_SSDP
    - Content: **`ff02::fb,224.0.0.251,239.255.255.250`**
    - Statistics: **_checked_**
    - Description: **IP: mDNS and SSDP hosts**
- Type: **Network(s)**
  - SUB_MULTI_BROAD
    - Content: **`ff00::/8,224.0.0.0/4,255.255.255.255,ff02::1,ff02::c,ff02::fb,ff02::1:2`**
    - Statistics: **_checked_**
    - Description: **SUB: multicast + broadcast (IPv4+IPv6)**
  - SUB_PRIV4
    - Content: **`10.0.0.0/8,172.16.0.0/12,192.168.0.0/16`**
    - Statistics: **_checked_**
    - Description: **SUB: RFC1918 IPv4 private net**
  - SUB_PRIV6
    - Content: **`fd00:affe:affe:0::0/48`**
      > Example IPv6 ULA, adjust to your own range.
    - Statistics: **_checked_**
    - Description: **SUB: RFC4193 IPv6 ULA**
  - SUB_PRIV_BOGON
    - Content: **`10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.0/8,224.0.0.0/4,255.255.255.255,fe80::/10,::1/128,ff00::/8,fc00::/7,ff02::1,ff02::2,2001:db8::/32,::/128,2002::/16,3ffe::/16`**
    - Statistics: **_checked_**
    - Description: **SUB: RFC1918+Bogon+Local+Multicast+Additional**
  - SUB_LINK_LOCAL6
    - Content: **`fe80::/10`**
    - Statistics: **_checked_**
    - Description: **SUB: IPv6 link local**
  - SUB_SITE_MC
    - Content: **`239.254.0.0/16`**
    - Statistics: **_checked_**
    - Description: **SUB: site-local multicast (RFC2365)**
  - SUB_GLOBAL6
    - Content: **`2000::/3`**
    - Statistics: **_checked_**
    - Description: **SUB: IPv6 global unicast**
  - SUB_ULA6
    - Content: **`fd00::/8`**
    - Statistics: **_checked_**
    - Description: **SUB: IPv6 unique local address**
- Type: **URL Table (IPs)**
  - URL_BLOCKLIST
    - Content: **`https://ipv64.net/blocklists/ipv64_blocklist_all.txt`**
    - Statistics: **_checked_**
- Type: **Port(s)**
  - PORT_DNS_BLOCK
    - Content: **`53,853,2853,5355,9953`**
    - Description: **PORT: DNS block ports**
  - PORT_LB_NOLOG
    - Content: **`53,2055,9200`**
    - Description: **PORT: loopback no-log**
  - PORT_S_MDNS
    - Content: **`5353,5540`**
    - Description: **PORT: mDNS (IoT/Thread)**
  - PORT_S_SIP
    - Content: **`3478,3479,5060,7078:7109,10000:30000`**
    - Description: **PORT: SIP service**

### // Groups

> Create groups as needed, e.g. default public net access groups.

- Name: **G_PUB_NET4_D**
  - Description: **default public net access [IPv4]**
  - Members: **_add interfaces which should have internet access_**
  - Sequence: `5`
  - (no) GUI groups: **_checked_**
- Name: **G_PUB_NET6_D**
  - Description: **default public net access [IPv6]**
  - Members: **_add interfaces which should have internet access_**
  - Sequence: `6`
  - (no) GUI groups: **_checked_**

### // NAT > Port Forward

> Forward NTP/DNS traffic to the firewall instead of blocking it.

- Description: **PF:: forward NTP to local [IPv4]**
  - Interface: **_select interfaces_**
  - TCP/IP Version: **IPv4**
  - Protocol: **UDP**
  - Source / Invert: **_unchecked_**
  - Source: **SUB_PRIV4**
  - Destination / Invert: **_checked_**
  - Destination: **IP_S_DNS_NTP_INTERN**
  - Destination port range: **123**
  - Redirect target IP: **IP_S_DNS_NTP_INTERN**
  - Log: **_checked_**
  - Filter rule association: **None**
- Description: **PF:: forward NTP to local [IPv6]**
  - Interface: **_select interfaces_**
  - TCP/IP Version: **IPv6**
  - Protocol: **UDP**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_checked_**
  - Destination: **IP_S_DNS_NTP_INTERN**
  - Destination port range: **123**
  - Redirect target IP: **IP_S_DNS_NTP_INTERN**
  - Log: **_checked_**
  - Filter rule association: **None**
- Description: **PF:: forward DNS to local [IPv4]**
  - Interface: **G_PUB_NET4_D**
  - TCP/IP Version: **IPv4**
  - Protocol: **TCP/UDP**
  - Source / Invert: **_unchecked_**
  - Source: **SUB_PRIV4**
  - Destination / Invert: **_checked_**
  - Destination: **IP_S_DNS_NTP_INTERN**
  - Destination port range: **53**
  - Redirect target IP: **IP_S_DNS_NTP_INTERN**
  - Log: **_checked_**
  - Filter rule association: **None**
- Description: **PF:: forward DNS to local [IPv6]**
  - Interface: **G_PUB_NET6_D**
  - TCP/IP Version: **IPv6**
  - Protocol: **TCP/UDP**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_checked_**
  - Destination: **IP_S_DNS_NTP_INTERN**
  - Destination port range: **53**
  - Redirect target IP: **IP_S_DNS_NTP_INTERN**
  - Log: **_checked_**
  - Filter rule association: **None**

### // Rules

#### Floating

- Description: **ALLOW:: F: NTP internal [IPv4+IPv6]**
  - Action: **Pass**
  - Quick: **_checked_**
  - Interface: **none**
  - Direction: **in**
  - TCP/IP Version: **IPv4+IPv6**
  - Protocol: **UDP**
  - Source / Invert: **_unchecked_**
  - Source: **SUB_PRIV4, SUB_PRIV6**
  - Destination / Invert: **_unchecked_**
  - Destination: **IP_S_DNS_NTP_INTERN**
  - Destination port range: **123**
  - Log: **_checked_**
- Description: **ALLOW:: F: mDNS [IPv4+IPv6]**
  - Action: **Pass**
  - Quick: **_checked_**
  - Interface: **none**
  - Direction: **in**
  - TCP/IP Version: **IPv4+IPv6**
  - Protocol: **UDP**
  - Source / Invert: **_unchecked_**
  - Source: **SUB_PRIV4, SUB_PRIV6, SUB_LINK_LOCAL6**
  - Destination / Invert: **_unchecked_**
  - Destination: **IP_S_MDNS_SSDP**
  - Destination port range: **5353**
  - Log: **_checked_**
- Description: **ALLOW:: F: MLD internal [IPv6]**
  - Action: **Pass**
  - Quick: **_checked_**
  - Interface: **none**
  - Direction: **in**
  - TCP/IP Version: **IPv6**
  - Protocol: **ICMP**
  - Source / Invert: **_unchecked_**
  - Source: **fe80::/10**
  - Destination / Invert: **_unchecked_**
  - Destination: **ff02::16/128**
  - Log: **_checked_**
- Description: **BLOCK:: F: DNS outside [IPv4+IPv6]**
  - Action: **Block**
  - Quick: **_checked_**
  - Interface: **none**
  - Direction: **in**
  - TCP/IP Version: **IPv4+IPv6**
  - Protocol: **TCP/UDP**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_checked_**
  - Destination: **IP_S_DNS_NTP_INTERN**
  - Destination port range: **PORT_DNS_BLOCK**
  - Log: **_checked_**
- Description: **BLOCK:: F: no rule WAN [IPv4]**
  - Action: **Block**
  - Quick: **_unchecked_**
  - Interface: **none**
  - Direction: **in**
  - TCP/IP Version: **IPv4**
  - Protocol: **any**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_unchecked_**
  - Destination: **any**
  - Log: **_checked_**
- Description: **BLOCK:: F: no rule local [IPv4]**
  - Action: **Block**
  - Quick: **_unchecked_**
  - Interface: **none**
  - Direction: **in**
  - TCP/IP Version: **IPv4**
  - Protocol: **any**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_unchecked_**
  - Destination: **SUB_PRIV_BOGON, SUB_MULTI_BROAD**
  - Log: **_checked_**
- Description: **BLOCK:: F: no rule WAN [IPv6]**
  - Action: **Block**
  - Quick: **_unchecked_**
  - Interface: **none**
  - Direction: **in**
  - TCP/IP Version: **IPv6**
  - Protocol: **any**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_unchecked_**
  - Destination: **any**
  - Log: **_checked_**
- Description: **BLOCK:: F: no rule local [IPv6]**
  - Action: **Block**
  - Quick: **_unchecked_**
  - Interface: **none**
  - Direction: **in**
  - TCP/IP Version: **IPv6**
  - Protocol: **any**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_unchecked_**
  - Destination: **SUB_PRIV_BOGON, SUB_MULTI_BROAD, SUB_PRIV6**
  - Log: **_checked_**

#### 00_WAN

- Description: **BLOCK:: WAN: blocklist (in)**
  - Action: **Block**
  - Quick: **_checked_**
  - Interface: **00_WAN**
  - Direction: **in**
  - TCP/IP Version: **IPv4+IPv6**
  - Protocol: **any**
  - Source / Invert: **_unchecked_**
  - Source: **URL_BLOCKLIST**
  - Destination / Invert: **_unchecked_**
  - Destination: **any**
  - Log: **_checked_**
- Description: **BLOCK:: WAN: no rule [IPv4]**
  - Action: **Block**
  - Quick: **_checked_**
  - Interface: **00_WAN**
  - Direction: **in**
  - TCP/IP Version: **IPv4**
  - Protocol: **any**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_unchecked_**
  - Destination: **any**
  - Log: **_checked_**
- Description: **BLOCK:: WAN: no rule [IPv6]**
  - Action: **Block**
  - Quick: **_checked_**
  - Interface: **00_WAN**
  - Direction: **in**
  - TCP/IP Version: **IPv6**
  - Protocol: **any**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_unchecked_**
  - Destination: **any**
  - Log: **_checked_**

#### G_PUB_NET4_D

- Description: **BLOCK:: GPN4D: DNS outside [IPv4+IPv6]**
  - Action: **Block**
  - Quick: **_checked_**
  - Interface: **G_PUB_NET4_D**
  - Direction: **in**
  - TCP/IP Version: **IPv4+IPv6**
  - Protocol: **TCP/UDP**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_checked_**
  - Destination: **IP_S_DNS_NTP_INTERN**
  - Destination port range: **PORT_DNS_BLOCK**
  - Log: **_checked_**
- Description: **ALLOW:: GPN4D: DNS inside [IPv4+IPv6]**
  - Action: **Pass**
  - Quick: **_checked_**
  - Interface: **G_PUB_NET4_D**
  - Direction: **in**
  - TCP/IP Version: **IPv4+IPv6**
  - Protocol: **TCP/UDP**
  - Source / Invert: **_unchecked_**
  - Source: **G_PUB_NET4_D net**
  - Destination / Invert: **_unchecked_**
  - Destination: **IP_S_DNS_NTP_INTERN**
  - Destination port range: **53**
  - Log: **_checked_**
- Description: **ALLOW:: GPN4D: internet [IPv4]**
  - Action: **Pass**
  - Quick: **_checked_**
  - Interface: **G_PUB_NET4_D**
  - Direction: **in**
  - TCP/IP Version: **IPv4**
  - Protocol: **any**
  - Source / Invert: **_unchecked_**
  - Source: **G_PUB_NET4_D net**
  - Destination / Invert: **_checked_**
  - Destination: **SUB_PRIV_BOGON**
  - Log: **_checked_**

#### G_PUB_NET6_D

- Description: **BLOCK:: GPN6D: DNS outside [IPv4+IPv6]**
  - Action: **Block**
  - Quick: **_checked_**
  - Interface: **G_PUB_NET6_D**
  - Direction: **in**
  - TCP/IP Version: **IPv4+IPv6**
  - Protocol: **TCP/UDP**
  - Source / Invert: **_unchecked_**
  - Source: **any**
  - Destination / Invert: **_checked_**
  - Destination: **IP_S_DNS_NTP_INTERN**
  - Destination port range: **PORT_DNS_BLOCK**
  - Log: **_checked_**
- Description: **ALLOW:: GPN6D: DNS inside [IPv4+IPv6]**
  - Action: **Pass**
  - Quick: **_checked_**
  - Interface: **G_PUB_NET6_D**
  - Direction: **in**
  - TCP/IP Version: **IPv4+IPv6**
  - Protocol: **TCP/UDP**
  - Source / Invert: **_unchecked_**
  - Source: **G_PUB_NET6_D net**
  - Destination / Invert: **_unchecked_**
  - Destination: **IP_S_DNS_NTP_INTERN**
  - Destination port range: **53**
  - Log: **_checked_**
- Description: **ALLOW:: GPN6D: internet [IPv6]**
  - Action: **Pass**
  - Quick: **_checked_**
  - Interface: **G_PUB_NET6_D**
  - Direction: **in**
  - TCP/IP Version: **IPv6**
  - Protocol: **any**
  - Source / Invert: **_unchecked_**
  - Source: **G_PUB_NET6_D net**
  - Destination / Invert: **_checked_**
  - Destination: **SUB_PRIV_BOGON**
  - Log: **_checked_**

#### LOOPBACK

- Description: **ALLOW:: LB:: 9200**
  - Action: **Pass**
  - Quick: **_checked_**
  - Interface: **Loopback**
  - Direction: **out**
  - TCP/IP Version: **IPv4**
  - Protocol: **TCP/UDP**
  - Source / Invert: **_unchecked_**
  - Source: **127.0.0.1/32**
  - Destination / Invert: **_unchecked_**
  - Destination: **127.0.0.1/32**
  - Destination port range: **PORT_LB_NOLOG**
  - Log: **_unchecked_**

### // Shaper

| direction          | config           | value                                            |
| :----------------- | :--------------- | :----------------------------------------------- |
| **down :: Pipes**  | Bandwidth        | `XY Mbit/s`                                      |
|                    | Queue            | `2`                                              |
|                    | Scheduler type   | `FlowQueue-CoDel`                                |
|                    | (FQ-)CoDel ECN   | _checked_                                        |
|                    | FQ-CoDel quantum | `300*(<Bandwidth>/100) = X` or `1514`            |
|                    | Description      | `WAN-Download-Pipe`                              |
| **down :: Queues** | Pipe             | `WAN-Download-Pipe`                              |
|                    | Weight           | `100`                                            |
|                    | mask             | `destination`                                    |
|                    | (FQ-)CoDel ECN   | _checked_                                        |
|                    | Description      | `WAN-Download-Queue`                             |
| **down :: Rules**  | Sequence         | `2`                                              |
|                    | Interface        | `00_WAN`                                         |
|                    | Protocol         | `ip`                                             |
|                    | Source           | `any`                                            |
|                    | Src-port         | `any`                                            |
|                    | Destination      | `any`                                            |
|                    | Dst-port         | `any`                                            |
|                    | Direction        | `in`                                             |
|                    | Target           | `WAN-Download-Queue`                             |
|                    | Description      | `WAN-Download-Rule`                              |
| **up :: Pipes**    | Bandwidth        | `XY Mbit/s`                                      |
|                    | Queue            | _empty_                                          |
|                    | Scheduler type   | `FlowQueue-CoDel`                                |
|                    | (FQ-)CoDel ECN   | _checked_                                        |
|                    | FQ-CoDel quantum | `300*(<Bandwidth>/100) = X` or `1514` or _empty_ |
|                    | Description      | `WAN-Upload-Pipe`                                |
| **up :: Queues**   | Pipe             | `WAN-Upload-Pipe`                                |
|                    | Weight           | `100`                                            |
|                    | mask             | `source`                                         |
|                    | (FQ-)CoDel ECN   | _checked_                                        |
|                    | Description      | `WAN-Upload-Queue`                               |
| **up :: Rules**    | Sequence         | `2`                                              |
|                    | Interface        | `00_WAN`                                         |
|                    | Protocol         | `ip`                                             |
|                    | Source           | `any`                                            |
|                    | Src-port         | `any`                                            |
|                    | Destination      | `any`                                            |
|                    | Dst-port         | `any`                                            |
|                    | Direction        | `out`                                            |
|                    | Target           | `WAN-Upload-Queue`                               |
|                    | Description      | `WAN-Upload-Rule`                                |

### // Settings > Advanced

| Section            | Key                  | Value                                                                                   |
| :----------------- | :------------------- | :-------------------------------------------------------------------------------------- |
| **Bogon Networks** | Update Frequency     | `Weekly`                                                                                |
| **Logging**        | Default block        | _checked_                                                                               |
|                    | Default pass         | _checked_                                                                               |
|                    | Outbound NAT         | _checked_                                                                               |
|                    | Bogon networks       | _checked_                                                                               |
|                    | Private networks     | _checked_                                                                               |
| **Miscellaneous**  | Disable anti-lockout | _checked_ (_Only when you created relevant firewall rules, else you will lock you out_) |
|                    |                      |                                                                                         |
|                    |                      |                                                                                         |
|                    |                      |                                                                                         |

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
|                             | Do not forward private reverse lookups       | _unchecked_                                        |
| **DHCP**                    | DHCP FQDN                                    | _checked_                                          |
|                             | DHCP default domain                          | _empty_                                            |
|                             | DHCP local domain                            | _checked_                                          |
|                             | DHCP authoritative                           | _unchecked_                                        |
|                             | DHCP reply delay                             | _unchecked_                                        |
|                             | DHCP register firewall rules                 | _checked_                                          |
|                             | Router advertisements                        | _unchecked_                                        |
|                             | Disable HA sync                              | _unchecked_                                        |
| **ISC / KEA DHCP (legacy)** | Register ISC DHCP4 leases                    | _unchecked_                                        |
|                             | DHCP domain override                         | _unchecked_                                        |
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
