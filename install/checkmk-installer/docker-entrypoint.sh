#!/usr/bin/env bash
set -euo pipefail

echo "ERROR: this script was quarantined because it was syntactically broken." >&2
echo "A copy of the previous content was saved next to this file." >&2
exit 1

: <<'CORRUPTED_6cb451feb90046ed9ac10dcebb13d933'
#!/bin/bash
# Docker entrypoint script for ISO builderset -e
echo "================================================"
echo "  CheckMK Installer - ISO Builder (Docker)     "
echo "================================================"
echo ""
# Controlla se siamo in modalit├á interattiva
if [ "$1" = "/bin/bash" ]; then
    echo "Modalit├á interattiva attivata."    
echo ""    
echo "Per generare l'ISO, esegui:"    
echo "  ./make-iso.sh"    
echo ""    exec "$@"else    
# Esegui direttamente il coman
do passato    exec "$@"fi

CORRUPTED_6cb451feb90046ed9ac10dcebb13d933

