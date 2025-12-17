#!/bin/bash
# Launcher per ydea-templates.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/Ydea-Toolkit/full/ydea-templates.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
