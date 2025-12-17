#!/bin/bash
# Launcher per esempi-ydea.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/Ydea-Toolkit/full/esempi-ydea.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
