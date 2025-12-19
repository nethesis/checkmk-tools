#!/bin/bash
# 30-firewall.sh - Configure UFW firewall

set -euo pipefail

echo "[30-FIREWALL] Configuring UFW..."

# Install UFW
apt-get install -y ufw

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow CheckMK agent
ufw allow 6556/tcp

# Enable firewall
echo "y" | ufw enable

echo "[30-FIREWALL] Firewall configured successfully"
