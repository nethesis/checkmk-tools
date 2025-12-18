#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/ydea-toolkit.sh"

need jq

anagrafica_id="${1:-2339268}"
out_dir="${YDEA_OUT_DIR:-/tmp}"

log_info "Exploring anagrafica id=$anagrafica_id"

endpoints=(
    "/anagrafica/${anagrafica_id}"
    "/anagrafiche/${anagrafica_id}"
    "/clienti/${anagrafica_id}"
    "/cliente/${anagrafica_id}"
    "/aziende/${anagrafica_id}"
    "/azienda/${anagrafica_id}"
    "/anagrafiche?id=${anagrafica_id}"
    "/sla?anagrafica_id=${anagrafica_id}"
    "/contracts?anagrafica_id=${anagrafica_id}"
    "/contratti?anagrafica_id=${anagrafica_id}"
)

found=0
for ep in "${endpoints[@]}"; do
    log_info "GET $ep"
    if resp="$(ydea_api GET "$ep" 2>/dev/null)"; then
        printf '%s\n' "$resp" | jq . || printf '%s\n' "$resp"
        file="$out_dir/ydea-anagrafica-${anagrafica_id}-$(printf '%s' "$ep" | tr '/?=&' '____').json"
        printf '%s\n' "$resp" >"$file"
        log_info "Saved: $file"
        found=$((found + 1))
    else
        log_warn "Endpoint failed: $ep"
    fi
done

log_info "Successful endpoints: $found/${#endpoints[@]}"

log_info "Searching tickets for anagrafica_id=$anagrafica_id (limit=50)"
tickets="$(ydea_api GET "/tickets?limit=50" 2>/dev/null || echo '{"objs":[]}')"
matching="$(printf '%s' "$tickets" | jq --arg aid "$anagrafica_id" '[.objs[]? | select(.anagrafica_id == ($aid|tonumber))]')"
count="$(printf '%s' "$matching" | jq -r 'length')"
log_info "Found $count tickets"
if [[ "$count" != "0" ]]; then
    log_info "First ticket sample:"
    printf '%s\n' "$matching" | jq '.[0]'
    log_info "Available keys across matching tickets:"
    printf '%s\n' "$matching" | jq '[.[].keys[]] | unique | sort[]'
fi

exit 0

: <<'CORRUPTED_550a91e664c448978b1c63856150c1e7'
#!/bin/bash
/usr/bin/env bash
# explore-anagrafica.sh - Esplora i dati dell'anagrafica per trovare la SLAset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"source "$SCRIPT_DIR/ydea-toolkit.sh"
ANAGRAFICA_ID="${1:-2339268}"  
# Default: AZIENDA MONITORATA test
echo "­ƒöì Esplorazione anagrafica ID: $ANAGRAFICA_ID..."
echo ""ensure_token
TOKEN="$(load_token)"
# Prova vari endpoint per l'anagraficadeclare -a 
ENDPOINTS=(  "/anagrafica/$ANAGRAFICA_ID"  "/anagrafiche/$ANAGRAFICA_ID"  "/clienti/$ANAGRAFICA_ID"  "/cliente/$ANAGRAFICA_ID"  "/aziende/$ANAGRAFICA_ID"  "/azienda/$ANAGRAFICA_ID"  "/anagrafiche?id=$ANAGRAFICA_ID"  "/sla?anagrafica_id=$ANAGRAFICA_ID"  "/contracts?anagrafica_id=$ANAGRAFICA_ID"  "/contratti?anagrafica_id=$ANAGRAFICA_ID")
echo "­ƒôí Tentativo di recupero dati anagrafica..."
echo ""for ENDPOINT in "${ENDPOINTS[@]}"; do  
echo -n "   GET $ENDPOINT ... "    
RESPONSE=$(curl -s -w '\n%{http_code}' \    -H "Accept: application/json" \    -H "Authorization: Bearer ${TOKEN}" \    "${YDEA_BASE_URL}${ENDPOINT}" 2>&1 || 
echo -e "\n000")  
HTTP_CODE=$(
echo "$RESPONSE" | tail -n1)    if [[ "$HTTP_CODE" == "200" ]]; then
    echo "Ô£à HTTP $HTTP_CODE - TROVATO!"        
HTTP_BODY=$(
echo "$RESPONSE" | sed '$d')        
echo ""    
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"    
echo "RISPOSTA DA: $ENDPOINT"    
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"    
echo ""    
echo "$HTTP_BODY" | jq '.'    
echo ""        
# Cerca campi contenenti "sla", "premium", "mon"    
echo "­ƒöì Campi contenenti 'SLA', 'Premium' o 'Mon':"    
echo "$HTTP_BODY" | jq 'walk(if type == "object" then with_entries(select(.key | test("sla|premium|mon|contract|contratt"; "i"))) else . end)' 2>/dev/null || 
echo "   Nessuno trovato"    
echo ""        
# Salva il risultato    
echo "$HTTP_BODY" | jq '.' > "/tmp/anagrafica-${ANAGRAFICA_ID}.json"    
echo "­ƒÆ¥ Salvato in: /tmp/anagrafica-${ANAGRAFICA_ID}.json"    
echo ""
elif [[ "$HTTP_CODE" == "404" ]]; then
    echo "ÔØî HTTP $HTTP_CODE - Non trovato"
elif [[ "$HTTP_CODE" == "401" ]]; then
    echo "ÔØî HTTP $HTTP_CODE - Non autorizzato"
elif [[ "$HTTP_CODE" == "403" ]]; then
    echo "ÔØî HTTP $HTTP_CODE - Accesso negato"
else    
echo "ÔØî HTTP $HTTP_CODE"  fi
done
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "RICERCA NEI TICKET CON QUESTA ANAGRAFICA"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
echo "Cerco ticket con anagrafica_id=$ANAGRAFICA_ID per vedere tutti i campi disponibili..."
echo ""
RESPONSE=$(curl -s \  -H "Accept: application/json" \  -H "Authorization: Bearer ${TOKEN}" \  "${YDEA_BASE_URL}/tickets?limit=50")
MATCHING_TICKETS=$(
echo "$RESPONSE" | jq --arg aid "$ANAGRAFICA_ID" '[.objs[] | select(.anagrafica_id == ($aid|tonumber))]')
COUNT=$(
echo "$MATCHING_TICKETS" | jq 'length')
echo "Trovati $COUNT ticket con questa anagrafica"
if [[ "$COUNT" -gt 0 ]]; then
    echo ""  
echo "Primo ticket trovato (per analisi campi):"  
echo "$MATCHING_TICKETS" | jq '.[0]'  
echo ""    
echo "Tutte le chiavi disponibili nei ticket di questa anagrafica:"  
echo "$MATCHING_TICKETS" | jq '[.[].keys[]] | unique | sort[]'  
echo ""    
# Cerca campi custom o sla  
echo "Valori customAttributes nei ticket di questa anagrafica:"  
echo "$MATCHING_TICKETS" | jq '[.[].customAttributes // {}] | unique'fi
echo ""
echo "Ô£à Esplorazione completata!"

CORRUPTED_550a91e664c448978b1c63856150c1e7

