#!/bin/bash
# ===============================================================
# checkmk-tuning-interactive.sh v4.0
# Ottimizzazione automatica e interattiva per Checkmk Raw Edition
# con benchmark, riepilogo e modalita "Autotune"
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
NC='\033[0m'
MODE="interactive"[[ "$1" == "--auto" ]] && 
MODE="auto"clear
echo -e "${CYAN}=== Checkmk Tuning Tool v4.0 ===${NC}"
echo "Sito: $SITE"
echo "Modalita: $MODE"
echo "Backup in: $BACKUP_DIR"echomkdir -p "$BACKUP_DIR"cp -a "$NAGIOS_CFG" "$BACKUP_DIR/" 2>/dev/nullcp -a "$GLOBAL_MK" "$BACKUP_DIR/" 2>/dev/null
# ---------------------------------------------------------------
# 1 AOau Lettura risorse attuali
# ---------------------------------------------------------------
CORES=$(nproc)
LOAD_NOW=$(awk '{print $1}' /proc/loadavg)
CPU_NOW=$(mpstat 3 3 | awk '/Average/ && $12 ~ /[0-9.]+/ {sum += 100 - $12; count++} END {if (count>0) print sum/count}')
CHECKS_NOW=$(ps -eo comm | grep check_ | wc -l)
echo -e "${YELLOW}Oa Stato attuale del sistema:${NC}"
echo "  CPU media: ${CPU_NOW}%"
echo "  Load average: ${LOAD_NOW}"
echo "  Core disponibili: ${CORES}"
echo "  Processi check_* attivi: ${CHECKS_NOW}"echo
# ---------------------------------------------------------------
# 2 AOau Lettura impostazioni correnti
# ---------------------------------------------------------------
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
CURRENT_DELAY="(non impostato)"
# ---------------------------------------------------------------
# 3 AOau Calcolo suggerimenti automatici
# ---------------------------------------------------------------if [[ "$MODE" == "auto" ]]; then
    echo -e "${YELLOW}Oa Analisi automatica del carico...${NC}"    if (( $(
echo "$LOAD_NOW > $CORES*2" | bc -l) )); then
    NEW_CONC=20        
NEW_SLEEP=0.35        
COMMENT="Carico molto alto: limito concorrenza e aumento sleep."
elif (( $(
echo "$LOAD_NOW > $CORES*1" | bc -l) )); then
    NEW_CONC=25        
NEW_SLEEP=0.30        
COMMENT="Carico medio-alto: leggero bilanciamento."
elif (( $(
echo "$CPU_NOW > 70" | bc -l) )); then
    NEW_CONC=25        
NEW_SLEEP=0.30        
COMMENT="CPU alta: mantengo concorrenza media, aumento sleep."
elif (( $(
echo "$LOAD_NOW < $CORES*0.6" | bc -l) )) && (( $(
echo "$CPU_NOW < 40" | bc -l) )); then
    NEW_CONC=35        
NEW_SLEEP=0.20        
COMMENT="Sottoutilizzato: aumento concorrenza."
else        
NEW_CONC=30        
NEW_SLEEP=0.25        
COMMENT="Carico stabile: uso parametri bilanciati."    fi    
NEW_SERV_TMOUT=60    
NEW_HOST_TMOUT=60    
NEW_DELAY="s"    
echo    
echo -e "${GREEN}Oa Decisione automatica:${NC}"    
echo "  max_concurrent_checks = $NEW_CONC"    
echo "  service_check_timeout = $NEW_SERV_TMOUT"    
echo "  host_check_timeout    = $NEW_HOST_TMOUT"    
echo "  sleep_time            = $NEW_SLEEP"    
echo "  inter_check_delay     = $NEW_DELAY"    
echo "  Commento: $COMMENT"    echo
else    
# Interattivo    
echo -e "${YELLOW}Oa Inserisci i nuovi valori (invio = default):${NC}"    read -r -p "  max_concurrent_checks [30]: " NEW_CONC    read -r -p "  service_check_timeout [60]: " NEW_SERV_TMOUT    read -r -p "  host_check_timeout [60]: " NEW_HOST_TMOUT    read -r -p "  sleep_time [0.25]: " NEW_SLEEP    read -r -p "  inter_check_delay (n/s/d) [s]: " NEW_DELAY    
NEW_CONC=${NEW_CONC:-30}    
NEW_SERV_TMOUT=${NEW_SERV_TMOUT:-60}    
NEW_HOST_TMOUT=${NEW_HOST_TMOUT:-60}    
NEW_SLEEP=${NEW_SLEEP:-0.25}    
NEW_DELAY=${NEW_DELAY:-s}fi
# ---------------------------------------------------------------
# 4 AOau Riepilogo / conferma
# ---------------------------------------------------------------clear
echo -e "${CYAN}=== Riepilogo tuning $MODE ===${NC}"printf "  OCo CPU: %s%% | Load: %s | Core: %s | Processi check: %s\n" "$CPU_NOW" "$LOAD_NOW" "$CORES" "$CHECKS_NOW"printf "  OCo Parametri correnti: conc=%s, sleep=%s\n" "$CURRENT_CONC" "$CURRENT_SLEEP"echo
echo -e "${GREEN}Nuovi parametri:${NC}"cat <<EOF  max_concurrent_checks = $NEW_CONC  service_check_timeout = $NEW_SERV_TMOUT  host_check_timeout    = $NEW_HOST_TMOUT  sleep_time            = $NEW_SLEEP  service_inter_check_delay_method = $NEW_DELAYEOFecho
if [[ "$MODE" != "auto" ]]; then    read -r -p "Applico queste modifiche? (s/n): " CONFIRM    [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]] && 
echo -e "${RED}Oi Operazione annullata.${NC}" && exit 0
else    
echo -e "${YELLOW}Oa Applicazione automatica senza conferma utente.${NC}"    sleep 2
fi # ---------------------------------------------------------------
# 5 AOau Applicazione modifiche
# ---------------------------------------------------------------
echo -e "${YELLOW}Oa Scrittura configurazione...${NC}"cat > "$NAGIOS_CFG" <<EOF
# =========================================================
# Ottimizzazione Checkmk Nagios Core - generato automaticamente
# =========================================================max_concurrent_checks=$NEW_CONCservice_check_timeout=$NEW_SERV_TMOUThost_check_timeout=$NEW_HOST_TMOUTsleep_time=$NEW_SLEEPservice_inter_check_delay_method=$NEW_DELAYEOFgrep -q "service_check_timeout" "$GLOBAL_MK" 2>/dev/null || 
echo "service_check_timeout = $NEW_SERV_TMOUT" >> "$GLOBAL_MK"grep -q "use_cache_for_checking" "$GLOBAL_MK" 2>/dev/null || 
echo "use_cache_for_checking = True" >> "$GLOBAL_MK"
# ---------------------------------------------------------------
# 6 AOau Riavvio + Benchmark post
# ---------------------------------------------------------------
echo -e "${YELLOW}Oa Riavvio del sito $SITE...${NC}"omd restart "$SITE"
echo -e "${YELLOW}Oa Atten
do stabilizzazione dei processi...${NC}"
STABLE_COUNT=0
PREV_PROC=0
SECONDS_WAITED=0while [ $STABLE_COUNT -lt 2 ]; do    sleep 10    
PROC_NOW=$(ps -eo comm | grep check_ | wc -l)    if [ "$PROC_NOW" == "$PREV_PROC" ] && [ "$PROC_NOW" -ne 0 ]; then        ((STABLE_COUNT++))    else        
STABLE_COUNT=0    fi    
PREV_PROC=$PROC_NOW    ((SECONDS_WAITED+=10))    
echo "  OA Verifica dopo ${SECONDS_WAITED}s Oa $PROC_NOW processi check_*"    if [ $SECONDS_WAITED -ge 120 ]; then
    echo "  OUa A Timeout di stabilizzazione raggiunto (120s)"        break    fi
done
echo -e "${YELLOW}Oa Atten
do 60s di quiete prima del benchmark finale...${NC}"sleep 60
CPU_SUM=0
COUNT=0for i in {1..3}; do    
SAMPLE=$(mpstat 3 3 | awk '/Average/ && $12 ~ /[0-9.]+/ {sum += 100 - $12; count++} END {if (count>0) print sum/count}')    
CPU_SUM=$(
echo "$CPU_SUM + $SAMPLE" | bc)    ((COUNT++))    
echo "  oe Rilevazione 
#$i: ${SAMPLE}% CPU"    sleep 10done
CPU_AFTER=$(
echo "scale=2; $CPU_SUM / $COUNT" | bc)
LOAD_AFTER=$(awk '{print $1}' /proc/loadavg)
CHECKS_AFTER=$(ps -eo comm | grep check_ | wc -l)
LOAD_AFTER=$(awk '{print $1}' /proc/loadavg)
CHECKS_AFTER=$(ps -eo comm | grep check_ | wc -l)
# ---------------------------------------------------------------
# 7 AOau Report finale
# ---------------------------------------------------------------clear
echo -e "${CYAN}=== Benchmark prima e dopo ===${NC}"printf "%-30s %-15s %-15s\n" "Parametro" "Prima" "Dopo"printf "%-30s %-15s %-15s\n" "CPU Utilization (%)" "${CPU_NOW}" "${CPU_AFTER}"printf "%-30s %-15s %-15s\n" "Load Average (1m)" "${LOAD_NOW}" "${LOAD_AFTER}"printf "%-30s %-15s %-15s\n" "Processi check_*" "${CHECKS_NOW}" "${CHECKS_AFTER}"echo
echo -e "${GREEN}Oa Ottimizzazione completata!${NC}"
echo "Backup salvato in: $BACKUP_DIR"echo
