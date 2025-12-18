#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/ydea-toolkit.sh"

need jq

pages="${1:-10}"
needle_regex="${2:-Premium|Mon|premium|mon}"
out_dir="${YDEA_OUT_DIR:-/tmp}"
out_all="$out_dir/ydea-contracts.json"
out_match="$out_dir/ydea-contracts-matching.json"

log_info "Searching contracts for regex: $needle_regex (pages=$pages)"

fetch_contracts() {
    local endpoint="$1"
    local all='[]'
    for ((page=1; page<=pages; page++)); do
        log_info "GET $endpoint page=$page"
        resp="$(ydea_api GET "/${endpoint}?limit=100&page=${page}" 2>/dev/null || echo '{"objs":[]}')"
        count="$(printf '%s' "$resp" | jq -r '.objs | length' 2>/dev/null || echo 0)"
        if [[ "$count" == "0" ]]; then
            break
        fi
        objs="$(printf '%s' "$resp" | jq '.objs' 2>/dev/null || echo '[]')"
        all="$(jq -n --argjson a "$all" --argjson b "$objs" '$a + $b')"
    done
    printf '%s' "$all"
}

contracts="$(fetch_contracts 'contratti')"
if [[ "$(printf '%s' "$contracts" | jq 'length' 2>/dev/null || echo 0)" == "0" ]]; then
    log_warn "No contracts via /contratti; trying /contracts"
    contracts="$(fetch_contracts 'contracts')"
fi

printf '%s\n' "$contracts" >"$out_all"

matches="$(printf '%s' "$contracts" | jq --arg re "$needle_regex" '[.[] | select((. | tostring) | test($re))]')"
printf '%s\n' "$matches" >"$out_match"

log_info "Total contracts: $(jq -r 'length' "$out_all" 2>/dev/null || echo 0)"
log_info "Matching contracts: $(jq -r 'length' "$out_match" 2>/dev/null || echo 0)"
log_info "Saved: $out_all"
log_info "Saved: $out_match"

exit 0

: <<'CORRUPTED_4290558e7d434dd39657f9f1c76bada2'
#!/bin/bash
/usr/bin/env bash
# search-sla-in-contracts.sh - Cerca SLA Premium_Mon nei contrattiset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"source "$SCRIPT_DIR/ydea-toolkit.sh"
echo "­ƒöì Ricerca 'Premium_Mon' nei contratti..."
echo ""ensure_token
TOKEN="$(load_token)"
# Recupera tutti i contratti (paginati)
echo "­ƒôí Recupero contratti..."
ALL_CONTRACTS="/tmp/all-contracts.json"
echo "[]" > "$ALL_CONTRACTS"for PAGE in $(seq 1 10); do  
echo -n "   Pagina $PAGE... "    
RESPONSE=$(curl -s \    -H "Accept: application/json" \    -H "Authorization: Bearer ${TOKEN}" \    "${YDEA_BASE_URL}/contratti?limit=100&page=${PAGE}")  if ! 
echo "$RESPONSE" | jq -e '.objs' >/dev/null 2>&1; then
    echo "Fine"    break  fi  
COUNT=$(
echo "$RESPONSE" | jq -r '.objs | length')  if [[ "$COUNT" -eq 0 ]]; then
    echo "Fine"    break  fi
echo "$COUNT contratti"  
echo "$RESPONSE" | jq '.objs' >> "$ALL_CONTRACTS.tmp"
done # Combina tutti i risultatijq -s 'add' "$ALL_CONTRACTS.tmp" 2>/dev/null > "$ALL_CONTRACTS" || 
echo "[]" > "$ALL_CONTRACTS"rm -f "$ALL_CONTRACTS.tmp"
TOTAL=$(jq 'length' "$ALL_CONTRACTS")
echo ""
echo "   Totale contratti raccolti: $TOTAL"
echo ""
# Cerca "Premium" o "Mon" nei contratti
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "CONTRATTI CONTENENTI 'Premium' o 'Mon'"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
MATCHING=$(jq '[.[] | select((. | tostring) | test("Premium|Mon|premium|mon"))]' "$ALL_CONTRACTS")
MATCHING_COUNT=$(
echo "$MATCHING" | jq 'length')
echo "Trovati: $MATCHING_COUNT contratti"
if [[ "$MATCHING_COUNT" -gt 0 ]]; then
    echo ""  
echo "$MATCHING" | jq '.[]'else  
echo "   Nessun contratto trovato con 'Premium' o 'Mon'"fi
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "DETTAGLIO DI UN CONTRATTO (per vedere struttura completa)"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
# Prendi il primo contratto e fai GET dettagliato
FIRST_ID=$(jq -r '.[0].id' "$ALL_CONTRACTS")
if [[ -n "$FIRST_ID" && "$FIRST_ID" != "null" ]]; then
    echo "Recupero dettagli contratto ID: $FIRST_ID..."  
echo ""    
DETAIL=$(curl -s \    -H "Accept: application/json" \    -H "Authorization: Bearer ${TOKEN}" \    "${YDEA_BASE_URL}/contratti/${FIRST_ID}")    
echo "$DETAIL" | jq '.'    
echo ""  
echo "Tutte le chiavi disponibili in un contratto:"  
echo "$DETAIL" | jq 'keys[]' | sort
fi
echo ""
echo "­ƒÆ¥ File salvato: $ALL_CONTRACTS"
echo ""
echo "Ô£à Ricerca completata!"

CORRUPTED_4290558e7d434dd39657f9f1c76bada2

