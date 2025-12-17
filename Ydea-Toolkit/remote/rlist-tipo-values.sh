
#!/bin/bash
/usr/bin/env bash
# rlist-tipo-values.sh - Remote launcherset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FULL_DIR="$(dirname "$SCRIPT_DIR")/full"exec "$FULL_DIR/list-tipo-values.sh" "$@"
