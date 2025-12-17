#!/bin/bash
# Launcher per smart-wrapper-example.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/smart-wrapper-example.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
