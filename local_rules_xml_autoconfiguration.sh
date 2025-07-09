#!/bin/bash

# Wazuh Manager container name — change if different
CONTAINER_NAME="wazuh.manager"
TMP_RULE_FILE="/tmp/evilginx_rules.xml"

# Step 1: Create full rule group in a temporary file
cat <<'EOF' > evilginx_rules.tmp
<group name="evilginx_red_team,">
  <!-- Evilginx Process Execution -->
  <rule id="100100" level="10">
    <if_sid>1110</if_sid>
    <match>evilginx2</match>
    <description>ALERT: Evilginx process execution detected.</description>
    <group>phishing,process,evilginx</group>
  </rule>

  <!-- Phishlet File Modification -->
  <rule id="100101" level="10">
    <if_sid>550</if_sid>
    <match>.*phishlets.*\.yaml</match>
    <description>ALERT: Evilginx phishlet file modified or added.</description>
    <group>phishing,fim,evilginx</group>
  </rule>

  <!-- Dante SOCKS5 Proxy Process -->
  <rule id="100102" level="9">
    <if_sid>1110</if_sid>
    <match>danted|dante-server</match>
    <description>ALERT: Dante SOCKS5 proxy started on phishing server.</description>
    <group>proxy,process,socks5,dante</group>
  </rule>

  <!-- Port 1080 Detection -->
  <rule id="100103" level="8">
    <if_sid>530</if_sid>
    <match>1080</match>
    <description>ALERT: Dante SOCKS5 port (1080) is open.</description>
    <group>network,socks5,dante</group>
  </rule>

  <!-- Evilginx HTTP/HTTPS Listener -->
  <rule id="100104" level="8">
    <if_sid>530</if_sid>
    <match>80|443</match>
    <description>INFO: Web server (possibly Evilginx) listening on ports 80/443.</description>
    <group>network,evilginx,web</group>
  </rule>

  <!-- SSH Operator Access -->
  <rule id="100105" level="7">
    <if_sid>5710</if_sid>
    <match>ssh|sshd|Accepted password|Accepted publickey</match>
    <description>SSH Login to Evilginx server detected.</description>
    <group>ssh,operator,login</group>
  </rule>

  <!-- Outbound Phishing Target Connections -->
  <rule id="100106" level="10">
    <if_sid>4001</if_sid>
    <match>google\.com|microsoft\.com|login\.live\.com</match>
    <description>ALERT: Evilginx target connections observed.</description>
    <group>network,evilginx,target</group>
  </rule>
</group>
EOF

# Step 2: Copy the temp file into the container
echo "[*] Copying rules into Wazuh container..."
docker cp evilginx_rules.tmp "$CONTAINER_NAME":"$TMP_RULE_FILE"

# Step 3: Append to local_rules.xml inside container
echo "[*] Appending rules to local_rules.xml inside container..."
docker exec -i "$CONTAINER_NAME" bash -c "cat $TMP_RULE_FILE >> /var/ossec/etc/rules/local_rules.xml"

# Step 4: Clean up
echo "[*] Cleaning up..."
docker exec "$CONTAINER_NAME" rm "$TMP_RULE_FILE"
rm evilginx_rules.tmp

# Step 5: Restart container
echo "[*] Restarting Wazuh Manager..."
docker-compose ps --services
docker-compose restart wazuh.manager

echo "[✔] Evilginx Red Team rules added successfully!"
