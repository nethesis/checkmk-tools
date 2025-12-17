#!/bin/bash
# Launcher per check-proxmox-vm-status.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-proxmox/full/check-proxmox-vm-status.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
