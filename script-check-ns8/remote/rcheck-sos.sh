#!/bin/bash
# Launcher per check-sos.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-ns8/full/check-sos.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
