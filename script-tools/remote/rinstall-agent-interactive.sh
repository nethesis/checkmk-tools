#!/bin/bash
# Launcher per install-agent-interactive.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/install-agent-interactive.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
