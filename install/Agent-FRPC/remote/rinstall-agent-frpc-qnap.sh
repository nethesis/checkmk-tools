#!/bin/bash
# Launcher per install-agent-frpc-qnap.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/install/Agent-FRPC/full/install-agent-frpc-qnap.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
