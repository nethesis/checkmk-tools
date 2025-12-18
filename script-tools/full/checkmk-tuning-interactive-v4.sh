#!/usr/bin/env bash
# ===============================================================
# checkmk-tuning-interactive-v4.sh v4.0
# Ottimizzazione automatica e interattiva per Checkmk Raw Edition
# con benchmark, riepilogo e modalità "--auto" (autotune)
# ===============================================================

set -e

SITE="monitoring"
SITEPATH="/opt/omd/sites/$SITE"
NAGIOS_CFG="$SITEPATH/etc/nagios/nagios.d/tuning.cfg"
GLOBAL_MK="$SITEPATH/etc/check_mk/conf.d/wato/global.mk"
BACKUP_DIR="/root/checkmk_tuning_backup_$(date +%Y%m%d_%H%M%S)"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m'

MODE="interactive"
if [[ "${1:-}" == "--auto" ]]; then
    MODE="auto"
fi

clear
echo -e "${CYAN}=== Checkmk Tuning Tool v4.0 ===${NC}"
echo "Sito: $SITE"
echo "Modalità: $MODE"
echo "Backup in: $BACKUP_DIR"
echo

mkdir -p "$BACKUP_DIR"
cp -a "$NAGIOS_CFG" "$BACKUP_DIR/" 2>/dev/null || true
cp -a "$GLOBAL_MK" "$BACKUP_DIR/" 2>/dev/null || true

CORES=$(nproc)
LOAD_NOW=$(awk '{print $1}' /proc/loadavg)
CPU_NOW=$(mpstat 3 3 | awk '/Average/ && $12 ~ /[0-9.]+/ {s+=100-$12;c++} END{if(c) printf("%.2f",s/c); else print 0}')
CHECKS_NOW=$(ps -eo comm | grep -c '^check_' || true)

echo -e "${YELLOW}Stato attuale del sistema:${NC}"
echo "  CPU media: ${CPU_NOW}%"
echo "  Load average: ${LOAD_NOW}"
echo "  Core disponibili: ${CORES}"
echo "  Processi check_* attivi: ${CHECKS_NOW}"
echo

get_cfg_value() {
    local key="$1"
    grep -E "^${key}=" "$NAGIOS_CFG" 2>/dev/null | awk -F= '{print $2}' | xargs
}

CURRENT_CONC=$(get_cfg_value "max_concurrent_checks")
CURRENT_SLEEP=$(get_cfg_value "sleep_time")
[[ -z "$CURRENT_CONC" ]] && CURRENT_CONC="(non impostato)"
[[ -z "$CURRENT_SLEEP" ]] && CURRENT_SLEEP="(non impostato)"

NEW_SERV_TMOUT=60
NEW_HOST_TMOUT=60
NEW_DELAY="s"

if [[ "$MODE" == "auto" ]]; then
    echo -e "${YELLOW}Analisi automatica del carico...${NC}"
    if (( $(echo "$LOAD_NOW > $CORES*2" | bc -l) )); then
        NEW_CONC=20
        NEW_SLEEP=0.35
        COMMENT="Carico molto alto: limito concorrenza e aumento sleep."
    elif (( $(echo "$LOAD_NOW > $CORES*1" | bc -l) )); then
        NEW_CONC=25
        NEW_SLEEP=0.30
        COMMENT="Carico medio-alto: leggero bilanciamento."
    elif (( $(echo "$CPU_NOW > 70" | bc -l) )); then
        NEW_CONC=25
        NEW_SLEEP=0.30
        COMMENT="CPU alta: mantengo concorrenza media, aumento sleep."
    elif (( $(echo "$LOAD_NOW < $CORES*0.6" | bc -l) )) && (( $(echo "$CPU_NOW < 40" | bc -l) )); then
        NEW_CONC=35
        NEW_SLEEP=0.20
        COMMENT="Sottoutilizzato: aumento concorrenza."
    else
        NEW_CONC=30
        NEW_SLEEP=0.25
        COMMENT="Carico stabile: uso parametri bilanciati."
    fi

    echo
    echo -e "${GREEN}Decisione automatica:${NC}"
    echo "  max_concurrent_checks = $NEW_CONC"
    echo "  sleep_time            = $NEW_SLEEP"
    echo "  Commento: $COMMENT"
    echo
else
    echo -e "${YELLOW}Inserisci i nuovi valori (invio = default):${NC}"
    read -r -p "  max_concurrent_checks [30]: " NEW_CONC
    read -r -p "  service_check_timeout [60]: " NEW_SERV_TMOUT
    read -r -p "  host_check_timeout [60]: " NEW_HOST_TMOUT
    read -r -p "  sleep_time [0.25]: " NEW_SLEEP
    read -r -p "  inter_check_delay (n/s/d) [s]: " NEW_DELAY

    NEW_CONC=${NEW_CONC:-30}
    NEW_SERV_TMOUT=${NEW_SERV_TMOUT:-60}
    NEW_HOST_TMOUT=${NEW_HOST_TMOUT:-60}
    NEW_SLEEP=${NEW_SLEEP:-0.25}
    NEW_DELAY=${NEW_DELAY:-s}
fi

clear
echo -e "${CYAN}=== Riepilogo tuning ($MODE) ===${NC}"
printf "  - CPU: %s%% | Load: %s | Core: %s | Processi check: %s\n" "$CPU_NOW" "$LOAD_NOW" "$CORES" "$CHECKS_NOW"
printf "  - Parametri correnti: conc=%s, sleep=%s\n" "$CURRENT_CONC" "$CURRENT_SLEEP"
echo

echo -e "${GREEN}Nuovi parametri:${NC}"
cat <<EOF
max_concurrent_checks = $NEW_CONC
service_check_timeout = $NEW_SERV_TMOUT
host_check_timeout    = $NEW_HOST_TMOUT
sleep_time            = $NEW_SLEEP
service_inter_check_delay_method = $NEW_DELAY
EOF
echo

if [[ "$MODE" != "auto" ]]; then
    read -r -p "Applico queste modifiche? (s/n): " CONFIRM
    if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
        echo -e "${RED}Operazione annullata.${NC}"
        exit 0
    fi
else
    echo -e "${YELLOW}Applicazione automatica senza conferma utente.${NC}"
    sleep 2
fi

echo -e "${YELLOW}Scrittura configurazione...${NC}"
mkdir -p "$(dirname "$NAGIOS_CFG")"
cat > "$NAGIOS_CFG" <<EOF
# =========================================================
# Ottimizzazione Checkmk Nagios Core - generato automaticamente
# =========================================================
max_concurrent_checks=$NEW_CONC
service_check_timeout=$NEW_SERV_TMOUT
host_check_timeout=$NEW_HOST_TMOUT
sleep_time=$NEW_SLEEP
service_inter_check_delay_method=$NEW_DELAY
EOF

grep -q "^service_check_timeout" "$GLOBAL_MK" 2>/dev/null || echo "service_check_timeout = $NEW_SERV_TMOUT" >> "$GLOBAL_MK"
grep -q "^use_cache_for_checking" "$GLOBAL_MK" 2>/dev/null || echo "use_cache_for_checking = True" >> "$GLOBAL_MK"

echo -e "${YELLOW}Riavvio del sito $SITE...${NC}"
omd restart "$SITE"

echo -e "${YELLOW}Attendo 30s prima del benchmark finale...${NC}"
sleep 30

CPU_AFTER=$(mpstat 3 3 | awk '/Average/ && $12 ~ /[0-9.]+/ {s+=100-$12;c++} END{if(c) printf("%.2f",s/c); else print 0}')
LOAD_AFTER=$(awk '{print $1}' /proc/loadavg)
CHECKS_AFTER=$(ps -eo comm | grep -c '^check_' || true)

clear
echo -e "${CYAN}=== Benchmark prima e dopo ===${NC}"
printf "%-28s %-12s %-12s\n" "Parametro" "Prima" "Dopo"
printf "%-28s %-12s %-12s\n" "CPU Utilization (%)" "$CPU_NOW" "$CPU_AFTER"
printf "%-28s %-12s %-12s\n" "Load Average (1m)" "$LOAD_NOW" "$LOAD_AFTER"
printf "%-28s %-12s %-12s\n" "Processi check_*" "$CHECKS_NOW" "$CHECKS_AFTER"
echo
echo -e "${GREEN}Ottimizzazione completata!${NC}"
echo "Backup salvato in: $BACKUP_DIR"
echo
