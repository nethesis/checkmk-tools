#!/bin/bash
# Remote launcher per setup-mrpe.sh
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-proxmox/setup-mrpe.sh"
exec "$LOCAL_SCRIPT" "$@"
