#!/bin/bash
# Docker entrypoint script for ISO builderset -e
echo "================================================"
echo "  CheckMK Installer - ISO Builder (Docker)     "
echo "================================================"
echo ""
# Controlla se siamo in modalit├á interattivaif [ "$1" = "/bin/bash" ]; then    
echo "Modalit├á interattiva attivata."    
echo ""    
echo "Per generare l'ISO, esegui:"    
echo "  ./make-iso.sh"    
echo ""    exec "$@"else    
# Esegui direttamente il comando passato    exec "$@"fi
