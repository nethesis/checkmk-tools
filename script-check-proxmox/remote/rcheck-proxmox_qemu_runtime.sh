#!/bin/bash
# Launcher per check-proxmox_qemu_runtime.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-proxmox/full/check-proxmox_qemu_runtime.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
