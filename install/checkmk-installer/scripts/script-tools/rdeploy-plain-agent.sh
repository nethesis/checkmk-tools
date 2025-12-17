#!/bin/bash
# Launcher per eseguire deploy-plain-agent.sh remoto dal repo GitHub
SCRIPT_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/deploy-plain-agent.sh"
# Esegue lo script remotobash <$(curl -fsSL "$SCRIPT_URL") "$@"
