#!/bin/bash
# Launcher remoto per upgrade-checkmk.sh - scarica ed esegue da GitHub

# Cache buster per forzare download nuova versione
TIMESTAMP=$(date +%s)
GITHUB_RAW_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/=${TIMESTAMP}"

# Scarica in file temporaneo ed esegui
TEMP_SCRIPT=$(mktemp)
curl -fsSL "$GITHUB_RAW_URL" -o "$TEMP_SCRIPT"
bash "$TEMP_SCRIPT" "$@"
EXIT_CODE=$?
rm -f "$TEMP_SCRIPT"
exit $EXIT_CODE