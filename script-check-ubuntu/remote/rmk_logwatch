#!/usr/bin/env bash
# Remote launcher per mk_logwatch
# Scarica e esegue la versione completa da repository

REPO_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ubuntu/full/mk_logwatch"

# Usa temp file per scaricare ed eseguire lo script
TEMP_SCRIPT=$(mktemp)
curl -fsSL "$REPO_URL" -o "$TEMP_SCRIPT"
python3 "$TEMP_SCRIPT" "$@"
EXIT_CODE=$?
rm -f "$TEMP_SCRIPT"
exit $EXIT_CODE
