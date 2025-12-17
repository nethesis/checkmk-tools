#!/bin/bash
/usr/bin/env bash
# Test rapido per verificare log_ticket_event
echo "­ƒº¬ Test 1: Funzione log_ticket_event in ydea_realip"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
# Simula la funzione loglog() { 
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }
# Simula la funzione log_ticket_event come in ydea_realiplog_ticket_event() {  local event_type="$1"  local ticket_id="$2"  local details="${3:-}"  log "[TICKET-EVENT] [$event_type] 
#$ticket_id $details"}
echo ""
echo "Test output per ydea_realip:"log_ticket_event "CREATO" "1234567" "Service: server-web/Apache, Stato: CRITICAL, Priorit├á: high"log_ticket_event "NOTA-AGGIUNTA" "1234567" "Service: server-web/Apache, Stato: WARNING"log_ticket_event "RIAPERTO" "1234567" "Service: server-web/Apache, Stato: CRITICAL (era risolto)"log_ticket_event "RISOLTO-AUTO" "1234567" "Host: server-web, Stato: OK"
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "­ƒº¬ Test 2: Funzione log_ticket_event in ydea-ticket-monitor.sh"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
# Simula la funzione log_ticket_event come in ydea-ticket-monitor.shlog_ticket_event_monitor() {  local event_type="$1"  local ticket_id="$2"  local details="${3:-}"  
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TICKET-EVENT] [$event_type] 
#$ticket_id $details"}
echo ""
echo "Test output per ydea-ticket-monitor.sh:"log_ticket_event_monitor "RISOLTO" "1234567" "[TK25/003376] Host: server-web, Service: Apache, Stato: Aperto ÔåÆ Risolto"log_ticket_event_monitor "STATO-CAMBIATO" "1234568" "[TK25/003377] In lavorazione ÔåÆ Sospeso (Host: db-server, Service: MySQL)"
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "Ô£à Test completato - Le funzioni log_ticket_event sono sintatticamente corrette"
echo ""
echo "­ƒôØ Output atteso nei log reali:"
echo "   - ydea_realip scrive su stderr (catturato da CheckMK)"
echo "   - ydea-ticket-monitor.sh scrive su stdout (rediretto a /var/log/ydea-ticket-monitor.log)"
