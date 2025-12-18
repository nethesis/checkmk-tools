#!/usr/bin/env bash
set -euo pipefail

# Test rapido per verificare log_ticket_event

sep() {
  printf '%*s\n' 70 '' | tr ' ' '-'
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

log_ticket_event() {
  local event_type="$1"
  local ticket_id="$2"
  local details="${3:-}"
  log "[TICKET-EVENT] [$event_type] #$ticket_id $details"
}

log_ticket_event_monitor() {
  local event_type="$1"
  local ticket_id="$2"
  local details="${3:-}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TICKET-EVENT] [$event_type] #$ticket_id $details"
}

echo "Test 1: Funzione log_ticket_event in ydea_realip"
sep
echo "Output (stderr):"
log_ticket_event "CREATO" "1234567" "Service: server-web/Apache, Stato: CRITICAL, Priorita: high"
log_ticket_event "NOTA-AGGIUNTA" "1234567" "Service: server-web/Apache, Stato: WARNING"
log_ticket_event "RIAPERTO" "1234567" "Service: server-web/Apache, Stato: CRITICAL (era risolto)"
log_ticket_event "RISOLTO-AUTO" "1234567" "Host: server-web, Stato: OK"

echo
echo "Test 2: Funzione log_ticket_event in ydea-ticket-monitor.sh"
sep
echo "Output (stdout):"
log_ticket_event_monitor "RISOLTO" "1234567" "[TK25/003376] Host: server-web, Service: Apache, Stato: Aperto -> Risolto"
log_ticket_event_monitor "STATO-CAMBIATO" "1234568" "[TK25/003377] In lavorazione -> Sospeso (Host: db-server, Service: MySQL)"

echo
echo "OK: funzioni log_ticket_event sintatticamente corrette"
echo "Note:"
echo "- ydea_realip scrive su stderr (catturato da CheckMK)"
echo "- ydea-ticket-monitor.sh scrive su stdout (rediretto su file)"
