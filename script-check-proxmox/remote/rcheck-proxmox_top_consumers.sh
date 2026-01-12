#!/bin/bash
# Launcher per check-proxmox_top_consumers.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-proxmox/full/check-proxmox_top_consumers.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
