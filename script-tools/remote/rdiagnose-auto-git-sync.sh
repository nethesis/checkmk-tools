#!/bin/bash
# Launcher per eseguire diagnose-auto-git-sync.sh remoto dal repo GitHub

SCRIPT_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/sync_update/diagnose-auto-git-sync.sh"

# Esegue lo script remoto
bash <(curl -fsSL "$SCRIPT_URL") "$@"
