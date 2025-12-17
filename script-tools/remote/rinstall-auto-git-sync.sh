#!/bin/bash
# Launcher per install-auto-git-sync.sh (usa script locale aggiornato da auto-git-sync)

LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/install-auto-git-sync.sh"

# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
