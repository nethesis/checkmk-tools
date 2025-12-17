#!/bin/bash
/usr/bin/env bash
# quick-test-ydea-api.sh ÔÇö Test rapi
do connessione API Ydea
# Verifica che le credenziali funzionino prima di eseguire la discovery completaset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YDEA_TOOLKIT="${SCRIPT_DIR}/ydea-toolkit.sh"
# Carica le funzioni da ydea-toolkit
# shellcheck disable=SC1090source "$YDEA_TOOLKIT"
echo ""
echo "­ƒöÉ Test Connessione Ydea API"
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo ""
# Test 1: Verifica variabili ambiente
echo "­ƒôï Test 1: Verifica configurazione..."if [[ -z "${YDEA_ID:-}" || "${YDEA_ID}" == "ID" ]]; then  
echo "ÔØî YDEA_ID non configurato correttamente"  
echo "   Edita il file .env e imposta YDEA_ID"  exit 1fi
if [[ -z "${YDEA_API_KEY:-}" || "${YDEA_API_KEY}" == "TOKEN" ]]; then  
echo "ÔØî YDEA_API_KEY non configurato correttamente"  
echo "   Edita il file .env e imposta YDEA_API_KEY"  exit 1fi
echo "Ô£à Variabili configurate:"
echo "   YDEA_ID: ${YDEA_ID}"
echo "   YDEA_API_KEY: ${YDEA_API_KEY:0:10}..."
echo ""
# Test 2: Login
echo "­ƒôï Test 2: Autenticazione..."if ! ensure_token 2>&1; then  
echo "ÔØî Autenticazione fallita"  
echo "   Verifica che YDEA_ID e YDEA_API_KEY siano corretti"  exit 1fi
echo "Ô£à Autenticazione riuscita"
echo ""
# Test 3: Test chiamata API categorie
echo "­ƒôï Test 3: Test chiamata API categorie..."set +e  
# Disabilita exit on error temporaneamentecategories_data=$(ydea_api GET "/categories" 2>&1)exit_code=$?set -e  
# Riabilita exit on error
if [[ $exit_code -ne 0 ]]; then  
echo "ÔØî Errore nella chiamata API categorie (exit code: $exit_code)"  
echo ""  
echo "Risposta/Errore:"  
echo "$categories_data"  
echo ""  
echo "Possibili cause:"  
echo "  - Endpoint /categories non esiste o non ├¿ accessibile"  
echo "  - Problema di connessione o timeout"  
echo "  - Token scaduto o non vali
do"  exit 1fi
# Verifica se la risposta ├¿ JSON valido
if ! 
echo "$categories_data" | jq empty 2>/dev/null; then  
echo "ÔØî Risposta non ├¿ JSON vali
do"  
echo ""  
echo "Risposta ricevuta:"  
echo "$categories_data" | head -30  exit 1fi
# Verifica se c'├¿ un errore nella risposta
if 
echo "$categories_data" | jq -e 'has("error")' >/dev/null 2>&1; then  
echo "ÔØî Errore nella risposta API"  
echo "$categories_data" | jq '.'  exit 1ficat_count=$(
echo "$categories_data" | jq -r '.objs | length' 2>/dev/null || 
echo "0")
echo "Ô£à API categorie funzionante - $cat_count categorie trovate"
echo ""
# Test 4: Test chiamata API ticket
echo "­ƒôï Test 4: Test chiamata API tickets..."tickets_data=$(ydea_api GET "/tickets?limit=1" 2>&1)
if [[ $? -ne 0 ]] || 
echo "$tickets_data" | jq -e '.error' >/dev/null 2>&1; then  
echo "ÔØî Errore nella chiamata API tickets"  
echo "Risposta API:"  
echo "$tickets_data" | head -20  exit 1fi
echo "Ô£à API tickets funzionante"
echo ""
# Test 5: Test chiamata API users
echo "­ƒôï Test 5: Test chiamata API users..."users_data=$(ydea_api GET "/users?limit=1" 2>&1)
if [[ $? -ne 0 ]] || 
echo "$users_data" | jq -e '.error' >/dev/null 2>&1; then  
echo "ÔØî Errore nella chiamata API users"  
echo "Risposta API:"  
echo "$users_data" | head -20  exit 1fi
echo "Ô£à API users funzionante"
echo ""
# Riepilogo
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo "Ô£à Tutti i test superati!"
echo ""
echo "­ƒÜÇ Puoi ora eseguire lo script di discovery:"
echo "   ./ydea-discover-sla-ids.sh"
echo ""
