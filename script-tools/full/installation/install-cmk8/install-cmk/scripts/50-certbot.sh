#!/bin/bash
# 50-certbot.sh - Install Certbot for SSL certificates

set -euo pipefail

echo "[50-CERTBOT] Installing Certbot..."

# Install certbot
apt-get install -y certbot python3-certbot-apache

echo "[50-CERTBOT] Certbot installed successfully"
echo "[50-CERTBOT] Run 50-certbot-run.sh to obtain certificates"
