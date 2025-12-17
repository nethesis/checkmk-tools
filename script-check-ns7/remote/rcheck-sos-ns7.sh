#!/bin/bash
# Launcher per check-sos-ns7.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-ns7/full/check-sos-ns7.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
