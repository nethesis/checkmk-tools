#!/bin/bash
# 25-postfix.sh - Install and configure Postfix

set -euo pipefail

echo "[25-POSTFIX] Installing Postfix..."

# Preseed selections
debconf-set-selections <<< "postfix postfix/mailname string $(hostname -f)"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

# Install
apt-get install -y postfix mailutils

# Configure for local delivery
postconf -e "inet_interfaces = loopback-only"
postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost"

# Restart
systemctl restart postfix
systemctl enable postfix

echo "[25-POSTFIX] Postfix configured successfully"
