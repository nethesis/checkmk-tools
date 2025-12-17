#!/bin/bash
/usr/bin/env bash
# ydea-discover-sla-ids.sh ÔÇö Scopri ID per categorie, sottocategorie e SLA personalizzata
# Utilizzato per trovare gli ID necessari per la gestione ticket con SLA Premium_Monset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YDEA_TOOLKIT="${SCRIPT_DIR}/ydea-toolkit.sh"
# Verifica che ydea-toolkit esista
if [[ ! -f "$YDEA_TOOLKIT" ]]; then
    echo "ÔØî Errore: ydea-toolkit.sh non trovato in $SCRIPT_DIR"
    exit 1
fi # Carica le funzioni da ydea-toolkit
# shellcheck disable=SC1090source "$YDEA_TOOLKIT"
# ===== Configurazione =====
OUTPUT_FILE="${SCRIPT_DIR}/sla-premium-mon-ids.json"
# Categorie da cercare
MACRO_CATEGORY="Premium_Mon"declare -a 
SUBCATEGORIES=(  "Centrale telefonica NethVoice"  "Firewall UTM NethSecurity"  "Collaboration Suite NethService"  "Computer client"  "Server"  "Apparati di rete - Networking"  "Hypervisor"  "Consulenza tecnica specialistica")
SLA_NAME="TK25/003209 SLA Personalizzata"
# ===== Funzioni Helper =====print_header() {  
echo ""  
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"  
echo "  $1"  
echo "ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ"  
echo ""}
# ===== Discovery Categorie =====discover_categories() {  print_header "­ƒöì DISCOVERY CATEGORIE E SOTTOCATEGORIE"    log_info "Recupero lista categorie da Ydea API..."    
# Chiama API per ottenere tutte le categorie  local categories_data  categories_data=$(ydea_api GET "/categories" 2>/dev/null || 
echo '{"objs":[]}')    if [[ -z "$categories_data" || "$categories_data" == '{"objs":[]}' ]]; then    log_error "Nessuna categoria trovata o errore nella chiamata API"    return 1  fi    
# Salva i dati completi per debug  
echo "$categories_data" > "${SCRIPT_DIR}/categories-full-dump.json"  log_debug "Dump completo categorie salvato in categories-full-dump.json"    
# Cerca la macro categoria Premium_Mon  local macro_cat_id  macro_cat_id=$(
echo "$categories_data" | jq -r --arg name "$MACRO_CATEGORY" '    .objs[]? | select(.nome == $name) | .id  ' | head -1)    if [[ -z "$macro_cat_id" || "$macro_cat_id" == "null" ]]; then    log_warn "Macro categoria '$MACRO_CATEGORY' non trovata direttamente"    log_info "Elenco tutte le categorie disponibili:"    
echo "$categories_data" | jq -r '.objs[]? | "\(.id) ÔåÆ \(.nome)"'    macro_cat_id=""
else    log_success "Macro categoria '$MACRO_CATEGORY' trovata ÔåÆ ID: $macro_cat_id"  fi    
# Cerca le sottocategorie  declare -A subcategory_ids  local found_count=0    
echo ""  log_info "Ricerca sottocategorie..."  
echo ""    for subcat in "${SUBCATEGORIES[@]}"; do    local subcat_id    subcat_id=$(
echo "$categories_data" | jq -r --arg name "$subcat" '      .objs[]? | select(.nome == $name) | .id    ' | head -1)        if [[ -n "$subcat_id" && "$subcat_id" != "null" ]]; then      subcategory_ids["$subcat"]="$subcat_id"      
echo "  Ô£à '$subcat' ÔåÆ ID: $subcat_id"      ((found_count++))    else      
echo "  ÔØî '$subcat' ÔåÆ NON TROVATA"    fi  done
echo ""  log_info "Sottocategorie trovate: $found_count/${
#SUBCATEGORIES[@]}"    
# Costruisci JSON output per categorie  local json_output="{}"    if [[ -n "$macro_cat_id" ]]; then
    json_output=$(
echo "$json_output" | jq --arg id "$macro_cat_id" --arg name "$MACRO_CATEGORY" '      .macro_category = {id: ($id|tonumber), name: $name}    ')  fi    
# Aggiungi sottocategorie  local subcats_json="[]"  for subcat in "${!subcategory_ids[@]}"; do    local subcat_id="${subcategory_ids[$subcat]}"    subcats_json=$(
echo "$subcats_json" | jq --arg name "$subcat" --arg id "$subcat_id" '      . += [{name: $name, id: ($id|tonumber)}]    ')  done    json_output=$(
echo "$json_output" | jq --argjson subcats "$subcats_json" '    .subcategories = $subcats  ')    
echo "$json_output"}
# ===== Discovery SLA =====discover_sla() {  print_header "­ƒöì DISCOVERY SLA PERSONALIZZATA"    log_info "Recupero lista SLA da Ydea API..."    
# Chiama API per ottenere tutte le SLA  local sla_data  sla_data=$(ydea_api GET "/sla" 2>/dev/null || 
echo '{"objs":[]}')    if [[ -z "$sla_data" || "$sla_data" == '{"objs":[]}' ]]; then    log_warn "Nessuna SLA trovata o endpoint non disponibile"    
# Prova endpoint alternativo    sla_data=$(ydea_api GET "/slas" 2>/dev/null || 
echo '{"objs":[]}')  fi    
# Salva i dati completi per debug  
echo "$sla_data" > "${SCRIPT_DIR}/sla-full-dump.json"  log_debug "Dump completo SLA salvato in sla-full-dump.json"    
# Cerca la SLA specifica  local sla_id  sla_id=$(
echo "$sla_data" | jq -r --arg name "$SLA_NAME" '    .objs[]? | select(.nome == $name or .name == $name or .title == $name) | .id  ' | head -1)    if [[ -z "$sla_id" || "$sla_id" == "null" ]]; then    log_warn "SLA '$SLA_NAME' non trovata direttamente"    log_info "Elenco tutte le SLA disponibili:"    
echo "$sla_data" | jq -r '.objs[]? | "\(.id) ÔåÆ \(.nome // .name // .title)"'        
# Prova ricerca parziale su TK25/003209    log_info "Tentativo ricerca per codice 'TK25/003209'..."    sla_id=$(
echo "$sla_data" | jq -r '      .objs[]? | select(.nome // .name // .title | test("TK25/003209")) | .id    ' | head -1)        if [[ -z "$sla_id" || "$sla_id" == "null" ]]; then
    sla_id=""
else      log_success "SLA trovata tramite ricerca parziale ÔåÆ ID: $sla_id"    fi
else    log_success "SLA '$SLA_NAME' trovata ÔåÆ ID: $sla_id"  fi    
# Costruisci JSON output per SLA  local json_output="{}"    if [[ -n "$sla_id" ]]; then
    json_output=$(
echo "$json_output" | jq --arg id "$sla_id" --arg name "$SLA_NAME" '      .sla = {id: ($id|tonumber), name: $name}    ')  fi
echo "$json_output"}
# ===== Discovery Priorit├á =====discover_priorities() {  print_header "­ƒöì DISCOVERY PRIORIT├Ç"    log_info "Recupero lista priorit├á da Ydea API..."    
# Chiama API per ottenere tutte le priorit├á  local priorities_data  priorities_data=$(ydea_api GET "/priorities" 2>/dev/null || 
echo '{"objs":[]}')    if [[ -z "$priorities_data" || "$priorities_data" == '{"objs":[]}' ]]; then    log_warn "Nessuna priorit├á trovata o endpoint non disponibile"    return 0  fi    
# Salva i dati completi per debug  
echo "$priorities_data" > "${SCRIPT_DIR}/priorities-full-dump.json"  log_debug "Dump completo priorit├á salvato in priorities-full-dump.json"    
# Cerca priorit├á "Bassa"  local low_priority_id  low_priority_id=$(
echo "$priorities_data" | jq -r '    .objs[]? | select(.nome == "Bassa" or .name == "Bassa" or .nome == "Low" or .name == "Low") | .id  ' | head -1)    if [[ -z "$low_priority_id" || "$low_priority_id" == "null" ]]; then    log_warn "Priorit├á 'Bassa' non trovata"    log_info "Elenco tutte le priorit├á disponibili:"    
echo "$priorities_data" | jq -r '.objs[]? | "\(.id) ÔåÆ \(.nome // .name)"'    low_priority_id=""
else    log_success "Priorit├á 'Bassa' trovata ÔåÆ ID: $low_priority_id"  fi    
# Costruisci JSON output per priorit├á  local json_output="{}"    if [[ -n "$low_priority_id" ]]; then
    json_output=$(
echo "$json_output" | jq --arg id "$low_priority_id" '      .low_priority = {id: ($id|tonumber), name: "Bassa"}    ')  fi
echo "$json_output"}
# ===== Main =====main() {  print_header "­ƒöì YDEA SLA DISCOVERY TOOL"    log_info "Inizio discovery per SLA Premium_Mon..."  log_info "Output verr├á salvato in: $OUTPUT_FILE"    
# Verifica autenticazione  if ! ensure_token 2>&1; then    log_error "Impossibile autenticarsi a Ydea API"    log_error "Verifica YDEA_ID e YDEA_API_KEY nel file .env"
    exit 1  fi    log_success "Autenticazione completata"    
# Discovery categorie  local categories_json  categories_json=$(discover_categories)    
# Discovery SLA  local sla_json  sla_json=$(discover_sla)    
# Discovery priorit├á  local priorities_json  priorities_json=$(discover_priorities)    
# Combina tutti i risultati  print_header "­ƒôØ GENERAZIONE FILE CONFIGURAZIONE"    local final_json  final_json=$(jq -n \    --argjson cats "$categories_json" \    --argjson sla "$sla_json" \    --argjson priorities "$priorities_json" \    '{      discovery_date: (now | strftime("%Y-%m-%d %H:%M:%S")),      description: "ID per gestione ticket con SLA Premium_Mon",      macro_category: $cats.macro_category,      subcategories: $cats.subcategories,      sla: $sla.sla,      low_priority: $priorities.low_priority    }')    
# Salva il file  
echo "$final_json" > "$OUTPUT_FILE"    print_header "Ô£à DISCOVERY COMPLETATO"    log_success "File di configurazione creato: $OUTPUT_FILE"  
echo ""  
echo "Contenuto:"  jq -C '.' "$OUTPUT_FILE" || cat "$OUTPUT_FILE"  
echo ""    
# Verifica completezza  local missing_items=()    if ! 
echo "$final_json" | jq -e '.macro_category.id' >/dev/null 2>&1; then    missing_items+=("Macro categoria Premium_Mon")  fi    local subcat_count  subcat_count=$(
echo "$final_json" | jq '.subcategories | length')  if [[ "$subcat_count" -lt "${
#SUBCATEGORIES[@]}" ]]; then    missing_items+=("Alcune sottocategorie ($subcat_count/${
#SUBCATEGORIES[@]} trovate)")  fi    if ! 
echo "$final_json" | jq -e '.sla.id' >/dev/null 2>&1; then    missing_items+=("SLA personalizzata TK25/003209")  fi    if [[ "${
#missing_items[@]}" -gt 0 ]]; then
    echo ""    log_warn "ÔÜá´©Å  ATTENZIONE: Alcuni elementi non sono stati trovati:"    for item in "${missing_items[@]}"; do      
echo "  ÔÇó $item"    done
echo ""    log_info "Controlla i file *-full-dump.json per verificare i dati disponibili nell'API"
    exit 1  else    
echo ""    log_success "­ƒÄë Tutti gli elementi richiesti sono stati trovati!"    
echo ""    log_info "Prossimi passi:"    
echo "  1. Verifica il contenuto di: $OUTPUT_FILE"    
echo "  2. Integra questi ID negli script di notifica CheckMK"    
echo "  3. Implementa la logica di mapping sottocategoria ÔåÆ tipo allarme"  fi}
# Esegui mainmain "$@"
