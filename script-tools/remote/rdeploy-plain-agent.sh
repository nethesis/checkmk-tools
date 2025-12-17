#!/bin/bash
# Launcher per deploy-plain-agent.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/deploy-plain-agent.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
