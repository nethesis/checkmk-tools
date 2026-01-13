#!/bin/bash
# Launcher LOCAL per check-proxmox_vm_disks - scarica ed esegue da GitHub

# Cache buster per forzare download nuova versione
TIMESTAMP=$(date +%s)
GITHUB_RAW_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-proxmox/local/=${TIMESTAMP}"

# Scarica in file temporaneo ed esegui (timeout 60s)
TEMP_SCRIPT=$(mktemp)
curl -fsSL "$GITHUB_RAW_URL" -o "$TEMP_SCRIPT"
timeout 60s bash "$TEMP_SCRIPT" "$@"
EXIT_CODE=$?
rm -f "$TEMP_SCRIPT"
exit $EXIT_CODE