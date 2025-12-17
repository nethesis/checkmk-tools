#!/bin/bash
# ===============================================================
# checkmk-tuning-interactive.sh v2.0
# Script interattivo per ottimizzare Checkmk Raw Edition (Nagios core)
# con riepilogo chiaro prima dell'applicazione
# ===============================================================
# Autore: Marzio Bordin + GPT-5 Assistant
# ===============================================================
SITE="monitoring"
SITEPATH="/opt/omd/sites/$SITE"
NAGIOS_CFG="$SITEPATH/etc/nagios/nagios.d/tuning.cfg"
GLOBAL_MK="$SITEPATH/etc/check_mk/conf.d/wato/global.mk"
BACKUP_DIR="/root/checkmk_tuning_backup_$(date +%Y%m%d_%H%M%S)"
# --- Colori per leggibilit├á ---
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m'clear
echo -e "${CYAN}=== Checkmk Tuning Interattivo (v2.0) ===${NC}"
echo "Sito: $SITE"
echo "Backup in: $BACKUP_DIR"echo
# ---------------------------------------------------------------
# 1´©ÅÔâú Lettura impostazioni attuali
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
echo "­ƒº® Impostazioni attuali:"printf "  ÔÇó max_concurrent_checks = %s\n" "$CURRENT_CONC"printf "  ÔÇó service_check_timeout = %s\n" "$CURRENT_SERV_TMOUT"printf "  ÔÇó host_check_timeout    = %s\n" "$CURRENT_HOST_TMOUT"printf "  ÔÇó sleep_time            = %s\n" "$CURRENT_SLEEP"printf "  ÔÇó inter_check_delay     = %s\n" "$CURRENT_DELAY"echogrep -E "service_check_timeout|use_cache_for_checking" "$GLOBAL_MK" 2>/dev/null && 
echo || 
echo "  Nessuna opzione extra trovata in global.mk"echo
# ---------------------------------------------------------------
# 2´©ÅÔâú Inserimento nuovi valori
# ---------------------------------------------------------------
echo -e "${YELLOW}ÔåÆ Inserisci i nuovi valori (invio per usare i default suggeriti):${NC}"read -r -p "  Nuovo valore per max_concurrent_checks [30]: " NEW_CONCread -r -p "  Nuovo valore per service_check_timeout (sec) [60]: " NEW_SERV_TMOUTread -r -p "  Nuovo valore per host_check_timeout (sec) [60]: " NEW_HOST_TMOUTread -r -p "  Nuovo valore per sleep_time (sec fra i check) [0.25]: " NEW_SLEEPread -r -p "  Metodo inter_check_delay (n = none / s = spread / d = smart) [s]: " 
NEW_DELAYNEW_CONC=${NEW_CONC:-30}
NEW_SERV_TMOUT=${NEW_SERV_TMOUT:-60}
NEW_HOST_TMOUT=${NEW_HOST_TMOUT:-60}
NEW_SLEEP=${NEW_SLEEP:-0.25}
NEW_DELAY=${NEW_DELAY:-s}
# ---------------------------------------------------------------
# 3´©ÅÔâú Riepilogo prima dell'applicazione
# ---------------------------------------------------------------clear
echo -e "${CYAN}=== Riepilogo configurazione ===${NC}"echo
echo -e "${YELLOW}Valori attuali:${NC}"printf "  max_concurrent_checks = %s\n" "$CURRENT_CONC"printf "  service_check_timeout = %s\n" "$CURRENT_SERV_TMOUT"printf "  host_check_timeout    = %s\n" "$CURRENT_HOST_TMOUT"printf "  sleep_time            = %s\n" "$CURRENT_SLEEP"printf "  inter_check_delay     = %s\n" "$CURRENT_DELAY"echo
echo -e "${GREEN}Nuovi valori proposti:${NC}"cat <<EOF  max_concurrent_checks = $NEW_CONC  service_check_timeout = $NEW_SERV_TMOUT  host_check_timeout    = $NEW_HOST_TMOUT  sleep_time            = $NEW_SLEEP  service_inter_check_delay_method = $NEW_DELAYEOFechoread -r -p "Applico queste modifiche? (s/n): " CONFIRM[[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]] && 
echo -e "${RED}ÔØî Operazione annullata.${NC}" && exit 0
# ---------------------------------------------------------------
# 4´©ÅÔâú Applicazione modifiche
# ---------------------------------------------------------------
echo -e "${YELLOW}ÔåÆ Scrittura configurazione...${NC}"cat > "$NAGIOS_CFG" <<EOF
# =========================================================
# Ottimizzazione Checkmk Nagios Core - generato automaticamente
# =========================================================max_concurrent_checks=$NEW_CONCservice_check_timeout=$NEW_SERV_TMOUThost_check_timeout=$NEW_HOST_TMOUTsleep_time=$NEW_SLEEPservice_inter_check_delay_method=$NEW_DELAYEOFgrep -q "service_check_timeout" "$GLOBAL_MK" 2>/dev/null || 
echo "service_check_timeout = $NEW_SERV_TMOUT" >> "$GLOBAL_MK"grep -q "use_cache_for_checking" "$GLOBAL_MK" 2>/dev/null || 
echo "use_cache_for_checking = True" >> "$GLOBAL_MK"
# ---------------------------------------------------------------
# 5´©ÅÔâú Riavvio e verifica
# ---------------------------------------------------------------echo
echo -e "${YELLOW}ÔåÆ Riavvio del sito $SITE...${NC}"omd restart "$SITE"echo
echo -e "${CYAN}Ultime righe del log Nagios:${NC}"sudo -u "$SITE" tail -n 10 "$SITEPATH/var/nagios/nagios.log" 2>/dev/null || tail -n 10 "$SITEPATH/var/nagios/nagios.log"echo
echo -e "${CYAN}Processi di check attivi:${NC}"ps -eo comm | grep check_ | wc -lecho
echo -e "${GREEN}Ô£à Ottimizzazione completata!${NC}"
echo "Backup salvato in: $BACKUP_DIR"echo
