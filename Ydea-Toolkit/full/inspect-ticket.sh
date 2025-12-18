#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/ydea-toolkit.sh"

need jq

ticket_id="${1:-}"
if [[ -z "$ticket_id" ]]; then
  echo "Usage: $0 <ticket_id>" >&2
  exit 2
fi

log_info "Inspect ticket #$ticket_id (limit=100)"

resp="$(ydea_api GET "/tickets?limit=100")" || {
  log_error "API call failed"
  printf '%s\n' "$resp" | jq . 2>/dev/null || printf '%s\n' "$resp" >&2
  exit 1
}

ticket_json="$(printf '%s' "$resp" | jq --arg tid "$ticket_id" -c '.objs[]? | select(.id == ($tid|tonumber))' 2>/dev/null || true)"

if [[ -z "$ticket_json" || "$ticket_json" == "null" ]]; then
  log_warn "Ticket #$ticket_id not found in the first 100 tickets"
  echo "Available tickets (first 20):" >&2
  printf '%s' "$resp" | jq -r '.objs[]? | "\(.id) - \(.codice // "N/A") - \(.titolo // "")"' 2>/dev/null | head -n 20 >&2 || true
  exit 1
fi

printf '%s\n' "$ticket_json" | jq .

exit 0

: <<'CORRUPTED_08ee04b901924b0fb6eb2d20453338cd'
#!/usr/bin/env bash

set -euo pipefail

# inspect-ticket.sh - Inspect a single ticket for complete structure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ydea-toolkit.sh"

TICKET_ID="${1:-}"

if [[ -z "$TICKET_ID" ]]; then
  echo "Usage: $0 <ticket_id>"
  echo ""
  echo "Example:"
  echo "  $0 1486125"
  exit 1
fi

echo "Inspecting ticket #$TICKET_ID..."
echo ""

# Ensure token
ensure_token
TOKEN="$(load_token)"

# Direct API call to get ticket list and filter by ID
echo "API Call: GET /tickets?limit=100"
echo ""

RESPONSE=$(curl -s -w '\n%{http_code}' \
  -H "Accept: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  "${YDEA_BASE_URL}/tickets?limit=100")

HTTP_BODY="$(echo "$RESPONSE" | sed '$d')"
HTTP_CODE="$(echo "$RESPONSE" | tail -n1)"

echo "HTTP Status: $HTTP_CODE"
echo ""

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR in API call"
  echo "$HTTP_BODY" | jq . 2>/dev/null || echo "$HTTP_BODY"
  exit 1
fi

# Filter for specific ticket
TICKET_DATA=$(echo "$HTTP_BODY" | jq --arg tid "$TICKET_ID" '.objs[] | select(.id == ($tid|tonumber))' || true)

if [[ -z "$TICKET_DATA" || "$TICKET_DATA" == "null" ]]; then
  echo "Ticket #$TICKET_ID not found in results"
  echo ""
  echo "Available tickets:"
  echo "$HTTP_BODY" | jq -r '.objs[] | "\(.id) - \(.codice) - \(.titolo)"' | head -20
  exit 1
fi

echo "Ticket found!"
echo ""
echo "=== COMPLETE TICKET STRUCTURE ==="
echo ""

# Show formatted JSON
echo "$TICKET_DATA" | jq '.'

echo ""
echo "=== END ==="

exit 0
echo "CAMPI CHIAVE ESTRATTI"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
echo "­ƒôï Info Base:"
echo "   ID: $(
echo "$TICKET_DATA" | jq -r '.id')"
echo "   Codice: $(
echo "$TICKET_DATA" | jq -r '.codice // "N/A"')"
echo "   Titolo: $(
echo "$TICKET_DATA" | jq -r '.titolo // "N/A"')"
echo ""
echo "­ƒôè Priorit├á:"
echo "   Priorit├á: $(
echo "$TICKET_DATA" | jq -r '.priorita // "N/A"')"
echo "   Priorit├á ID: $(
echo "$TICKET_DATA" | jq -r '.priorita_id // .prioritaId // "N/A"')"
echo ""
echo "­ƒôé Categorie:"
echo "   Categoria: $(
echo "$TICKET_DATA" | jq -r '.categoria // "N/A"')"
echo "   Categoria ID: $(
echo "$TICKET_DATA" | jq -r '.categoria_id // .categoriaId // "N/A"')"
echo "   Sotto-categoria: $(
echo "$TICKET_DATA" | jq -r '.sottocategoria // .sotto_categoria // "N/A"')"
echo "   Sotto-categoria ID: $(
echo "$TICKET_DATA" | jq -r '.sottocategoria_id // .sottocategoriaId // "N/A"')"
echo ""
echo "ÔÅ▒´©Å  SLA:"
echo "   SLA: $(
echo "$TICKET_DATA" | jq -r '.sla // "N/A"')"
echo "   SLA ID: $(
echo "$TICKET_DATA" | jq -r '.sla_id // .slaId // "N/A"')"
echo "   SLA Nome: $(
echo "$TICKET_DATA" | jq -r '.sla_nome // .slaNome // "N/A"')"
echo ""
echo "­ƒôî Stato:"
echo "   Stato: $(
echo "$TICKET_DATA" | jq -r '.stato // "N/A"')"
echo "   Stato ID: $(
echo "$TICKET_DATA" | jq -r '.stato_id // .statoId // "N/A"')"
echo ""
echo "­ƒöº Custom Attributes:"if 
echo "$TICKET_DATA" | jq -e '.customAttributes' >/dev/null 2>&1; then
    echo "$TICKET_DATA" | jq '.customAttributes'else  
echo "   Nessun custom attribute trovato"
fi
echo ""
echo "­ƒæñ Assegnazione:"
echo "   Assegnato A: $(
echo "$TICKET_DATA" | jq -r '.assegnatoA // .assegnato_a // "N/A"')"
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "TUTTE LE CHIAVI DISPONIBILI NEL JSON"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
echo "$TICKET_DATA" | jq -r 'keys[]' | sort
echo ""
echo "Ô£à Ispezione completata!"
echo ""
echo "­ƒÆí Suggerimento: Per vedere solo i campi che contengono 'categoria' o 'sla':"
echo "   
echo '$TICKET_DATA' | jq 'to_entries | map(select(.key | test(\"categoria|sla|categor\"; \"i\")))'"

CORRUPTED_08ee04b901924b0fb6eb2d20453338cd

