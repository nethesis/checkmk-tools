#!/bin/bash
# Launcher per check-proxmox-vm-snapshot-status.sh (scarica da GitHub)
GITHUB_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-proxmox/full/check-proxmox-vm-snapshot-status.sh"
curl -sSL "$GITHUB_URL" | bash -s -- "$@"
