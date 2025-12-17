#!/bin/bash
# Launcher per check_ns8_services.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-ns8/full/check_ns8_services.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
