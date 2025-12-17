#!/bin/bash
# Launcher per check-pkg-install.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-ns7/full/check-pkg-install.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
