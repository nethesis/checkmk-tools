#!/bin/bash
# Launcher per update-scripts-from-repo.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/update-scripts-from-repo.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
