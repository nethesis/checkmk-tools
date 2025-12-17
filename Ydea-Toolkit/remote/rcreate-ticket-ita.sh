#!/bin/bash
# Launcher per create-ticket-ita.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/Ydea-Toolkit/full/create-ticket-ita.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
