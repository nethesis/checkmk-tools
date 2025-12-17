#!/bin/bash
/usr/bin/env bash
# esempi-ydea.sh - Script di esempio per operazioni comuni
TOOLKIT="./ydea-toolkit.sh"
# Carica credenziali
if [[ -f .env ]]; then  source .env
else  
echo "ÔØî File .env non trovato. Copia .env.example in .env e compila le credenziali."
    exit 1
fi echo "=== ESEMPI DI USO YDEA TOOLKIT ==="echo
# === ESEMPIO 1: Report giornaliero ticket ===esempio_report_giornaliero() {  
echo "­ƒôè REPORT TICKET GIORNALIERO"  
echo "================================"    
# Ticket aperti  
echo "­ƒöô Ticket APERTI:"  $TOOLKIT list 100 open | jq -r '.data[] | "  
#\(.id) - \(.title) [prio: \(.priority)]"' 2>/dev/null || 
echo "Errore"    
echo    
# Ticket in corso  
echo "ÔÜÖ´©Å  Ticket IN LAVORAZIONE:"  $TOOLKIT list 100 in_progress | jq -r '.data[] | "  
#\(.id) - \(.title) [assegnato a: \(.assigned_to.name // "nessuno")]"' 2>/dev/null || 
echo "Errore"    
echo    
# Statistiche  
echo "­ƒôê STATISTICHE:"local total_openlocal total_opentotal_open=$($TOOLKIT list 1000 open | jq '.total // 0' 2>/dev/null)local total_closedlocal total_closedtotal_closed=$($TOOLKIT list 1000 closed | jq '.total // 0' 2>/dev/null)  
echo "  Aperti: $total_open"  
echo "  Chiusi: $total_closed"}
# === ESEMPIO 2: Crea ticket da monitoraggio ===esempio_ticket_monitoraggio() {  
echo "­ƒÜ¿ CREAZIONE TICKET DA ALERT"  
echo "================================"    
# Simula un alert di sistema  local hostname="server-prod-01"  local alert_type="CPU usage high"  local current_value="95%"    local title="[ALERT] $alert_type su $hostname"  local description="Alert automatico dal sistema di monitoraggio:  Hostname: $hostnameTipo alert: $alert_typeValore corrente: $current_valueData/ora: $(date '+%Y-%m-%d %H:%M:%S')Azione richiesta: Verificare carico CPU e processi in esecuzione."  
echo "Creo ticket: $title"  local resultlocal resultresult=$($TOOLKIT create "$title" "$description" "high")local ticket_idlocal ticket_idticket_id=$(
echo "$result" | jq -r '.id // empty')    if [[ -n "$ticket_id" ]]; then
    echo "Ô£à Ticket creato: 
#$ticket_id"    
echo "$result" | jq '.'  else    
echo "ÔØî Errore nella creazione"    
echo "$result"  fi}
# === ESEMPIO 3: Cerca e aggiorna ticket ===esempio_cerca_e_aggiorna() {  
echo "­ƒöì CERCA E AGGIORNA TICKET"  
echo "================================"    local query="database"    
echo "Cerco ticket contenenti: '$query'"local ticketslocal ticketstickets=$($TOOLKIT search "$query" 5)    
echo "$tickets" | jq -r '.data[]? | "  
#\(.id) - \(.title) [\(.status)]"'    
# Prendi il primo ticket (esempio)local first_idlocal first_idfirst_id=$(
echo "$tickets" | jq -r '.data[0].id // empty')    if [[ -n "$first_id" ]]; then
    echo    
echo "Aggiungo commento al ticket 
#$first_id"    $TOOLKIT comment "$first_id" "Ticket rivisto durante manutenzione programmata"  fi}
# === ESEMPIO 4: Workflow completo ===esempio_workflow_completo() {  
echo "­ƒöä WORKFLOW COMPLETO"  
echo "================================"    
# 1. Crea ticket  
echo "1´©ÅÔâú Creazione ticket..."local resultlocal resultresult=$($TOOLKIT create "Test workflow" "Ticket di test per workflow automatico" "normal")local ticket_idlocal ticket_idticket_id=$(
echo "$result" | jq -r '.id // empty')    if [[ -z "$ticket_id" ]]; then
    echo "ÔØî Errore nella creazione"    return 1  fi
echo "   Ô£à Creato ticket 
#$ticket_id"    
# 2. Recupera dettagli  
echo "2´©ÅÔâú Recupero dettagli..."  $TOOLKIT get "$ticket_id" | jq '{id, title, status, priority, created_at}'    
# 3. Aggiungi commento  
echo "3´©ÅÔâú Aggiunta commento..."  $TOOLKIT comment "$ticket_id" "Inizio lavorazione ticket"    
# 4. Aggiorna stato  
echo "4´©ÅÔâú Aggiornamento stato a 'in progress'..."  $TOOLKIT update "$ticket_id" '{"status":"in_progress"}'    
# 5. Aggiungi nota finale e chiudi  
echo "5´©ÅÔâú Aggiunta nota finale..."  $TOOLKIT comment "$ticket_id" "Lavorazione completata con successo"    
echo "6´©ÅÔâú Chiusura ticket..."  $TOOLKIT close "$ticket_id" "Test workflow completato"    
echo  
echo "Ô£à Workflow completato per ticket 
#$ticket_id"}
# === ESEMPIO 5: Export ticket in CSV ===esempio_export_csv() {  
echo "­ƒÆ¥ EXPORT TICKET IN CSV"  
echo "================================"    local output_file="tickets_$(date +%Y%m%d_%H%M%S).csv"    
echo "Esporto ticket in $output_file..."    $TOOLKIT list 1000 | jq -r '    ["ID","Titolo","Status","Priorit├á","Creato il","Assegnato a"] as $headers |    .data[] as $row |    [$row.id, $row.title, $row.status, $row.priority, $row.created_at, ($row.assigned_to.name // "N/A")] |    @csv  ' > "$output_file"    
echo "Ô£à Export completato: $output_file"  
echo "Prime 5 righe:"  head -5 "$output_file"}
# === MENU INTERATTIVO ===show_menu() {  
echo  
echo "Scegli un esempio da eseguire:"  
echo "  1) Report giornaliero ticket"  
echo "  2) Crea ticket da alert monitoraggio"  
echo "  3) Cerca e aggiorna ticket"  
echo "  4) Workflow completo (crea ÔåÆ aggiorna ÔåÆ chiudi)"  
echo "  5) Export ticket in CSV"  
echo "  0) Esci"  
echo  read -r -p "Scelta [0-5]: " choice    case $choice in    1) esempio_report_giornaliero ;;    2) esempio_ticket_monitoraggio ;;    3) esempio_cerca_e_aggiorna ;;    4) esempio_workflow_completo ;;    5) esempio_export_csv ;;    0) 
echo "Ciao!"; exit 0 ;;    *) 
echo "ÔØî Scelta non valida"; show_menu ;;  esac    
echo  read -r -p "Premi INVIO per continuare..."  show_menu}
# Avvio
if [[ "${1:-}" == "--menu" ]]; then  show_menu
else  
echo "Esegui con --menu per il menu interattivo"  
echo "Oppure esegui singole funzioni:"  
echo "  source $0 && esempio_report_giornaliero"  
echo "  source $0 && esempio_workflow_completo"
fi 