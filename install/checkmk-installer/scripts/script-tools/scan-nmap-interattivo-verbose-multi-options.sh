#!/usr/bin/env bash
set -euo pipefail

# Wrapper: use canonical implementation from repo.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL="$SCRIPT_DIR/../../../../script-tools/full/scan-nmap-interattivo-verbose-multi-options.sh"

if [[ -x "$CANONICAL" ]]; then
    exec "$CANONICAL" "$@"
fi

echo "[ERR] Script canonico non trovato o non eseguibile: $CANONICAL" >&2
exit 1
