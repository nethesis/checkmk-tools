#!/bin/bash
# Launcher per install-frpc-dryrun.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-tools/full/install-frpc-dryrun.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
