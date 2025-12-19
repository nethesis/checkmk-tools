#!/bin/bash
# Proxmox VM API Check
# Verifica accessibilità API Proxmox

set -euo pipefail

API_URL="${PROXMOX_API_URL:-https://localhost:8006/api2/json}"
TOKEN_ID="${PROXMOX_TOKEN_ID:-}"
TOKEN_SECRET="${PROXMOX_TOKEN_SECRET:-}"

echo "<<<proxmox_api>>>"

if [[ -z "$TOKEN_ID" || -z "$TOKEN_SECRET" ]]; then
    echo "2 Proxmox_API - No API credentials configured"
    exit 0
fi

# Test API connectivity
response=$(curl -s -k -m 5 \
    -H "Authorization: PVEAPIToken=$TOKEN_ID=$TOKEN_SECRET" \
    "$API_URL/version" 2>&1)

if [[ $? -eq 0 ]]; then
    version=$(echo "$response" | grep -oP '"version":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    echo "0 Proxmox_API - API Reachable (Version: $version)"
else
    echo "2 Proxmox_API - API Unreachable: $response"
fi
