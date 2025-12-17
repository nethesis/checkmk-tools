#!/bin/bash
# Launcher per deploy-monitoring-scripts.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/deploy-monitoring-scripts.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
