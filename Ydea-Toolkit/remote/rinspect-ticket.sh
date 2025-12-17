
#!/bin/bash
/usr/bin/env bash
# rinspect-ticket.sh - Remote launcher per inspect-ticket.shset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FULL_DIR="$(dirname "$SCRIPT_DIR")/full"exec "$FULL_DIR/inspect-ticket.sh" "$@"
