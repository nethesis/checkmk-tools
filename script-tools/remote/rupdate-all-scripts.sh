#!/bin/bash
# Launcher per update-all-scripts.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/update-all-scripts.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
