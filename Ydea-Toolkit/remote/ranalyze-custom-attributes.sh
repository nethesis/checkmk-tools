
#!/bin/bash
/usr/bin/env bash
# ranalyze-custom-attributes.sh - Remote launcherset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FULL_DIR="$(dirname "$SCRIPT_DIR")/full"exec "$FULL_DIR/analyze-custom-attributes.sh" "$@"
