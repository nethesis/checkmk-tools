#!/usr/bin/env bash
set -euo pipefail

TOOLKIT_DIR="${YDEA_TOOLKIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
YDEA_TOOLKIT="${TOOLKIT_DIR%/}/ydea-toolkit.sh"
YDEA_ENV="${TOOLKIT_DIR%/}/.env"

STATE_FILE="${YDEA_HEALTH_STATE_FILE:-/tmp/ydea_health_state.json}"
MAIL_SCRIPT="${YDEA_MAIL_SCRIPT:-/omd/sites/monitoring/local/share/check_mk/notifications/mail_ydea_down}"

ALERT_EMAIL="${YDEA_ALERT_EMAIL:-}"
FAILURE_THRESHOLD="${YDEA_FAILURE_THRESHOLD:-3}"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }

init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        printf '{"status":"unknown","last_check":0,"consecutive_failures":0,"last_failure":0,"notified":false}\n' >"$STATE_FILE"
    fi
}

get_state() {
    local field="$1"
    jq -r ".${field} // empty" "$STATE_FILE" 2>/dev/null || true
}

update_state() {
    local status="$1"
    local consecutive_failures="$2"
    local notified="$3"
    local now
    now="$(date -u +%s)"
    jq -n \
        --arg status "$status" \
        --argjson now "$now" \
        --argjson failures "$consecutive_failures" \
        --argjson notified "$notified" \
        --argjson last_failure "$( [[ "$status" == "down" ]] && echo "$now" || echo "$(get_state last_failure | sed 's/[^0-9]//g' || echo 0)" )" \
        '{status:$status,last_check:$now,consecutive_failures:$failures,last_failure:$last_failure,notified:$notified}' \
        >"$STATE_FILE"
}

send_email_alert() {
    local subject="$1"
    local body="$2"

    if [[ -z "$ALERT_EMAIL" ]]; then
        log "No ALERT_EMAIL configured; skipping email"
        return 0
    fi

    if [[ -x "$MAIL_SCRIPT" ]]; then
        export NOTIFY_HOSTNAME="ydea.cloud"
        export NOTIFY_HOSTADDRESS="my.ydea.cloud"
        export NOTIFY_WHAT="HOST"
        export NOTIFY_HOSTSTATE="DOWN"
        export NOTIFY_HOSTOUTPUT="$subject"
        export NOTIFY_CONTACTEMAIL="$ALERT_EMAIL"
        export NOTIFY_DATE="$(date '+%Y-%m-%d')"
        export NOTIFY_SHORTDATETIME="$(date '+%Y-%m-%d %H:%M:%S')"
        "$MAIL_SCRIPT" >/dev/null 2>&1 || true
        return 0
    fi

    if command -v mail >/dev/null 2>&1; then
        printf '%s\n' "$body" | mail -s "$subject" "$ALERT_EMAIL"
        return 0
    fi

    log "No mail sender available; skipping email"
    return 0
}

test_ydea() {
    if [[ -f "$YDEA_ENV" ]]; then
        # shellcheck disable=SC1090
        source "$YDEA_ENV"
    fi
    if [[ ! -f "$YDEA_TOOLKIT" ]]; then
        log "ERROR: ydea-toolkit.sh not found: $YDEA_TOOLKIT"
        return 1
    fi
    # shellcheck disable=SC1090
    source "$YDEA_TOOLKIT"
    need jq
    need curl
    ensure_token >/dev/null 2>&1
    ydea_api GET "/tickets?limit=1" >/dev/null 2>&1
}

main() {
    init_state
    local current_status failures notified
    current_status="$(get_state status)"
    failures="$(get_state consecutive_failures)"
    notified="$(get_state notified)"
    failures="${failures:-0}"
    notified="${notified:-false}"

    log "Checking Ydea API health..."

    if test_ydea; then
        log "OK: Ydea reachable"
        if [[ "$current_status" == "down" && "$notified" == "true" ]]; then
            send_email_alert "[RECOVERY] Ydea API reachable" "Ydea API is reachable again at $(date '+%Y-%m-%d %H:%M:%S')"
        fi
        update_state "up" 0 false
        exit 0
    fi

    failures=$((failures + 1))
    log "DOWN: Ydea not reachable (failures: $failures/$FAILURE_THRESHOLD)"

    if [[ "$failures" -ge "$FAILURE_THRESHOLD" && "$notified" != "true" ]]; then
        send_email_alert "[ALERT] Ydea API down" "Ydea API is not reachable at $(date '+%Y-%m-%d %H:%M:%S')."
        update_state "down" "$failures" true
    else
        update_state "down" "$failures" "$notified"
    fi
}

main

: <<'CORRUPTED_ccdd988fe90e43748340dba4479a951c'
#!/bin/bash
/usr/bin/env bash
# ydea-health-monitor.sh - Monitoraggio disponibilit├á Ydea API
# Controlla ogni 15 minuti se Ydea ├¿ raggiungibile e notifica via email se downset -euo pipefail
# ===== CONFIG =====
# Usa path assoluto per supportare esecuzione via launcher remoto
TOOLKIT_DIR="${YDEA_TOOLKIT_DIR:-/opt/ydea-toolkit}"
YDEA_TOOLKIT="${TOOLKIT_DIR}/ydea-toolkit.sh"
YDEA_ENV="${TOOLKIT_DIR}/.env"
STATE_FILE="/tmp/ydea_health_state.json"
MAIL_SCRIPT="/omd/sites/monitoring/local/share/check_mk/notifications/mail_ydea_down"
# Destinatario email per notifiche
ALERT_EMAIL="${YDEA_ALERT_EMAIL:-massimo.palazzetti@nethesis.it}"
# Soglia di errori consecutivi prima di notificare (per evitare falsi positivi)
FAILURE_THRESHOLD="${YDEA_FAILURE_THRESHOLD:-3}"
# ===== UTILITY =====log() { 
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }log_error() { 
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2; }
# Inizializza stato se non esisteinit_state() {  if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"status":"unknown","last_check":0,"consecutive_failures":0,"last_failure":"","notified":false}' > "$STATE_FILE"  fi}
# Leggi stato correnteget_state() {  local field="$1"  jq -r ".${field} // empty" "$STATE_FILE" 2>/dev/null || 
echo ""}
# Aggiorna statoupdate_state() {  local status="$1"local nowlocal nownow=$(date -u +%s)  local consecutive_failures="${2:-0}"  local notified="${3:-false}"    jq -n \    --arg status "$status" \    --arg now "$now" \    --arg failures "$consecutive_failures" \    --arg notified "$notified" \    '{status: $status, last_check: ($now|tonumber), consecutive_failures: ($failures|tonumber), notified: ($notified == "true"), last_failure: (if $status == "down" then $now
else "" end)}' \    > "$STATE_FILE"}
# ===== NOTIFICA EMAIL =====send_email_alert() {  local subject="$1"  local body="$2"    log "Invio notifica email a $ALERT_EMAIL"    
# Usa lo script mail_ydea_down se esiste, altrimenti fallback a mail command  if [[ -x "$MAIL_SCRIPT" ]]; then    
# Esporta variabili per lo script di notifica    export 
NOTIFY_HOSTNAME="ydea.cloud"    export 
NOTIFY_HOSTADDRESS="my.ydea.cloud"    export 
NOTIFY_WHAT="HOST"    export 
NOTIFY_HOSTSTATE="DOWN"    export 
NOTIFY_HOSTOUTPUT="Ydea API non raggiungibile - Impossibile effettuare login"    export 
NOTIFY_CONTACTEMAIL="$ALERT_EMAIL"    export 
NOTIFY_DATE="$(date '+%Y-%m-%d')"    export 
NOTIFY_SHORTDATETIME="$(date '+%Y-%m-%d %H:%M:%S')"        "$MAIL_SCRIPT" 2>&1 | log
else    
# Fallback: usa coman
do mail se disponibile    if command -v mail >/dev/null 2>&1; then
    echo "$body" | mail -s "$subject" "$ALERT_EMAIL"
else      log_error "N├® $MAIL_SCRIPT n├® coman
do 'mail' disponibili. Impossibile inviare notifica."      return 1    fi  fi}
# ===== TEST YDEA =====test_ydea_login() {  
# Carica ambiente  if [[ ! -f "$YDEA_ENV" ]]; then    log_error "File .env non trovato: $YDEA_ENV"    return 1  fi  source "$YDEA_ENV"    if [[ ! -x "$YDEA_TOOLKIT" ]]; then    log_error "Script ydea-toolkit.sh non trovato o non eseguibile: $YDEA_TOOLKIT"    return 1  fi    
# Testa login (con timeout)  local result  if result=$(timeout 30s "$YDEA_TOOLKIT" login 2>&1); then    return 0  else    log_error "Login fallito: $result"    return 1  fi}
# ===== MAIN LOGIC =====main() {  init_state    local current_status  current_status=$(get_state "status")  local consecutive_failures  consecutive_failures=$(get_state "consecutive_failures")  consecutive_failures=${consecutive_failures:-0}  local was_notified  was_notified=$(get_state "notified")    log "Controllo disponibilit├á Ydea API..."    if test_ydea_login; then    
# ===== YDEA UP =====    log "Ô£à Ydea API raggiungibile"        
# Se era down e abbiamo notificato, invia recovery email    if [[ "$current_status" == "down" && "$was_notified" == "true" ]]; then      log "Ydea tornato online, invio notifica di recovery"            local subject="Ô£à [RECOVERY] Ydea API - Servizio Ripristinato"      local body="Il servizio Ydea API ├¿ tornato online.Dettagli:- Data/Ora recovery: $(date '+%Y-%m-%d %H:%M:%S')- Durata down: Da controllare in logs- Ultimo check fallito: $(date -d "@$(get_state 'last_failure')" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || 
echo 'N/A')Il servizio di ticketing ├¿ nuovamente operativo.---Monitor automatico Ydea Health"            send_email_alert "$subject" "$body"    fi        
# Reset stato    update_state "up" 0 "false"
else    
# ===== YDEA DOWN =====    consecutive_failures=$((consecutive_failures + 1))    log_error "ÔØî Ydea API non raggiungibile (tentativi falliti: $consecutive_failures/$FAILURE_THRESHOLD)"        
# Notifica solo se raggiungiamo la soglia e non abbiamo gi├á notificato    if [[ $consecutive_failures -ge $FAILURE_THRESHOLD && "$was_notified" != "true" ]]; then      log "Soglia di errori raggiunta, invio notifica"            local subject="­ƒÜ¿ [ALERT] Ydea API - Servizio Non Raggiungibile"      local body="ATTENZIONE: Il servizio Ydea API non ├¿ raggiungibile.Dettagli:- Data/Ora rilevazione: $(date '+%Y-%m-%d %H:%M:%S')- Tentativi falliti consecutivi: $consecutive_failures- URL: https://my.ydea.cloud- Endpoint: /app_api_v2/loginImpatto:- Sistema di ticketing non disponibile- Alert CheckMK NON verranno convertiti in ticket Ydea- Creazione manuale ticket non possibileAzioni richieste:1. Verificare status servizio Ydea (https://status.ydea.cloud se disponibile)2. Controllare connettivit├á di rete3. Verificare credenziali API4. Contattare supporto Ydea se necessarioIl sistema continuer├á a monitorare e invier├á notifica quan
do il servizio sar├á ripristinato.---Monitor automatico Ydea HealthCheck ogni 15 minuti"            if send_email_alert "$subject" "$body"; then        log "Ô£à Notifica inviata con successo"        update_state "down" "$consecutive_failures" "true"
else        log_error "Errore invio notifica"        update_state "down" "$consecutive_failures" "false"      fi
else      
# Aggiorna solo il contatore      update_state "down" "$consecutive_failures" "$was_notified"    fi  fi}
# Esegui mainmainexit 0

CORRUPTED_ccdd988fe90e43748340dba4479a951c

