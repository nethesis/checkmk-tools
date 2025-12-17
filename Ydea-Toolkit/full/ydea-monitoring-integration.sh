#!/bin/bash
/usr/bin/env bash
# ydea-monitoring-integration.sh
# Integrazione tra sistemi di monitoraggio e Ydea per creazione automatica ticketset -euo pipefail
TOOLKIT="./ydea-toolkit.sh"
# Configurazione
ALERT_THRESHOLD_CPU=90
ALERT_THRESHOLD_MEM=85
ALERT_THRESHOLD_DISK=90
# File per tracciare ticket gi├á creati (evita duplicati)
TICKET_CACHE="/tmp/ydea_tickets_cache.json"
# ===== UTILITY =====log_info() { 
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ôä╣´©Å  $*"; }log_warn() { 
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ÔÜá´©Å  $*"; }log_error() { 
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ÔØî $*" >&2; }log_success() { 
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ô£à $*"; }
# Inizializza cacheinit_cache() {  [[ -f "$TICKET_CACHE" ]] || 
echo '{}' > "$TICKET_CACHE"}
# Verifica se esiste gi├á un ticket aperto per questo alertticket_exists() {  local alert_key="$1"  init_cache  jq -e --arg key "$alert_key" '.[$key] != null' "$TICKET_CACHE" >/dev/null 2>&1}
# Salva ticket in cachesave_ticket_cache() {  local alert_key="$1"  local ticket_id="$2"  init_cache  jq --arg key "$alert_key" --arg id "$ticket_id" --arg ts "$(date -u +%s)" \    '.[$key] = {ticket_id: $id, created_at: $ts}' \    "$TICKET_CACHE" > "${TICKET_CACHE}.tmp" && mv "${TICKET_CACHE}.tmp" "$TICKET_CACHE"}
# Rimuovi ticket dalla cache (quan
do viene chiuso)remove_ticket_cache() {  local alert_key="$1"  init_cache  jq --arg key "$alert_key" 'del(.[$key])' \    "$TICKET_CACHE" > "${TICKET_CACHE}.tmp" && mv "${TICKET_CACHE}.tmp" "$TICKET_CACHE"}
# Pulisci cache da ticket vecchi (>24h)cleanup_cache() {  init_cachelocal nowlocal nownow=$(date -u +%s)  local max_age=$((24 * 3600))    jq --arg now "$now" --arg max "$max_age" '    to_entries |     map(select(($now | tonumber) - (.value.created_at | tonumber) < ($max | tonumber))) |     from_entries  ' "$TICKET_CACHE" > "${TICKET_CACHE}.tmp" && mv "${TICKET_CACHE}.tmp" "$TICKET_CACHE"}
# ===== FUNZIONI DI MONITORAGGIO =====
# Monitora CPUcheck_cpu_usage() {  local hostname="${1:-$(hostname)}"  local cpu_usage    
# CPU usage (media degli ultimi 5 minuti)  cpu_usage=$(top -bn2 -d 1 | grep "Cpu(s)" | tail -1 | awk '{print $2}' | cut -d'%' -f1)  cpu_usage=${cpu_usage%.*}  
# Rimuovi decimali    log_info "CPU usage su $hostname: ${cpu_usage}%"    if [[ $cpu_usage -gt $ALERT_THRESHOLD_CPU ]]; then    local alert_key="cpu_high_${hostname}"        if ! ticket_exists "$alert_key"; then      log_warn "CPU usage oltre soglia ($ALERT_THRESHOLD_CPU%). Creo ticket..."            local title="[ALERT] CPU usage elevato su $hostname"      local description="ÔÜá´©Å Alert automatico dal sistema di monitoraggio**Dettagli Alert:**- Hostname: $hostname- Metric: CPU Usage- Valore corrente: ${cpu_usage}%- Soglia configurata: ${ALERT_THRESHOLD_CPU}%- Data/ora: $(date '+%Y-%m-%d %H:%M:%S')**Azioni suggerite:**1. Verificare processi con alto utilizzo CPU (\`top\`, \`htop\`)2. Controllare log di sistema per errori3. Valutare necessit├á di scaling o ottimizzazione4. Verificare eventuali job schedulati in esecuzione**Comandi diagnostici:**\`\`\`top -bn1 | head -20ps aux --sort=-%cpu | head -10uptime\`\`\`"local resultlocal resultresult=$($TOOLKIT create "$title" "$description" "high")local ticket_idlocal ticket_idticket_id=$(
echo "$result" | jq -r '.id // empty')            if [[ -n "$ticket_id" ]]; then        save_ticket_cache "$alert_key" "$ticket_id"        log_success "Ticket 
#$ticket_id creato per alert CPU"      else        log_error "Errore nella creazione del ticket"      fi    else      log_info "Ticket per CPU gi├á esistente, non creo duplicati"    fi  fi}
# Monitora memoriacheck_memory_usage() {  local hostname="${1:-$(hostname)}"  local mem_usage    mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')    log_info "Memory usage su $hostname: ${mem_usage}%"    if [[ $mem_usage -gt $ALERT_THRESHOLD_MEM ]]; then    local alert_key="mem_high_${hostname}"        if ! ticket_exists "$alert_key"; then      log_warn "Memory usage oltre soglia ($ALERT_THRESHOLD_MEM%). Creo ticket..."      local mem_infolocal mem_infomem_info=$(free -h | grep -E 'Mem|Swap')            local title="[ALERT] Memory usage elevato su $hostname"      local description="ÔÜá´©Å Alert automatico dal sistema di monitoraggio**Dettagli Alert:**- Hostname: $hostname- Metric: Memory Usage- Valore corrente: ${mem_usage}%- Soglia configurata: ${ALERT_THRESHOLD_MEM}%- Data/ora: $(date '+%Y-%m-%d %H:%M:%S')**Stato Memoria:**\`\`\`$mem_info\`\`\`**Azioni suggerite:**1. Identificare processi con alto utilizzo memoria2. Verificare memory leak in applicazioni3. Controllare cache e buffer4. Valutare necessit├á di aumento RAM**Comandi diagnostici:**\`\`\`free -hps aux --sort=-%mem | head -10vmstat 1 5\`\`\`"local resultlocal resultresult=$($TOOLKIT create "$title" "$description" "high")local ticket_idlocal ticket_idticket_id=$(
echo "$result" | jq -r '.id // empty')            if [[ -n "$ticket_id" ]]; then        save_ticket_cache "$alert_key" "$ticket_id"        log_success "Ticket 
#$ticket_id creato per alert memoria"      else        log_error "Errore nella creazione del ticket"      fi    else      log_info "Ticket per memoria gi├á esistente, non creo duplicati"    fi  fi}
# Monitora discocheck_disk_usage() {  local hostname="${1:-$(hostname)}"    
# Controlla tutti i filesystem  df -h | grep -vE '^Filesystem|tmpfs|cdrom|loop' | while read -r line; dolocal filesystemlocal filesystemfilesystem=$(
echo "$line" | awk '{print $1}')local mountpointlocal mountpointmountpoint=$(
echo "$line" | awk '{print $6}')local usagelocal usageusage=$(
echo "$line" | awk '{print $5}' | sed 's/%//')        log_info "Disk usage su $hostname:$mountpoint: ${usage}%"        if [[ $usage -gt $ALERT_THRESHOLD_DISK ]]; then      local alert_key="disk_high_${hostname}_${mountpoint//\//_}"            if ! ticket_exists "$alert_key"; then        log_warn "Disk usage su $mountpoint oltre soglia ($ALERT_THRESHOLD_DISK%). Creo ticket..."        local disk_infolocal disk_infodisk_info=$(df -h "$mountpoint")                local title="[ALERT] Disk usage elevato su $hostname:$mountpoint"        local description="ÔÜá´©Å Alert automatico dal sistema di monitoraggio**Dettagli Alert:**- Hostname: $hostname- Filesystem: $filesystem- Mount point: $mountpoint- Utilizzo corrente: ${usage}%- Soglia configurata: ${ALERT_THRESHOLD_DISK}%- Data/ora: $(date '+%Y-%m-%d %H:%M:%S')**Stato Disco:**\`\`\`$disk_info\`\`\`**Azioni suggerite:**1. Identificare file e directory pi├╣ grandi2. Pulizia log vecchi3. Rimozione file temporanei4. Valutare espansione storage**Comandi diagnostici:**\`\`\`du -sh ${mountpoint}/* | sort -rh | head -10find ${mountpoint} -type f -size +100M -exec ls -lh {} \\;df -i ${mountpoint}  
# Verifica inode\`\`\`"local resultlocal resultresult=$($TOOLKIT create "$title" "$description" "high")local ticket_idlocal ticket_idticket_id=$(
echo "$result" | jq -r '.id // empty')                if [[ -n "$ticket_id" ]]; then          save_ticket_cache "$alert_key" "$ticket_id"          log_success "Ticket 
#$ticket_id creato per alert disco"        else          log_error "Errore nella creazione del ticket"        fi      else        log_info "Ticket per disco $mountpoint gi├á esistente, non creo duplicati"      fi    fi  done}
# Monitora servizi specificicheck_service() {  local service_name="$1"  local hostname="${2:-$(hostname)}"    if ! systemctl is-active --quiet "$service_name"; then    local alert_key="service_down_${hostname}_${service_name}"        if ! ticket_exists "$alert_key"; then      log_warn "Servizio $service_name non attivo. Creo ticket..."      local service_statuslocal service_statusservice_status=$(systemctl status "$service_name" 2>&1 || true)            local title="[ALERT] Servizio $service_name non attivo su $hostname"      local description="­ƒö┤ Alert automatico dal sistema di monitoraggio**Dettagli Alert:**- Hostname: $hostname- Servizio: $service_name- Stato: NON ATTIVO- Data/ora: $(date '+%Y-%m-%d %H:%M:%S')**Status servizio:**\`\`\`$service_status\`\`\`**Azioni immediate:**1. Tentare riavvio: \`systemctl restart $service_name\`2. Controllare log: \`journalctl -u $service_name -n 50\`3. Verificare dipendenze4. Controllare configurazione**Comandi diagnostici:**\`\`\`systemctl status $service_namejournalctl -u $service_name --since \"1 hour ago\"\`\`\`"local resultlocal resultresult=$($TOOLKIT create "$title" "$description" "critical")local ticket_idlocal ticket_idticket_id=$(
echo "$result" | jq -r '.id // empty')            if [[ -n "$ticket_id" ]]; then        save_ticket_cache "$alert_key" "$ticket_id"        log_success "Ticket 
#$ticket_id creato per servizio down"      else        log_error "Errore nella creazione del ticket"      fi    else      log_info "Ticket per servizio $service_name gi├á esistente"    fi  else    log_info "Servizio $service_name: OK"  fi}
# ===== INTEGRAZIONE NETDATA =====
# Webhook receiver per Netdata alarmsnetdata_webhook_handler() {  
# Leggi JSON da stdin (inviato da Netdata)local alert_datalocal alert_dataalert_data=$(cat)  local alarm_namelocal alarm_namealarm_name=$(
echo "$alert_data" | jq -r '.alarm // .name')local statuslocal statusstatus=$(
echo "$alert_data" | jq -r '.status')local hostnamelocal hostnamehostname=$(
echo "$alert_data" | jq -r '.hostname')local valuelocal valuevalue=$(
echo "$alert_data" | jq -r '.value')local chartlocal chartchart=$(
echo "$alert_data" | jq -r '.chart')    log_info "Ricevuto alert Netdata: $alarm_name su $hostname (status: $status)"    if [[ "$status" == "CRITICAL" || "$status" == "WARNING" ]]; then    local alert_key="netdata_${hostname}_${alarm_name}"        if ! ticket_exists "$alert_key"; then      local priority="normal"      [[ "$status" == "CRITICAL" ]] && priority="critical"            local title="[NETDATA] $alarm_name su $hostname"      local description="ÔÜá´©Å Alert da Netdata**Dettagli Alert:**- Alarm: $alarm_name- Hostname: $hostname- Status: $status- Chart: $chart- Valore: $value- Data/ora: $(date '+%Y-%m-%d %H:%M:%S')**Dati completi alert:**\`\`\`json$alert_data\`\`\`"local resultlocal resultresult=$($TOOLKIT create "$title" "$description" "$priority")local ticket_idlocal ticket_idticket_id=$(
echo "$result" | jq -r '.id // empty')            if [[ -n "$ticket_id" ]]; then        save_ticket_cache "$alert_key" "$ticket_id"        log_success "Ticket 
#$ticket_id creato per alert Netdata"      fi    fi  elif [[ "$status" == "CLEAR" ]]; then    
# Alert risolto, chiudi ticket se esiste    local alert_key="netdata_${hostname}_${alarm_name}"    init_cachelocal ticket_idlocal ticket_idticket_id=$(jq -r --arg key "$alert_key" '.[$key].ticket_id // empty' "$TICKET_CACHE")        if [[ -n "$ticket_id" ]]; then      log_info "Alert risolto, chiu
do ticket 
#$ticket_id"      $TOOLKIT close "$ticket_id" "Alert Netdata risolto automaticamente: $alarm_name"      remove_ticket_cache "$alert_key"    fi  fi}
# ===== COMANDI CLI =====case "${1:-}" in  monitor)    
# Monitoring completo    log_info "Avvio monitoring completo..."    cleanup_cache    check_cpu_usage    check_memory_usage    check_disk_usage    log_success "Monitoring completato"    ;;      service)    
# Monitora servizio specifico    shift    [[ -z "${1:-}" ]] && { log_error "Specifica nome servizio"; exit 1; }    check_service "$1"    ;;      netdata-webhook)    
# Handler per webhook Netdata    netdata_webhook_handler    ;;      cleanup)    
# Pulisci cache    cleanup_cache    log_success "Cache pulita"    ;;      *)    cat >&2 <<'USAGE'­ƒöº Ydea Monitoring IntegrationUSO:  
# Monitoring completo (CPU, RAM, Disk)  ./ydea-monitoring-integration.sh monitor  
# Monitora servizio specifico  ./ydea-monitoring-integration.sh service <nome_servizio>    
# Webhook handler per Netdata (riceve JSON da stdin)  ./ydea-monitoring-integration.sh netdata-webhook < alert.json    
# Pulisci cache ticket  ./ydea-monitoring-integration.sh cleanupCONFIGURAZIONE CRON:  
# Monitoring ogni 5 minuti  */5 * * * * /path/to/ydea-monitoring-integration.sh monitor >> /var/log/ydea-monitor.log 2>&1CONFIGURAZIONE NETDATA:  Aggiungi in /etc/netdata/health_alarm_notify.conf:    
SEND_CUSTOM="YES"  
DEFAULT_RECIPIENT_CUSTOM="ydea"    
# Script custom notification  custom_sender() {    /path/to/ydea-monitoring-integration.sh netdata-webhook << EOF    {      "alarm": "${alarm}",      "status": "${status}",      "hostname": "${host}",      "value": "${value}",      "chart": "${chart}"    }  EOF  }USAGE    exit 1    ;;esac
