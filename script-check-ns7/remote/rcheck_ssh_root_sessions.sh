#!/bin/bash
# Launcher per check_ssh_root_sessions.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-ns7/full/check_ssh_root_sessions.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
