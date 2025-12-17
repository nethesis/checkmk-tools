#!/bin/bash
/usr/bin/env bash
# rsearch-sla-in-contracts.sh - Remote launcherset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FULL_DIR="$(dirname "$SCRIPT_DIR")/full"exec "$FULL_DIR/search-sla-in-contracts.sh" "$@"
