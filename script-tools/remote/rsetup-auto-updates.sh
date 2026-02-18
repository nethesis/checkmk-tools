#!/bin/bash
# Launcher per eseguire setup-auto-updates.sh remoto dal repo GitHub

SCRIPT_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/upgrade_maintenance/setup-auto-updates.sh"

# Esegue lo script remoto
bash <(curl -fsSL "$SCRIPT_URL") "$@"
