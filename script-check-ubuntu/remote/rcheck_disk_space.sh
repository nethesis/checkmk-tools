#!/bin/bash
# shellcheck disable=SC1017
# Launcher per check_disk_space.sh (usa script locale aggiornato da auto-git-sync)

LOCAL_SCRIPT="/opt/checkmk-tools/script-check-ubuntu/full/check_disk_space.sh"

# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"