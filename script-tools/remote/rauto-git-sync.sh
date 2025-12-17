#!/bin/bash
# Launcher per auto-git-sync.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/auto-git-sync.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
