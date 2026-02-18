#!/bin/bash
# Launcher per eseguire install-and-deploy-plain-agent.sh remoto dal repo GitHub
SCRIPT_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/installation/install-and-deploy-plain-agent.sh"
# Esegue lo script remotobash <$(curl -fsSL "$SCRIPT_URL") "$@"
