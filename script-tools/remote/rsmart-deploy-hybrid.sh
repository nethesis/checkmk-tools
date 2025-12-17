#!/bin/bash
# Launcher per smart-deploy-hybrid.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/smart-deploy-hybrid.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
