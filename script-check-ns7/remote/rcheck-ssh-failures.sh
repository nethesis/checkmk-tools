#!/bin/bash
# Launcher per check-ssh-failures.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-ns7/full/check-ssh-failures.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
