#!/bin/bash
# Launcher per proxmox_vm_monitor.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-proxmox/full/proxmox_vm_monitor.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
