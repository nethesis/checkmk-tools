#!/bin/bash
# Launcher per upgrade-checkmk.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/upgrade-checkmk.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
