#!/bin/bash
# Docker entrypoint script for ISO builder
set -e

echo "================================================"
echo "  CheckMK Installer - ISO Builder (Docker)     "
echo "================================================"
echo ""

# Controlla se siamo in modalità interattiva
if [ "$1" = "/bin/bash" ]; then
    echo "Modalità interattiva attivata."
    echo ""
    echo "Per generare l'ISO, esegui:"
    echo "  ./make-iso.sh"
    echo ""
    exec "$@"
else
    # Esegui direttamente il comando passato
    exec "$@"
fi
