
#!/bin/bash
/usr/bin/env bash
# scripts-only.sh - Test scripts-only deploymentset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
echo "=== Scripts-Only Deployment Test ==="
echo ""
# Load test configurationexport 
ENV_FILE="${INSTALLER_ROOT}/testing/test-config.env"source "$ENV_FILE"
# Run installer in unattended modecd "$INSTALLER_ROOT"
echo "[1/1] Scripts deployment..."bash modules/04-scripts-deploy.sh
echo ""
echo "=== Scripts-Only Deployment Complete ==="
echo ""
echo "Scripts deployed to:"
echo "  - /opt/script-check-ns7/"
echo "  - /opt/script-check-ns8/"
echo "  - /opt/script-check-ubuntu/"
echo "  - /opt/script-check-windows/"
echo "  - /opt/script-notify-checkmk/"
echo "  - /opt/script-tools/"
echo "  - /opt/Ydea-Toolkit/"
echo "  - /opt/Proxmox/"
echo ""
echo "Update script: /usr/local/bin/update-checkmk-scripts"
