#!/bin/bash
# 60-checkmk.sh - Install CheckMK Raw Edition

set -euo pipefail

echo "[60-CHECKMK] Installing CheckMK..."

# Variables
CMK_VERSION="${CMK_VERSION:-2.4.0p1}"
CMK_EDITION="cre"
SITE_NAME="${SITE_NAME:-monitoring}"

# Download CheckMK
echo "[60-CHECKMK] Downloading CheckMK ${CMK_VERSION}..."
cd /tmp
wget "https://download.checkmk.com/checkmk/${CMK_VERSION}/check-mk-raw-${CMK_VERSION}_0.jammy_amd64.deb"

# Install
echo "[60-CHECKMK] Installing package..."
apt-get install -y gdebi-core
gdebi -n "check-mk-raw-${CMK_VERSION}_0.jammy_amd64.deb"

# Create site
echo "[60-CHECKMK] Creating site ${SITE_NAME}..."
omd create "$SITE_NAME"

# Start site
echo "[60-CHECKMK] Starting site..."
omd start "$SITE_NAME"

# Show credentials
echo ""
echo "=========================================="
echo "CheckMK installed successfully!"
echo "=========================================="
echo "Site: $SITE_NAME"
echo "URL: http://$(hostname -I | awk '{print $1}')/$SITE_NAME"
echo "Username: cmkadmin"
echo "Password: $(omd su $SITE_NAME -c 'cat ~/var/check_mk/web/cmkadmin/automation.secret')"
echo "=========================================="
