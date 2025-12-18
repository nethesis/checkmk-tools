#!/usr/bin/env bash
set -euo pipefail

# Wrapper: usa la versione canonica in script-tools/full.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CANONICAL_LOCAL="$HERE/full/install-auto-git-sync.sh"
CANONICAL_OPT="/opt/checkmk-tools/script-tools/full/install-auto-git-sync.sh"

if [[ -x "$CANONICAL_LOCAL" ]]; then
    exec "$CANONICAL_LOCAL" "$@"
fi

if [[ -x "$CANONICAL_OPT" ]]; then
    exec "$CANONICAL_OPT" "$@"
fi

echo "[ERR] install-auto-git-sync.sh: script canonico non trovato" >&2
echo "[INFO] attesi: $CANONICAL_LOCAL oppure $CANONICAL_OPT" >&2
exit 1
