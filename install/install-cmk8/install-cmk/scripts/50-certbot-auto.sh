#!/bin/bash
# 50-certbot-auto.sh - Automated SSL certificate setup

set -euo pipefail

echo "[50-CERTBOT-AUTO] Automated certificate setup..."

# This is a wrapper that auto-detects domain from hostname
DOMAIN=$(hostname -f)

if [[ "$DOMAIN" == "localhost" ]] || [[ -z "$DOMAIN" ]]; then
    echo "[50-CERTBOT-AUTO] Cannot auto-detect domain - skipping SSL"
    exit 0
fi

# Run certbot-run
bash "$(dirname "$0")/50-certbot-run.sh" "$DOMAIN"
