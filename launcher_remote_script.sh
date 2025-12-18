#!/usr/bin/env bash
set -euo pipefail

# Launcher base per eseguire qualsiasi script dal repo GitHub senza copia locale
# Uso: bash launcher_remote_script.sh <URL_SCRIPT> [parametri]

if [[ ${1:-} == "" ]]; then
  echo "Usage: $0 <URL_SCRIPT> [parametri]" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not found" >&2
  exit 1
fi

SCRIPT_URL="$1"
shift

bash <(curl -fsSL "$SCRIPT_URL") "$@"
