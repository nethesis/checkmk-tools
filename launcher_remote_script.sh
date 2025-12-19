#!/bin/bash
# launcher_remote_script.sh - Template per creare launcher remoti
# Scarica ed esegue script dal repository GitHub passando eventuali parametri

set -euo pipefail

# Configurazione
REPO_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main"
SCRIPT_NAME="${1:-}"

if [[ -z "$SCRIPT_NAME" ]]; then
  echo "Uso: $0 <script_name> [args...]"
  echo ""
  echo "Esempi:"
  echo "  $0 script-tools/full/auto-git-sync.sh 300"
  echo "  $0 Ydea-Toolkit/full/ydea-toolkit.sh list-tickets"
  exit 1
fi

shift

# Scarica ed esegue
SCRIPT_URL="$REPO_URL/$SCRIPT_NAME"
echo "📥 Downloading: $SCRIPT_URL"

TEMP_SCRIPT=$(mktemp)
trap "rm -f '$TEMP_SCRIPT'" EXIT

if curl -fsSL "$SCRIPT_URL" -o "$TEMP_SCRIPT"; then
  echo "✓ Downloaded successfully"
  echo "▶ Executing: $SCRIPT_NAME $*"
  echo ""
  bash "$TEMP_SCRIPT" "$@"
else
  echo "❌ Failed to download script"
  exit 1
fi
