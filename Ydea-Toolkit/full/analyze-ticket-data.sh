#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/ydea-toolkit.sh"

need jq

limit="${1:-100}"
if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 [limit]" >&2
    exit 2
fi

log_info "Fetching tickets (limit=$limit)"

resp="$(ydea_api GET "/tickets?limit=$limit")" || {
    log_error "API call failed"
    printf '%s\n' "$resp" | jq . 2>/dev/null || printf '%s\n' "$resp" >&2
    exit 1
}

dump_file="$SCRIPT_DIR/tickets-dump.json"
printf '%s' "$resp" >"$dump_file"
log_info "Dump saved to: $dump_file"

echo ""
echo "=== PRIORITA ==="
printf '%s' "$resp" | jq -r '.objs[]? | "\(.priorita_id // .prioritaId // "")\t\(.priorita // "")"' 2>/dev/null | sort -u || true

echo ""
echo "=== STATI ==="
printf '%s' "$resp" | jq -r '.objs[]? | "\(.stato_id // .statoId // "")\t\(.stato // "")"' 2>/dev/null | sort -u || true

echo ""
echo "=== TIPI (campo .tipo) ==="
printf '%s' "$resp" | jq -r '.objs[]? | select(.tipo != null and .tipo != "") | .tipo' 2>/dev/null | sort -u || true

echo ""
echo "=== ESEMPIO customAttributes (primi 5) ==="
printf '%s' "$resp" | jq -r '.objs[0:5][]? | "Ticket \(.codice // "") (#\(.id // ""))"' 2>/dev/null || true
printf '%s' "$resp" | jq '.objs[0:5][]? | .customAttributes // {}' 2>/dev/null || true

exit 0

: <<'CORRUPTED_97fb9ae5f0914e2abfd7220dc199c02c'
#!/usr/bin/env bash

set -euo pipefail

# analyze-ticket-data.sh - Analyze existing tickets to extract categories, priority and SLA
# Extracts unique IDs to understand data structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YDEA_TOOLKIT="${SCRIPT_DIR}/ydea-toolkit.sh"
echo "DEBUG: Script dir: $SCRIPT_DIR" >&2
echo "DEBUG: Toolkit path: $YDEA_TOOLKIT" >&2
if [[ ! -f "$YDEA_TOOLKIT" ]]; then
    echo "ÔØî Errore: ydea-toolkit.sh non trovato in $SCRIPT_DIR" >&2  exit 1
fi # Carica le funzioni da ydea-toolkit
# shellcheck disable=SC1090source "$YDEA_TOOLKIT"
echo "DEBUG: Toolkit caricato con successo" >&2
echo ""
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo "  ­ƒôè ANALISI DATI TICKET YDEA"
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo ""
# Verifica autenticazione
echo "­ƒôï Autenticazione..."set +eensure_token_output=$(ensure_token 2>&1)ensure_exit=$?set -e
echo "DEBUG: ensure_token exit code: $ensure_exit" >&2
echo "DEBUG: ensure_token output: $ensure_token_output" >&2
if [[ $ensure_exit -ne 0 ]]; then
    echo "ÔØî Errore autenticazione"  
echo "$ensure_token_output"
    exit 1
fi echo "Ô£à Autenticato"
echo ""
echo "­ƒôï Recupero ticket (limit 100)..."set +etickets_data=$(ydea_api GET "/tickets?limit=100" 2>&1)api_exit=$?set -e
echo "DEBUG: ydea_api exit code: $api_exit" >&2
if [[ $api_exit -ne 0 ]]; then
    echo "ÔØî Errore nel recupero ticket (exit: $api_exit)"  
echo "$tickets_data"
    exit 1
fi echo "DEBUG: Dati ricevuti, lunghezza: ${
#tickets_data}" >&2
# Salva dump completo
echo "$tickets_data" > "${SCRIPT_DIR}/tickets-dump.json"
echo "­ƒÆ¥ Dump salvato in: ${SCRIPT_DIR}/tickets-dump.json"
echo ""
# Estrai priorit├á uniche
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "­ƒÄ» PRIORIT├Ç TROVATE:"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "$tickets_data" | jq -r '.objs[] | "\(.priorita_id) ÔåÆ \(.priorita)"' | sort -u
echo ""
# Estrai stati unici
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "­ƒôï STATI TROVATI:"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "$tickets_data" | jq -r '.objs[] | "\(.stato_id) ÔåÆ \(.stato)"' | sort -u
echo ""
# Estrai tipi unici (se esistono)
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "­ƒôü TIPI TROVATI:"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "$tickets_data" | jq -r '.objs[] | select(.tipo != null) | "\(.tipo)"' | sort -u
echo ""
# Cerca campi custom attributes
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "­ƒöº CUSTOM ATTRIBUTES (primi 5 ticket):"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "$tickets_data" | jq -r '.objs[0:5] | .[] | "Ticket \(.codice):\n\(.customAttributes)\n"'
echo ""
# Cerca nei custom attributes eventuali categorie o SLA
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "­ƒöì RICERCA CATEGORIE/SLA NEI CUSTOM ATTRIBUTES:"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
# Cerca campi che contengono "categ", "sla", "premium"
echo "$tickets_data" | jq -r '  .objs[] |   select(.customAttributes != null and .customAttributes != {}) |   {    ticket: .codice,    custom: .customAttributes  }' | head -50
echo ""
# Analizza un ticket specifico per vedere tutti i campi
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "­ƒöÄ STRUTTURA COMPLETA PRIMO TICKET:"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "$tickets_data" | jq '.objs[0]' | head -100
echo ""
# Cerca ticket con "Premium" nel codice o descrizione
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "­ƒÄû´©Å  TICKET CON 'PREMIUM' O 'TK25/003209':"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "$tickets_data" | jq -r '  .objs[] |   select(    (.codice // "" | test("TK25/003209"; "i")) or    (.titolo // "" | test("premium"; "i")) or    (.descrizione // "" | test("premium"; "i"))  ) |   "Ticket: \(.codice)\nTitolo: \(.titolo)\nCustom: \(.customAttributes)\n"' | head -50
echo ""
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo "  ­ƒÆí SUGGERIMENTI"
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"
echo ""
echo "Le informazioni su categorie e SLA potrebbero essere:"
echo "  1. Nei customAttributes dei ticket"
echo "  2. Recuperabili tramite endpoint specifico del singolo ticket"
echo "  3. Accessibili solo dall'interfaccia web"
echo ""
echo "Prossimi passi:"
echo "  1. Controlla i customAttributes sopra per vedere se ci sono"
echo "     campi relativi a categoria/SLA"
echo "  2. Prova a recuperare un ticket specifico con ID noto"
echo "  3. Contatta il supporto Ydea per documentazione API completa"
echo ""

CORRUPTED_97fb9ae5f0914e2abfd7220dc199c02c

