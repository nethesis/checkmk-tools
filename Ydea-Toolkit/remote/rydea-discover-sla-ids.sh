#!/bin/bash
# Launcher per ydea-discover-sla-ids.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/Ydea-Toolkit/full/ydea-discover-sla-ids.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
