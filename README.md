<div align="center">

<img src="docs/moncastle-logo.svg" alt="RoboMate MonCastle" width="300">

### Every server, service and signal in one console.

Inventory, monitoring, auditing and remediation for Active Directory, Windows, Linux, virtualization,
network, databases, containers and the cloud, all from one web console you host yourself.

![Version](https://img.shields.io/badge/version-4.7.4-1A84D2)
![Platform](https://img.shields.io/badge/server-Windows%20Server%202019%2B%20%7C%20Windows%2010%2F11-0A467B)
![PowerShell](https://img.shields.io/badge/PowerShell-7-0A7D97)
![Themes](https://img.shields.io/badge/UI-light%20%7C%20dark%20%7C%20mobile-12C08F)

[Highlights](#highlights) · [What's new](#whats-new-in-474) · [Tour](#a-tour-of-the-console) ·
[Features](#features) · [Getting started](#getting-started) · [Security](#security-and-privacy) · [FAQ](#faq)

<br>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/overview-dark.png">
  <img src="docs/screenshots/overview.png" alt="MonCastle overview: resources, health by category, fleet compute and what needs attention" width="100%">
</picture>

</div>

---

## Why MonCastle

Most IT teams juggle one tool for monitoring, another for inventory, a third for AD auditing and a pile of
scripts for everything else. **RoboMate MonCastle brings them together.** It discovers what you run, watches it
around the clock, tells you what needs attention and why, and lets you fix it from the same page, with every
change recorded.

- **See everything.** One console for domain controllers, file and print servers, Hyper-V and VMware, SQL and 97
  other database engines, switches and firewalls, Linux, Kubernetes, Entra ID, Intune and cloud networks.
- **Know what matters.** Clear Up / Warning / Down states, alarms with the reason and a suggested next step, and
  dashboards that open on the problem rather than the noise.
- **Act safely.** Built-in actions and scheduled jobs with role-based permissions, WhatIf previews and
  typed confirmation for anything risky.
- **Stay in control.** Self-hosted on your own Windows server. Your data stays on your network, encrypted at rest.

## Highlights

| | |
|---|---|
| 🧭 **Unified overview** | 460+ resources in 8 categories at a glance, with the problems that need attention first. |
| 📡 **Sensor-based monitoring** | Probe › groups › devices › sensors › channels, with limits, graphs, uptime and alarms. |
| 🔍 **Auto-discovery** | Finds hosts on your networks and from AD, Intune and Entra ID, and detects each device's type and group. |
| 🧩 **Monitoring profiles** | Bundle sensors, options and actions for a device type and apply them to groups or devices in one step. |
| 🛡️ **Security and compliance** | Defender, patching, exposure, local admins and checks against CIS, NIST, ISO 27001, PCI DSS, HIPAA and more. |
| ⚙️ **66 monitoring engines** | Collectors that run on your schedule, only for the targets you choose, with full run details. |
| ⚡ **Actions and jobs** | 40+ ready-made actions plus remote scripting, run now or on a schedule. |
| 📊 **Dashboards and reports** | Built-in dashboards for every area, your own dashboards, and reports you can save, share and export. |
| 🌗 **Light, dark and mobile** | A modern interface that follows your theme and works on a phone. |

## What's new in 4.7.4

- **Engines start only when you say so.** No monitoring engine runs until you choose what it reads: all devices of
  its type, some groups, single devices or the engine's own scope. Each engine shows *Not configured* until then.
- **Engine credentials per device or group.** Give an engine its own account for one device or a whole group.
- **Run details and My jobs.** See every engine run (when, who started it, rows read, unreachable hosts, errors) and
  find all the jobs you started under **Actions › My jobs**, with the full result, log and **Run again**.
- **Monitoring profiles.** Define sensors, limits, options and actions once per device type and assign them to
  groups or devices. Sensors are added and removed automatically as assignments change.
- **Devices in several groups.** A device keeps a primary group and can belong to others. Views, permissions,
  credentials and jobs count every group.
- **Smarter auto-discovery.** Found hosts are classified from SNMP, operating system, open ports, web banners,
  certificates and name hints, so servers, workstations, DCs, Linux, switches, firewalls, printers, storage, cameras
  and phones land in the right place.
- **Software inventory** for Windows servers, workstations and Linux (package manager, snap and flatpak).
- **Web servers, all of them.** IIS, Apache, nginx, Tomcat, WildFly, WebLogic, HAProxy, Traefik, Envoy, Kestrel,
  Node.js and many more, on Windows and Linux.
- **Every database engine.** 97 engines in 13 categories, from relational and data warehouse to document,
  time series, graph and vector, each with an availability check and a deeper read where a client or driver exists.

<details>
<summary><b>Earlier releases (4.7.0 to 4.7.3)</b></summary>

- **4.7.3:** SMTP *Security* setting with automatic STARTTLS / SSL detection, a dedicated Databases view, the Network
  view organised by device type, and one Web servers view for every web server on Windows and Linux.
- **4.7.2:** more discovery sources (AD, Intune, Entra ID), no duplicate sensors, Linux file systems and audit, SSL
  certificates, hardware temperature, containers and Kubernetes, cloud firewalls, WAF and VPN, Entra ID and Intune.
- **4.7.1:** automatic script sync, per-engine requirements, per-device access levels (Monitor only, Read,
  Administrator), engine targets, and one-click remote control over RDP, SSH or HTTPS.
- **4.7.0:** remote scripting, "found by engine" versus "manually added", a combined Windows overview, OpenShift and
  Nutanix, AD reports with tiering, and inventory and map views for added devices.

</details>

---

## A tour of the console

### Monitor

<table>
<tr>
<td width="50%"><img src="docs/screenshots/devices-and-sensors.png" alt="Devices and sensors tree"><br><b>Devices & sensors.</b> Every device with a coloured chip per sensor, filters by state, tree or tiles.</td>
<td width="50%"><img src="docs/screenshots/device-page.png" alt="Device page"><br><b>Device page.</b> Sensors, inventory, live view, troubleshooting, remote control and actions in one place.</td>
</tr>
<tr>
<td><img src="docs/screenshots/alarms.png" alt="Alarms"><br><b>Alarms.</b> Everything Down or Warning, grouped by family and longest open, with Investigate and Acknowledge.</td>
<td><img src="docs/screenshots/dashboards.png" alt="Dashboards"><br><b>Dashboards.</b> Built-in NOC, server, network and security dashboards, or build your own.</td>
</tr>
</table>

### Configure

<table>
<tr>
<td width="50%"><img src="docs/screenshots/auto-discovery.png" alt="Auto-discovery"><br><b>Auto-discovery.</b> Scan your networks and custom ranges; each candidate shows what it was detected from.</td>
<td width="50%"><img src="docs/screenshots/monitoring-profiles.png" alt="Monitoring profiles"><br><b>Monitoring profiles.</b> Start from a device type, pick sensors and actions, and assign to groups or devices.</td>
</tr>
<tr>
<td><img src="docs/screenshots/monitoring-engines.png" alt="Monitoring engines"><br><b>Monitoring engines.</b> Engine states by category, targets, schedule and run history.</td>
<td><img src="docs/screenshots/remote-scripting.png" alt="Remote scripting"><br><b>Remote scripting.</b> Run PowerShell, Bash or Python on chosen devices with a dry-run option.</td>
</tr>
</table>

### Infrastructure views

<table>
<tr>
<td width="50%"><img src="docs/screenshots/active-directory.png" alt="Active Directory"><br><b>Active Directory.</b> DCs, replication matrix, sites, AD services, DNS, DHCP, file and print, CA and IIS.</td>
<td width="50%"><img src="docs/screenshots/virtualization.png" alt="Virtualization"><br><b>Virtualization.</b> Hyper-V, VMware vSphere, OpenShift Virtualization and Nutanix with host capacity and clusters.</td>
</tr>
<tr>
<td><img src="docs/screenshots/network.png" alt="Network"><br><b>Network.</b> Switches, routers, firewalls, WAF, VPN, wireless and load balancers, each in its own tab.</td>
<td><img src="docs/screenshots/databases.png" alt="Databases"><br><b>Databases.</b> SQL Server and 97 engines by category, with backups, endpoints and cloud databases.</td>
</tr>
<tr>
<td><img src="docs/screenshots/web-servers.png" alt="Web servers"><br><b>Web servers.</b> Every web, application and proxy server, sites and URLs, IIS pools and certificates.</td>
<td><img src="docs/screenshots/containers-kubernetes.png" alt="Containers and Kubernetes"><br><b>Containers & Kubernetes.</b> Clusters, nodes, workloads, failing pods, Docker and Podman hosts.</td>
</tr>
<tr>
<td><img src="docs/screenshots/entra-intune.png" alt="Entra ID and Intune"><br><b>Entra ID & Intune.</b> Users, MFA, risky sign-ins, licences, app secrets and managed devices.</td>
<td><img src="docs/screenshots/security.png" alt="Security"><br><b>Security.</b> Defender health, patching, exposure, local admins, file share permissions and findings.</td>
</tr>
</table>

### Inventory and governance

<table>
<tr>
<td width="50%"><img src="docs/screenshots/inventory.png" alt="Inventory"><br><b>Inventory.</b> Every resource with vendor, model, OS, serial and software, filterable and exportable.</td>
<td width="50%"><img src="docs/screenshots/resource-map.png" alt="Resource map"><br><b>Resource map.</b> All resources grouped by role, site or status and coloured by health.</td>
</tr>
<tr>
<td><img src="docs/screenshots/compliance.png" alt="Compliance"><br><b>Compliance.</b> Scores per standard and device, with the controls that fail and why.</td>
<td><img src="docs/screenshots/reports.png" alt="Reports"><br><b>Reports.</b> Ready-made reports for every area and your own, printable and exportable.</td>
</tr>
</table>

### Works on your phone

<p align="center"><img src="docs/screenshots/phone.png" alt="MonCastle on a phone" width="520"></p>

---

## Features

### Monitoring
- Sensor model with channels, warning and error limits, live / 2-day / 30-day graphs, uptime and state log.
- Probe sensors: ping, TCP port, HTTP(S) with keyword, DNS, SSL certificate expiry, SNMP v1/v2c/v3, interface traffic,
  custom OID and PowerShell script.
- Engine sensors for CPU, memory, disks, services, event logs, updates, Defender, firewall, AD, DNS, DHCP, file and
  print servers, Hyper-V, VMware, clusters, SQL Server, Linux, web servers, databases, containers and cloud.
- Pause, acknowledge with a note, scan now, and bulk changes across devices.
- Receive alerts from Prometheus Alertmanager, Grafana, Zabbix, Nagios / Icinga, PRTG, SolarWinds, Datadog, Azure
  Monitor, AWS CloudWatch, SCOM, LibreNMS, Elastic or any JSON webhook.

### Coverage
- **Identity:** Active Directory (DCs, replication, sites, services, Group Policy, accounts, security events, tiering
  reports), Certificate Authority, NPS, Entra ID and Intune.
- **Windows:** servers and workstations, roles and features, IIS, RDS, WSUS, file servers and DFS, print servers.
- **Virtualization:** Hyper-V, VMware vSphere, failover clusters and CSVs, OpenShift Virtualization, Nutanix.
- **Network:** switches, routers, firewalls, WAF, VPN, wireless controllers and access points, load balancers, plus
  cloud firewalls, WAF and VPN on Azure, AWS, Google Cloud, Oracle Cloud and Huawei Cloud.
- **Storage:** SAN, NAS, Fibre Channel switches, backup appliances and cloud storage buckets.
- **Linux:** hardware, file systems, services, audit, updates and software over SSH.
- **Databases:** 97 engines in 13 categories, including SQL Server, Oracle, PostgreSQL, MySQL, MariaDB, MongoDB,
  Redis, Elasticsearch, Cassandra, ClickHouse, Neo4j, Db2, SAP HANA and cloud databases.
- **Containers:** Kubernetes clusters, nodes, workloads and pods, Docker and Podman hosts.
- **Power and hardware:** UPS, PDUs, environment sensors, iDRAC / iLO / XCC / IPMI, temperature.

### Inventory
- Hardware and software inventory for Windows and Linux, joined with what monitoring knows.
- OS update tracking against the latest release and support end of every Windows and Linux version.
- Bulk device import from CSV, with a check before anything is added and duplicates skipped.

### Actions and automation
- Actions by environment: AD accounts and groups, replication sync, Group Policy refresh, client maintenance,
  services and processes, Windows Update, firewall rules, Defender scans, Wake-on-LAN, network config backup, switch
  ports, Linux updates and services, VM control, storage snapshots, Kubernetes and cloud network actions.
- Scheduled jobs on devices, groups or everything that matches, with WhatIf, run-as credentials and failure alerts.
- Remote scripting in PowerShell, Bash or Python with a script library and dry run.
- Remote control in one click over RDP, SSH or the device's web interface.

### Notifications and reporting
- Notification rules by state, group and delay, sent by e-mail, Microsoft Teams, Slack or webhook, with templates.
- Built-in dashboards for Operations, Servers, Storage, Network, Active Directory, Security, Virtualization, Linux,
  Workstations, Printers and SQL, plus your own.
- Report builder with filters, grouping, charts, saved and shared reports, CSV and print to PDF.
- Compliance checks for CIS Controls v8, CIS benchmarks, NIST SP 800-53, NIST CSF 2.0, ISO 27001, PCI DSS 4.0,
  HIPAA, SOC 2, Essential Eight and GDPR Article 32.

### Administration
- Users with Reader, Contributor and Administrator roles, user groups that grant roles on device groups, and
  restricted users who only see their groups.
- Per-device access levels: Monitor only, Read, or Administrator.
- Several MonCastle servers: remote servers at branch offices probe locally and report to one central console.
- Data retention per sensor with encrypted, browsable archives.
- Automatic updates of the console and its scripts.

---

## Getting started

### Requirements

| | |
|---|---|
| **Console server** | Windows Server 2019 or later, or Windows 10 / 11 |
| **Runtime** | Included in the release package (no separate Node.js or .NET install) |
| **PowerShell** | PowerShell 7 |
| **Optional modules** | RSAT (AD, DNS, DHCP, Group Policy, Hyper-V, Failover Clustering), dbatools, VMware PowerCLI, database clients |
| **Browser** | Any current Edge, Chrome, Firefox or Safari, on desktop or phone |
| **Licence** | A MonCastle licence key |

The setup app checks what is already installed and offers to add what is missing.

### Install

1. Download the latest release package from [Releases](../../releases) and unzip it.
2. Run **MonCastle-Setup.exe** as administrator and follow the wizard:
   - choose the install folder and port (default **5050**);
   - pick the prerequisites to install;
   - choose the service account (LocalSystem, a gMSA or a named account) and whether this is a standalone or
     additional MonCastle server;
   - set the administrator recovery password and enter your licence key.
3. When setup finishes, open **https://robomatemoncastle:5050** and sign in.

> **Other PCs on your network** need to resolve the name too. Add a DNS A record `robomatemoncastle` that points to
> the console server, and make sure TCP 5050 is allowed inbound (setup adds the firewall rule on the server).

Prefer to try it first? `launcher\Start-MonCastle-Demo.cmd` opens the console with generated sample data, no licence
or PowerShell needed.

### First steps

1. **Add credentials** under *Configure › Credentials* (Windows, SSH, SNMP, VMware, database, cloud).
2. **Discover devices** under *Configure › Auto-discovery*, or import them from CSV.
3. **Apply a monitoring profile** to your groups under *Configure › Monitoring profiles*.
4. **Configure the engines** you need under *Actions › Monitoring engines* and choose their targets.
5. **Set up notifications** under *Configure › Notifications* so the right people hear about problems.

### Updating

MonCastle checks for new versions automatically. An administrator installs an update from
*Administrate › Updates & releases*; the current version is backed up first, and your data and settings are kept.

---

## Security and privacy

- **Self-hosted.** The console and all monitoring data stay on your own server and network.
- **HTTPS by default** on the console port, with your own certificate or one MonCastle creates and trusts for you.
- **Encrypted at rest.** Monitoring data, settings, history and credentials are stored with AES-256-GCM.
- **Secrets stay secret.** Device credentials are never sent to the browser, not even to administrators, and are
  never written to logs.
- **Least privilege.** Role-based access, per-device access levels and restricted users. Risky actions require an
  administrator, a typed confirmation, and preview first.
- **Verified scripts.** Only scripts from the verified catalogue run, each checked against its SHA-256 fingerprint before every run,
  with validated parameters.
- **Full audit trail.** Every sign-in, change, action and run is logged.

---

## FAQ

<details>
<summary><b>Do I need agents on my servers?</b></summary>

No. MonCastle reads Windows over WinRM / WMI, Linux over SSH, network and storage devices over SNMP or their REST
APIs, and cloud services through their APIs, using the credentials you provide.
</details>

<details>
<summary><b>Does monitoring stop when I close the browser?</b></summary>

No. The console runs as a Windows service and the engines run as scheduled tasks, so monitoring continues around the
clock.
</details>

<details>
<summary><b>Can I monitor branch offices or isolated networks?</b></summary>

Yes. Install an additional MonCastle server at the site and join it to your central console. It probes local devices
and reports back, and keeps working for up to 72 hours if the link drops.
</details>

<details>
<summary><b>Why does a new engine show "Not configured"?</b></summary>

Since 4.7.4 no engine runs until you choose its targets. Open the engine, go to its **Targets** tab, and pick devices,
groups or all devices of its type.
</details>

<details>
<summary><b>Can I bring alerts from my existing monitoring tool?</b></summary>

Yes. Under *Configure › Alert integrations* add Prometheus, Grafana, Zabbix, Nagios, PRTG, SolarWinds, Datadog, Azure
Monitor, CloudWatch, SCOM, LibreNMS, Elastic or any JSON webhook, and alerts appear as sensors on the matching devices.
</details>

---

<div align="center">

**RoboMate MonCastle 4.7.4** · Part of the RoboMate family

Screenshots show the console with generated sample data.

</div>
