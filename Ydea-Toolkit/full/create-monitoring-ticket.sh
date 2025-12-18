#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/ydea-toolkit.sh"

need jq

CONFIG_FILE="$SCRIPT_DIR/../config/premium-mon-config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Config not found: $CONFIG_FILE"
    exit 1
fi

cmk_host="${1:-}"
cmk_service="${2:-}"
cmk_state="${3:-}"
cmk_output="${4:-}"
cmk_hostip="${5:-}"

if [[ -z "$cmk_host" || -z "$cmk_state" || -z "$cmk_output" ]]; then
    cat >&2 <<USAGE
Usage: $0 <HOST> <SERVICE> <STATE> <OUTPUT> [HOST_IP]

Example:
    $0 'mail.example.com' 'HTTP' 'CRITICAL' 'Connection timeout' '1.2.3.4'
USAGE
    exit 2
fi

anagrafica_id="$(jq -r '.anagrafica_id' "$CONFIG_FILE")"
priorita_id="$(jq -r '.priorita_id' "$CONFIG_FILE")"
fonte="$(jq -r '.fonte' "$CONFIG_FILE")"
sla_id="$(jq -r '.sla_id // empty' "$CONFIG_FILE")"
assegnatoa_id="$(jq -r '.assegnatoa_id // empty' "$CONFIG_FILE")"
default_tipo="$(jq -r '.default_tipo' "$CONFIG_FILE")"

determine_tipo() {
    local hay
    hay="$(printf '%s %s %s' "$cmk_service" "$cmk_output" "$cmk_host" | tr '[:upper:]' '[:lower:]')"
    local key keyword
    while IFS= read -r key; do
        while IFS= read -r keyword; do
            [[ -z "$keyword" ]] && continue
            if printf '%s' "$hay" | grep -qi -- "$keyword"; then
                jq -r ".tipologie.${key}.tipo_ydea" "$CONFIG_FILE"
                return 0
            fi
        done < <(jq -r ".tipologie.${key}.keywords[]?" "$CONFIG_FILE")
    done < <(jq -r '.tipologie | keys[]' "$CONFIG_FILE")
    printf '%s' "$default_tipo"
}

tipo="$(determine_tipo)"

title="[${cmk_state}] ${cmk_host}"
if [[ -n "$cmk_service" && "$cmk_service" != "Host" ]]; then
    title+=" - ${cmk_service}"
fi
if [[ -n "$cmk_hostip" ]]; then
    title+=" [IP=${cmk_hostip}]"
fi

descrizione="Allarme generato da CheckMK (creazione automatica)"

note_privata="Allarme CheckMK\n\nHost: ${cmk_host}\nService: ${cmk_service:-Host}\nState: ${cmk_state}\nIP: ${cmk_hostip:-N/A}\nTimestamp: $(date '+%Y-%m-%d %H:%M:%S')\n\nOutput:\n${cmk_output}\n"

log_info "Creating ticket: $title"
log_debug "Tipo: $tipo"

body="$(jq -n \
    --arg titolo "$title" \
    --arg descrizione "$descrizione" \
    --arg fonte "$fonte" \
    --arg tipo "$tipo" \
    --argjson anagrafica "$anagrafica_id" \
    --argjson priorita "$priorita_id" \
    '{titolo:$titolo, descrizione:$descrizione, anagrafica_id:$anagrafica, priorita_id:$priorita, fonte:$fonte, tipo:$tipo}')"

if [[ -n "$sla_id" ]]; then
    body="$(printf '%s' "$body" | jq --argjson sid "$sla_id" '. + {sla_id:$sid}')"
fi
if [[ -n "$assegnatoa_id" ]]; then
    body="$(printf '%s' "$body" | jq --argjson uid "$assegnatoa_id" '. + {assegnatoa: [$uid]}')"
fi

resp="$(ydea_api POST "/ticket" "$body")" || {
    log_error "Ticket creation failed"
    printf '%s\n' "$resp" | jq . 2>/dev/null || printf '%s\n' "$resp" >&2
    exit 1
}

ticket_id="$(printf '%s' "$resp" | jq -r '.id // .ticket_id // .data.id // empty' 2>/dev/null || true)"
ticket_code="$(printf '%s' "$resp" | jq -r '.codice // .code // .data.codice // empty' 2>/dev/null || true)"

if [[ -z "$ticket_id" || "$ticket_id" == "null" ]]; then
    log_error "Could not extract ticket id from response"
    printf '%s\n' "$resp" | jq . 2>/dev/null || printf '%s\n' "$resp" >&2
    exit 1
fi

log_info "Ticket created: id=$ticket_id code=${ticket_code:-N/A}"

# Add private note (best-effort)
note_user_id="${YDEA_USER_ID_CREATE_NOTE}"
note_body="$(jq -n \
    --argjson tid "$ticket_id" \
    --arg desc "$note_privata" \
    --argjson uid "$note_user_id" \
    '{ticket_id:$tid, atk:{descrizione:$desc, pubblico:false, creatoda:$uid}}')"

if ydea_api POST "/ticket/atk" "$note_body" >/dev/null 2>&1; then
    log_info "Private note added"
else
    log_warn "Private note not added (ticket created anyway)"
fi

# Track
track_ticket "$ticket_id" "${ticket_code:-TK-$ticket_id}" "$cmk_host" "${cmk_service:-Host}" "$cmk_output" || true

# Output for CheckMK local scripts
printf 'TICKET_ID=%s\n' "$ticket_id"
printf 'TICKET_CODE=%s\n' "${ticket_code:-}"

exit 0

: <<'CORRUPTED_41e54a724c8c43efb80cd681c66a3c59'
#!/usr/bin/env bash

set -euo pipefail

# create-monitoring-ticket.sh - Create Ydea ticket from CheckMK alarm
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"source "$SCRIPT_DIR/ydea-toolkit.sh"
# Carica configurazione Premium_Mon
CONFIG_FILE="$SCRIPT_DIR/../config/premium-mon-config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then  log_error "File configurazione non trovato: $CONFIG_FILE"
    exit 1
fi # Leggi parametri da Check
MKCMK_HOST="${1:-}"
CMK_SERVICE="${2:-}"
CMK_STATE="${3:-}"
CMK_OUTPUT="${4:-}"
CMK_HOSTIP="${5:-}"if [[ -z "$CMK_HOST" ]]; then
    echo "ÔØî Uso: $0 <HOST> <SERVICE> <STATE> <OUTPUT> [HOST_IP]"  
echo ""  
echo "Esempio:"  
echo "  $0 'mail.example.com' 'HTTP' 'CRITICAL' 'Connection timeout' '1.2.3.4'"
    exit 1filog_info "=== Creazione ticket da CheckMK ==="log_info "Host: $CMK_HOST"log_info "Service: $CMK_SERVICE"log_info "State: $CMK_STATE"log_info "Output: $CMK_OUTPUT"log_info "IP: ${CMK_HOSTIP:-N/A}"
# Carica configurazione
ANAGRAFICA_ID=$(jq -r '.anagrafica_id' "$CONFIG_FILE")
PRIORITA_ID=$(jq -r '.priorita_id' "$CONFIG_FILE")
FONTE=$(jq -r '.fonte' "$CONFIG_FILE")
SLA_ID=$(jq -r '.sla_id // empty' "$CONFIG_FILE")
ASSEGNATOA_ID=$(jq -r '.assegnatoa_id // empty' "$CONFIG_FILE")
DEFAULT_TIPO=$(jq -r '.default_tipo' "$CONFIG_FILE")log_debug "Config: anagrafica=$ANAGRAFICA_ID, priorita=$PRIORITA_ID, sla=$SLA_ID, assegnatoa=$ASSEGNATOA_ID"
# Determina tipologia in base al servizio/hostdetermine_tipo() {  local service_lower=$(
echo "$CMK_SERVICE $CMK_OUTPUT $CMK_HOST" | tr '[:upper:]' '[:lower:]')    
# Controlla ogni tipologia  while 
IFS= read -r tipologia_key; do    
# Leggi keywords per questa tipologia    local keywords=$(jq -r ".tipologie.${tipologia_key}.keywords[]" "$CONFIG_FILE" 2>/dev/null || 
echo "")        
# Controlla se qualche keyword matcha    while 
IFS= read -r keyword; do      [[ -z "$keyword" ]] && continue      if 
echo "$service_lower" | grep -qi "$keyword"; then        jq -r ".tipologie.${tipologia_key}.tipo_ydea" "$CONFIG_FILE"        return 0      fi    done <<< "$keywords"  done < <(jq -r '.tipologie | keys[]' "$CONFIG_FILE")    
# Default se non trovato match  
echo "$DEFAULT_TIPO"}
TIPO=$(determine_tipo)log_info "Tipologia determinata: $TIPO"
# Costruisci titolo e descrizione
if [[ "$CMK_STATE" == "DOWN" || "$CMK_STATE" == "CRITICAL" ]]; then
    STATE_ICON="­ƒö┤"elif [[ "$CMK_STATE" == "WARNING" ]]; then
    STATE_ICON="ÔÜá´©Å"else  
STATE_ICON="Ôä╣´©Å"fi
TITOLO="[${CMK_STATE}] ${CMK_HOST}"if [[ -n "$CMK_SERVICE" && "$CMK_SERVICE" != "Host" ]]; then
    TITOLO="${TITOLO} - ${CMK_SERVICE}"fi
if [[ -n "$CMK_HOSTIP" ]]; then
    TITOLO="${TITOLO} [
IP=${CMK_HOSTIP}]"fi
# Descrizione generica
DESCRIZIONE="Allarme da sistema di monitoraggio CheckMK"
# Dettagli allarme per nota privata
NOTA_PRIVATA="<p><strong>${STATE_ICON} Allarme da CheckMK Monitoring</strong></p><ul><li><strong>Host:</strong> ${CMK_HOST}</li><li><strong>Service:</strong> ${CMK_SERVICE:-Host Check}</li><li><strong>Stato:</strong> ${CMK_STATE}</li><li><strong>IP:</strong> ${CMK_HOSTIP:-N/A}</li><li><strong>Data/Ora:</strong> $(date '+%Y-%m-%d %H:%M:%S')</li></ul><p><strong>Output:</strong></p><pre>${CMK_OUTPUT}</pre><p><em>Ticket creato automaticamente dal sistema di monitoraggio CheckMK</em></p>"log_info "Titolo: $TITOLO"
# Crea ticket tramite APIlog_info "Creazione ticket in corso..."
# Costruisci corpo ticket base
TICKET_BODY_BASE=$(jq -n \  --arg titolo "$TITOLO" \  --arg descrizione "$DESCRIZIONE" \  --argjson anagrafica "$ANAGRAFICA_ID" \  --argjson priorita "$PRIORITA_ID" \  --arg fonte "$FONTE" \  --arg tipo "$TIPO" \  '{    titolo: $titolo,    descrizione: $descrizione,    anagrafica_id: $anagrafica,    priorita_id: $priorita,    fonte: $fonte,    tipo: $tipo  }')
# Aggiungi campi opzionali se presenti
TICKET_BODY="$TICKET_BODY_BASE"
if [[ -n "$ASSEGNATOA_ID" ]]; then
    TICKET_BODY=$(
echo "$TICKET_BODY" | jq --argjson uid "$ASSEGNATOA_ID" '. + {assegnatoa: [$uid]}')fi
if [[ -n "$SLA_ID" ]]; then
    TICKET_BODY=$(
echo "$TICKET_BODY" | jq --argjson sid "$SLA_ID" '. + {sla_id: $sid}')filog_debug "Body: $TICKET_BODY"
# Chiamata API per creare ticketensure_token
RESPONSE=$(ydea_api POST "/ticket" "$TICKET_BODY")
# Estrai ID ticket creato
TICKET_ID=$(
echo "$RESPONSE" | jq -r '.id // .ticket_id // .data.id // empty')
TICKET_CODE=$(
echo "$RESPONSE" | jq -r '.codice // .code // .data.codice // empty')
if [[ -n "$TICKET_ID" && "$TICKET_ID" != "null" ]]; then  log_success "Ô£à Ticket creato con successo!"  log_success "   ID: $TICKET_ID"  log_success "   Codice: ${TICKET_CODE:-N/A}"  log_success "   Link: https://my.ydea.cloud/ticket/${TICKET_ID}"    
# Aggiungi nota privata con dettagli allarme  log_info "Aggiunta nota privata con dettagli allarme..."  
NOTE_USER_ID="${ASSEGNATOA_ID:-12336}"  
NOTE_BODY=$(jq -n \    --argjson tid "$TICKET_ID" \    --arg desc "$NOTA_PRIVATA" \    --argjson uid "$NOTE_USER_ID" \    '{ticket_id: $tid, atk: {descrizione: $desc, pubblico: false, creatoda: $uid}}')    if ydea_api POST "/ticket/atk" "$NOTE_BODY" >/dev/null 2>&1; then    log_success "Ô£à Nota privata aggiunta"
else    log_warn "ÔÜá´©Å  Nota privata non aggiunta (ticket comunque creato)"  fi    
# Traccia il ticket  track_ticket "$TICKET_ID" "${TICKET_CODE:-TK-${TICKET_ID}}" "$CMK_HOST" "$CMK_SERVICE" "$CMK_OUTPUT"    
# Output per CheckMK  
echo "
TICKET_ID=$TICKET_ID"  
echo "
TICKET_CODE=$TICKET_CODE"
    exit 0
else  log_error "ÔØî Errore nella creazione del ticket"  
echo "$RESPONSE" | jq '.' 2>/dev/null || 
echo "$RESPONSE"
    exit 1
fi 
CORRUPTED_41e54a724c8c43efb80cd681c66a3c59

