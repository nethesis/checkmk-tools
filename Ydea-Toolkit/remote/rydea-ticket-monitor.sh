#!/bin/bash
# Launcher per ydea-ticket-monitor.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/Ydea-Toolkit/full/ydea-ticket-monitor.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
