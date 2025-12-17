#!/bin/bash
# Launcher per check_dovecot_status.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-ns7/full/check_dovecot_status.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
