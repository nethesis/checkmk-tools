#!/bin/bash
# Launcher per install-ydea-checkmk-integration.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/Ydea-Toolkit/full/install-ydea-checkmk-integration.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
