#!/bin/bash
# Launcher per test-ydea-integration.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/Ydea-Toolkit/full/test-ydea-integration.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
