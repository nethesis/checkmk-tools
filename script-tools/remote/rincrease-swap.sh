#!/bin/bash
# Remote launcher per increase-swap.sh
# Scarica ed esegue lo script dal repository GitHub
REPO_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main"
SCRIPT_PATH="script-tools/full/increase-swap.sh"
# Verifica se eseguito come root
if [ "$EUID" -ne 0 ]; then
    echo "Questo script deve essere eseguito come root"
    exit 1
fi # Scarica in file temporaneo ed esegue con flag --yes
TEMP_SCRIPT=$(mktemp)curl -fsSL "$REPO_URL/$SCRIPT_PATH" -o "$TEMP_SCRIPT"bash "$TEMP_SCRIPT" --yes "$@"rm -f "$TEMP_SCRIPT"
