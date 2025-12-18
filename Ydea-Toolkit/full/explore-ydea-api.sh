#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/ydea-toolkit.sh"

need jq

log_info "Exploring Ydea API base: ${YDEA_BASE_URL%/}"

test_endpoint() {
    local method="$1"
    local endpoint="$2"
    local desc="$3"

    printf '\n=== %s: %s %s ===\n' "$desc" "$method" "$endpoint" >&2
    if resp="$(ydea_api "$method" "$endpoint" 2>/dev/null)"; then
        printf '%s\n' "$resp" | head -c 800
        printf '\n' 
        if printf '%s' "$resp" | jq -e . >/dev/null 2>&1; then
            printf 'JSON keys: ' >&2
            printf '%s' "$resp" | jq -r 'keys | join(", ")' >&2 || true
            printf '\n' >&2
            count="$(printf '%s' "$resp" | jq -r '.objs | length' 2>/dev/null || echo '')"
            if [[ -n "$count" ]]; then
                printf 'objs count: %s\n' "$count" >&2
            fi
        fi
        return 0
    fi
    printf 'FAILED\n' >&2
    return 1
}

endpoints=(
    "/categories"
    "/category"
    "/ticket/categories"
    "/sla"
    "/slas"
    "/priorities"
    "/priority"
    "/tickets?limit=1"
    "/users?limit=1"
    "/info"
)

for ep in "${endpoints[@]}"; do
    test_endpoint GET "$ep" "Probe"
done

exit 0

: <<'CORRUPTED_99c689c9e3b14d3b9d05ff684caafc3e'
#!/bin/bash
/usr/bin/env bash
# explore-ydea-api.sh ÔÇö Esplora gli endpoint disponibili dell'API Ydea
# Usa questo script per scoprire quali endpoint esistono e come risponde l'APIset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YDEA_TOOLKIT="${SCRIPT_DIR}/ydea-toolkit.sh"
# Carica le funzioni da ydea-toolkit
# shellcheck disable=SC1090source "$YDEA_TOOLKIT"
echo ""
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo "  ­ƒöì ESPLORAZIONE API YDEA"
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo ""
# Verifica autenticazione
echo "­ƒôï Step 1: Autenticazione..."set +eensure_token 2>&1
if [[ $? -ne 0 ]]; then
    echo "ÔØî Errore autenticazione"
    exit 1fiset -e
echo "Ô£à Autenticato"
echo ""
# Carica token
TOKEN=$(load_token)
BASE_URL="${YDEA_BASE_URL%/}"
echo "­ƒîÉ Base URL: $BASE_URL"
echo "­ƒöæ Token: ${TOKEN:0:20}..."
echo ""
# Funzione helper per testare un endpointtest_endpoint() {  local method="$1"  local endpoint="$2"  local description="$3"    
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"  
echo "­ƒôí Test: $description"  
echo "   $method $endpoint"  
echo ""    local url="${BASE_URL}${endpoint}"  local response  local http_code    set +e  response=$(curl -s -w '\n%{http_code}' \    -X "$method" \    -H "Authorization: Bearer $TOKEN" \    -H "Content-Type: application/json" \    -H "Accept: application/json" \    --connect-timeout 10 \    --max-time 30 \    "$url" 2>&1)  local curl_exit=$?  set -e    if [[ $curl_exit -ne 0 ]]; then
    echo "ÔØî Errore curl (exit: $curl_exit)"    
echo "$response"    return 1  fi    http_code=$(
echo "$response" | tail -1)  response=$(
echo "$response" | head -n -1)    
echo "­ƒôè HTTP Status: $http_code"    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    echo "Ô£à Successo!"    
echo ""    
echo "Risposta (primi 50 caratteri):"    
echo "$response" | head -c 500    
echo ""    
echo ""    
echo "Struttura JSON:"    
echo "$response" | jq -r 'keys' 2>/dev/null || 
echo "Non ├¿ JSON vali
do"        
# Se ha array 'objs', mostra quanti elementi    local count    count=$(
echo "$response" | jq -r '.objs | length' 2>/dev/null || 
echo "")    if [[ -n "$count" && "$count" != "null" ]]; then
    echo "­ƒôª Numero di oggetti (.objs): $count"      if [[ "$count" -gt 0 ]]; then
    echo ""        
echo "Esempio primo oggetto:"        
echo "$response" | jq -r '.objs[0]' 2>/dev/null | head -20      fi    fi
else    
echo "ÔÜá´©Å  HTTP $http_code"    
echo "$response" | jq '.' 2>/dev/null || 
echo "$response"  fi
echo ""}
# Test endpoint comuni
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo "  INIZIO TEST ENDPOINT"
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo ""
# Endpoint categorie - varianti comunitest_endpoint "GET" "/categories" "Lista categorie (variant 1)"test_endpoint "GET" "/category" "Lista categorie (variant 2)"test_endpoint "GET" "/ticket/categories" "Categorie ticket (variant 3)"test_endpoint "GET" "/api/categories" "Categorie con prefisso api"
# Endpoint SLA - varianti comuni  test_endpoint "GET" "/sla" "Lista SLA (variant 1)"test_endpoint "GET" "/slas" "Lista SLA (variant 2)"test_endpoint "GET" "/ticket/sla" "SLA ticket"
# Endpoint priorit├átest_endpoint "GET" "/priorities" "Lista priorit├á (variant 1)"test_endpoint "GET" "/priority" "Lista priorit├á (variant 2)"test_endpoint "GET" "/ticket/priorities" "Priorit├á ticket"
# Endpoint ticket (per riferimento)test_endpoint "GET" "/tickets?limit=1" "Lista ticket (per verifica)"
# Endpoint users (per riferimento)test_endpoint "GET" "/users?limit=1" "Lista utenti (per verifica)"
# Endpoint generico infotest_endpoint "GET" "/" "Info API root"test_endpoint "GET" "/info" "Info API"test_endpoint "GET" "/api" "API info"
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo "  Ô£à ESPLORAZIONE COMPLETATA"
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo ""
echo "­ƒÆí Suggerimento: Cerca negli output sopra gli HTTP 200 per vedere"
echo "   quali endpoint funzionano e quale struttura hanno i dati."
echo ""

CORRUPTED_99c689c9e3b14d3b9d05ff684caafc3e

