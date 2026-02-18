#!/bin/bash
# Launcher per eseguire deploy-from-repo.sh remoto dal repo GitHub

SCRIPT_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/deploy/deploy-from-repo.sh"

# Esegue lo script remoto
bash <(curl -fsSL "$SCRIPT_URL") "$@"
