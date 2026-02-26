#!/bin/bash
# 40-fail2ban.sh - Install and configure Fail2Ban

set -euo pipefail

echo "[40-FAIL2BAN] Installing Fail2Ban..."

# Install
apt-get install -y fail2ban

# Create local config
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
EOF

# Enable and start
systemctl enable fail2ban
systemctl restart fail2ban

echo "[40-FAIL2BAN] Fail2Ban configured successfully"
