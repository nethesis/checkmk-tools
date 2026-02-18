#!/bin/bash
# Remote launcher per increase-swap.sh

TIMESTAMP=$(date +%s)
SCRIPT_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/misc/increase-swap.sh?t=${TIMESTAMP}"

if [ "$EUID" -ne 0 ]; then
    echo "Questo script deve essere eseguito come root"
    exit 1
fi

TEMP_SCRIPT=$(mktemp)
curl -fsSL "$SCRIPT_URL" -o "$TEMP_SCRIPT"
bash "$TEMP_SCRIPT" --yes "$@"
EXIT_CODE=$?
rm -f "$TEMP_SCRIPT"
exit $EXIT_CODE
