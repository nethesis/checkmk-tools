#!/bin/bash
# Launcher per check-proxmox_vm_api.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-proxmox/full/check-proxmox_vm_api.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
