#!/bin/bash
# rinstall-agent-frpc-synology.sh - Remote launcher for Synology agent+FRPC installer

REPO_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main"
SCRIPT_PATH="install/Agent-FRPC/full/install-agent-frpc-synology.sh"

TEMP_SCRIPT=$(mktemp)
trap "rm -f $TEMP_SCRIPT" EXIT

curl -fsSL "${REPO_URL}/${SCRIPT_PATH}" -o "$TEMP_SCRIPT"
chmod +x "$TEMP_SCRIPT"

exec "$TEMP_SCRIPT" "$@"
