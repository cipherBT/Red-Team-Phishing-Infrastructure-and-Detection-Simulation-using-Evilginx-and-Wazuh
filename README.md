# Red-Team-Phishing-Infrastructure-and-Detection-Simulation-using-Evilginx-and-Wazuh

**Project Owner:** Adekilekun Fatiu\
**Date of Execution:** 07/07/2025\
**Project Title:** Red Team Phishing Infrastructure and Detection Simulation using Evilginx and Wazuh

---

## 1. Objective

Simulate a real-world credential theft operation using Evilginx2 phishing proxy while simultaneously monitoring and detecting activities using Wazuh SIEM with Kibana dashboards.

---

## 2. Scope of Engagement

| Item               | Description                        |
| ------------------ | ---------------------------------- |
| Authorized Range   | AWS-hosted VPS lab environment     |
| Authorized Domains | Internal test domains only         |
| Type of Engagement | Controlled Red Team Simulation     |
| Constraints        | No targeting of real-world systems |

---

## 3. Tools & Technologies

| Tool/Tech             | Purpose                          |
| --------------------- | -------------------------------- |
| Evilginx2             | Phishing Proxy                   |
| NameCheap             | Domain Provider                  |
| AWS Hosted Zones      | DNS Management                   |
| Docker/Docker-Compose | Containerization & Orchestration |
| Wazuh 4.12            | SIEM / XDR                       |
| Dante SOCKS5          | Proxy Server                     |
| Suricata              | Intrusion Detection System (IDS) |
| AuditD                | Linux Audit Daemon               |
| Amazon EC2            | VPS Infrastructure (Ubuntu)      |

---

## 4. Infrastructure Design

**VPS 1 (Attacker Node)**:

- Evilginx2
- Dante SOCKS5
- Wazuh Agent
- Suricata
- AuditD

**VPS 2 (Detection Node)**:

- Wazuh Manager (via Docker Compose)
- Wazuh Dashboard
- Wazuh Indexer

SSH is restricted via key-based authentication on both VPS instances.

---

## 5. Attack Simulation Phases

### Phase 1: Environment Setup

- Provision EC2 Instances:
  - VPS 1: t2.micro (1GB RAM)
  - VPS 2: t2.large (8GB RAM)
- Register test domain and configure DNS on AWS Hosted Zones

### Phase 2: Evilginx Setup (VPS 1)

- Install Go and build Evilginx2
- Clone repo: `git clone https://github.com/kgretzky/evilginx2.git`
- Build: `go build`
- Install Dante SOCKS5: `sudo apt install dante-server -y`
- Configure Dante (`/etc/danted.conf`):

```conf
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 1080
external: eth0
method: username none
user.notprivileged: nobody
client pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  log: connect disconnect error
}
pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  protocol: tcp udp
  log: connect disconnect error
}
```

- Enable and start Dante
- Verify proxy: `curl -x socks5://<ip>:1080 http://ifconfig.me`
- Configure Evilginx2 domain and phishlets

### Phase 3: Wazuh Manager Setup (VPS 2)

- Install Docker & Docker Compose
- Clone Wazuh Docker: `git clone https://github.com/wazuh/wazuh-docker -b v4.12.0`
- Deploy single-node via Docker Compose

### Phase 4: Wazuh Rules and Configuration

- Enter container: `docker exec -it wazuh.manager bash`
- Edit `ossec.conf` to enable:
  - `<logall>yes</logall>`
  - `<enabled>yes</enabled>` in vulnerability detection
  - Add SSH brute-force detection active response
- Deploy custom rules via `local_rules.xml`
- Restart: `docker-compose restart wazuh.manager`

### Phase 5: Wazuh Agent on Evilginx VPS (VPS 1)

- Install Wazuh agent and connect to manager (VPS 2)
- Verify visibility on dashboard

### Phase 6: Agent Hardening and Log Sources

- Configure directories in `ossec.conf` for FIM:

```xml
<directories check_all="yes" report_changes="yes" realtime="yes">/home/ubuntu/evilginx2</directories>
```

- Install and configure Suricata:
  - Add rules to `/etc/suricata/rules`
  - Point `eve.json` to Wazuh
- Install AuditD and add exec rules:

```bash
-a exit,always -F arch=b64 -S execve -k audit-wazuh-c
-a always,exit -F path=/home/ubuntu/evilginx2 -F perm=x -k evilginx_exec
```

- Reload audit rules

### Phase 7: Launch Phishing Attack

- Create lure: `lures create github`
- Edit lure path and hostname
- Get phishing URL: `lures get-url <id>`
- Capture session cookies via Evilginx and replay using EditThisCookie browser extension

---

## 6. Detection Use Cases

| Detection Point            | Wazuh Rule ID | Visibility                |
| -------------------------- | ------------- | ------------------------- |
| Evilginx process starts    | 100100        | Dashboard Alert           |
| Phishlet files modified    | 100101        | File Integrity Monitoring |
| SOCKS5 Proxy activity      | 100102/100103 | Port & Process Detection  |
| SSH Operator Access        | 100105        | Auth Logs                 |
| Outbound Target Connection | 100106        | Network Monitoring        |

---

## 7. Mitigation Recommendations

- Block Evilginx signatures on IDS/IPS
- Monitor Dante/Evilginx processes at endpoint
- Enforce MFA, token refresh intervals
- Adopt phishing-resistant authentication (e.g., passkeys)
- Conduct periodic user awareness and simulation tests

---

## 8. Lessons Learned

- Evilginx2 is an effective phishing proxy
- Wazuh, with custom rules, successfully detects red team behavior
- SOCKS5 proxies provide good opsec and traffic obfuscation
- Suricata and AuditD enhance visibility on low-level behavior

---

## 9. Project Deliverables

- ✅ Evilginx phishlet templates
- ✅ Custom Wazuh detection rules
- ✅ Audit.rules for AuditD
- ✅ Dante SOCKS5 proxy config (`danted.conf`)
- ✅ `ossec.conf` templates for Wazuh Manager & Agent
- ✅ Full setup + attack simulation guide (this file)

---

## 10. Ethical Disclaimer

This project was executed in a private cloud lab environment solely for educational and ethical cybersecurity training. No real-world services or unauthorized systems were targeted. All assets, infrastructure, and domains are under the control of the project owner.

---
