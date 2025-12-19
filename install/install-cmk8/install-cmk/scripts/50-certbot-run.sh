#!/bin/bash
# 50-certbot-run.sh - Obtain SSL certificate with Certbot

set -euo pipefail

echo "[50-CERTBOT-RUN] Obtaining SSL certificate..."

# Check if domain is provided
DOMAIN="${1:-}"

if [[ -z "$DOMAIN" ]]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 checkmk.example.com"
    exit 1
fi

# Obtain certificate
certbot --apache -d "$DOMAIN" --non-interactive --agree-tos --email "admin@${DOMAIN}"

echo "[50-CERTBOT-RUN] SSL certificate obtained for ${DOMAIN}"
