#!/bin/bash
# Launcher per check_postfix_queue.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-ns7/full/check_postfix_queue.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
