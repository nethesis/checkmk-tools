#!/bin/bash
# Launcher per install-checkmk-log-optimizer.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/install-checkmk-log-optimizer.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
