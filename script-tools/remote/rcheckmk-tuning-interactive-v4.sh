#!/bin/bash
# Launcher per checkmk-tuning-interactive-v4.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/checkmk-tuning-interactive-v4.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
