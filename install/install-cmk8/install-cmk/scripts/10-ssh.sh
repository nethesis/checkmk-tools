#!/bin/bash
# 10-ssh.sh - Configure SSH hardening

set -euo pipefail

echo "[10-SSH] Hardening SSH configuration..."

# Backup original
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Apply hardening
sed -i 's/#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config

# Restart SSH
systemctl restart sshd || systemctl restart ssh

echo "[10-SSH] SSH hardened successfully"
