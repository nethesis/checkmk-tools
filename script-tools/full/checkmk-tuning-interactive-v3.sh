
#!/bin/bash
/bin/bash
# ===============================================================
# checkmk-tuning-interactive.sh v3.0
# Ottimizzazione interattiva di Checkmk Raw (Nagios Core)
# con riepilogo completo e benchmark pre/post tuning
# ===============================================================
# Autore: Marzio Bordin + GPT-5 Assistant
# ===============================================================
SITE="monitoring"
SITEPATH="/opt/omd/sites/$SITE"
NAGIOS_CFG="$SITEPATH/etc/nagios/nagios.d/tuning.cfg"
GLOBAL_MK="$SITEPATH/etc/check_mk/conf.d/wato/global.mk"
BACKUP_DIR="/root/checkmk_tuning_backup_$(date +%Y%m%d_%H%M%S)"
# --- Colori ---
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m'clear
echo -e "${CYAN}=== Checkmk Tuning Interattivo (v3.0) ===${NC}"
echo "Sito: $SITE"
echo "Backup in: $BACKUP_DIR"echo
# ---------------------------------------------------------------
# 1´©ÅÔâú Benchmark iniziale
# ---------------------------------------------------------------
echo -e "${YELLOW}ÔåÆ Rilevamento dati iniziali...${NC}"
CPU_BEFORE=$(mpstat 3 3 | awk '/Average/ && $12 ~ /[0-9.]+/ {sum += 100 - $12; count++} END {if (count>0) print sum/count}')
LOAD_BEFORE=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
CHECKS_BEFORE=$(ps -eo comm | grep check_ | wc -l)
echo "  CPU attuale: ${CPU_BEFORE}%"
echo "  Load average: ${LOAD_BEFORE}"
echo "  Processi check attivi: ${CHECKS_BEFORE}"echo
# ---------------------------------------------------------------
# 2´©ÅÔâú Lettura impostazioni attuali
# ---------------------------------------------------------------
echo -e "${YELLOW}ÔåÆ Lettura impostazioni correnti...${NC}"mkdir -p "$BACKUP_DIR"cp -a "$NAGIOS_CFG" "$BACKUP_DIR/" 2>/dev/nullcp -a "$GLOBAL_MK" "$BACKUP_DIR/" 2>/dev/null
CURRENT_CONC=$(grep -E "^max_concurrent_checks" "$NAGIOS_CFG" 2>/dev/null | awk -
F= '{print $2}' | xargs)
CURRENT_SERV_TMOUT=$(grep -E "^service_check_timeout" "$NAGIOS_CFG" 2>/dev/null | awk -
F= '{print $2}' | xargs)
CURRENT_HOST_TMOUT=$(grep -E "^host_check_timeout" "$NAGIOS_CFG" 2>/dev/null | awk -
F= '{print $2}' | xargs)
CURRENT_SLEEP=$(grep -E "^sleep_time" "$NAGIOS_CFG" 2>/dev/null | awk -
F= '{print $2}' | xargs)
CURRENT_DELAY=$(grep -E "^service_inter_check_delay_method" "$NAGIOS_CFG" 2>/dev/null | awk -
F= '{print $2}' | xargs)[ -z "$CURRENT_CONC" ] && 
CURRENT_CONC="(non impostato)"[ -z "$CURRENT_SERV_TMOUT" ] && 
CURRENT_SERV_TMOUT="(non impostato)"[ -z "$CURRENT_HOST_TMOUT" ] && 
CURRENT_HOST_TMOUT="(non impostato)"[ -z "$CURRENT_SLEEP" ] && 
CURRENT_SLEEP="(non impostato)"[ -z "$CURRENT_DELAY" ] && 
CURRENT_DELAY="(non impostato)"echo
echo "­ƒº® Impostazioni attuali:"printf "  ÔÇó max_concurrent_checks = %s\n" "$CURRENT_CONC"printf "  ÔÇó service_check_timeout = %s\n" "$CURRENT_SERV_TMOUT"printf "  ÔÇó host_check_timeout    = %s\n" "$CURRENT_HOST_TMOUT"printf "  ÔÇó sleep_time            = %s\n" "$CURRENT_SLEEP"printf "  ÔÇó inter_check_delay     = %s\n" "$CURRENT_DELAY"echo
# ---------------------------------------------------------------
# 3´©ÅÔâú Nuovi valori
# ---------------------------------------------------------------
echo -e "${YELLOW}ÔåÆ Inserisci i nuovi valori (invio per default consigliato):${NC}"read -r -p "  max_concurrent_checks [30]: " NEW_CONCread -r -p "  service_check_timeout (sec) [60]: " NEW_SERV_TMOUTread -r -p "  host_check_timeout (sec) [60]: " NEW_HOST_TMOUTread -r -p "  sleep_time (sec) [0.25]: " NEW_SLEEPread -r -p "  inter_check_delay (n=none / s=spread / d=smart) [s]: " 
NEW_DELAYNEW_CONC=${NEW_CONC:-30}
NEW_SERV_TMOUT=${NEW_SERV_TMOUT:-60}
NEW_HOST_TMOUT=${NEW_HOST_TMOUT:-60}
NEW_SLEEP=${NEW_SLEEP:-0.25}
NEW_DELAY=${NEW_DELAY:-s}
# ---------------------------------------------------------------
# 4´©ÅÔâú Riepilogo
# ---------------------------------------------------------------clear
echo -e "${CYAN}=== Riepilogo configurazione ===${NC}"echo
echo -e "${YELLOW}Valori attuali:${NC}"printf "  max_concurrent_checks = %s\n" "$CURRENT_CONC"printf "  service_check_timeout = %s\n" "$CURRENT_SERV_TMOUT"printf "  host_check_timeout    = %s\n" "$CURRENT_HOST_TMOUT"printf "  sleep_time            = %s\n" "$CURRENT_SLEEP"printf "  inter_check_delay     = %s\n" "$CURRENT_DELAY"echo
echo -e "${GREEN}Nuovi valori proposti:${NC}"cat <<EOF  max_concurrent_checks = $NEW_CONC  service_check_timeout = $NEW_SERV_TMOUT  host_check_timeout    = $NEW_HOST_TMOUT  sleep_time = $NEW_SLEEP  service_inter_check_delay_method = $NEW_DELAYEOFechoread -r -p "Applico queste modifiche? (s/n): " CONFIRM[[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]] && 
echo -e "${RED}ÔØî Operazione annullata.${NC}" && exit 0
# ---------------------------------------------------------------
# 5´©ÅÔâú Applicazione modifiche
# ---------------------------------------------------------------
echo -e "${YELLOW}ÔåÆ Scrittura nuove impostazioni...${NC}"cat > "$NAGIOS_CFG" <<EOF
# =========================================================
# Ottimizzazione Checkmk Nagios Core - generato automaticamente
# =========================================================max_concurrent_checks=$NEW_CONCservice_check_timeout=$NEW_SERV_TMOUThost_check_timeout=$NEW_HOST_TMOUTsleep_time=$NEW_SLEEPservice_inter_check_delay_method=$NEW_DELAYEOFgrep -q "service_check_timeout" "$GLOBAL_MK" 2>/dev/null || 
echo "service_check_timeout = $NEW_SERV_TMOUT" >> "$GLOBAL_MK"grep -q "use_cache_for_checking" "$GLOBAL_MK" 2>/dev/null || 
echo "use_cache_for_checking = True" >> "$GLOBAL_MK"
# ---------------------------------------------------------------
# 6´©ÅÔâú Riavvio e benchmark post-modifica (v3.1 con attesa dinamica)
# ---------------------------------------------------------------echo
echo -e "${YELLOW}ÔåÆ Riavvio del sito $SITE...${NC}"omd restart "$SITE"
echo -e "${YELLOW}ÔåÆ Attendo stabilizzazione dei processi (min 60s)...${NC}"
STABLE_COUNT=0
PREV_PROC=0
SECONDS_WAITED=0while [ $STABLE_COUNT -lt 2 ]; do    sleep 10    
PROC_NOW=$(ps -eo comm | grep check_ | wc -l)    if [ "$PROC_NOW" == "$PREV_PROC" ] && [ "$PROC_NOW" -ne 0 ]; then        ((STABLE_COUNT++))    else        
STABLE_COUNT=0    fi    
PREV_PROC=$PROC_NOW    ((SECONDS_WAITED+=10))    
echo "  ÔÅ▒  Verifica dopo ${SECONDS_WAITED}s ÔåÆ $PROC_NOW processi check_*"    if [ $SECONDS_WAITED -ge 120 ]; then        
echo "  ÔÜá´©Å  Timeout di stabilizzazione raggiunto (120s)"        break    fidone
echo -e "${GREEN}ÔåÆ Processi stabilizzati, misuro ora...${NC}"
CPU_AFTER=$(mpstat 3 3 | awk '/Average/ && $12 ~ /[0-9.]+/ {sum += 100 - $12; count++} END {if (count>0) print sum/count}')
LOAD_AFTER=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
CHECKS_AFTER=$(ps -eo comm | grep check_ | wc -l)
# ---------------------------------------------------------------
# 7´©ÅÔâú Report comparativo
# ---------------------------------------------------------------clear
echo -e "${CYAN}=== Benchmark prima e dopo ===${NC}"printf "%-30s %-15s %-15s\n" "Parametro" "Prima" "Dopo"printf "%-30s %-15s %-15s\n" "CPU Utilization (%)" "${CPU_BEFORE}" "${CPU_AFTER}"printf "%-30s %-15s %-15s\n" "Load Average (1m)" "${LOAD_BEFORE}" "${LOAD_AFTER}"printf "%-30s %-15s %-15s\n" "Processi check_*" "${CHECKS_BEFORE}" "${CHECKS_AFTER}"echo
echo -e "${GREEN}Ô£à Ottimizzazione completata e benchmark stabile!${NC}"
echo "Backup: $BACKUP_DIR"echo
