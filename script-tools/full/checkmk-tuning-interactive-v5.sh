#!/usr/bin/env bash
# ===============================================================
# checkmk-tuning-interactive-v5.sh v5.1.1 (fixed, fail-safe)
# Autotune per Checkmk RAW (Nagios core) con backup e countdown.
# ===============================================================

set -euo pipefail

SITE="monitoring"
SITEPATH="/opt/omd/sites/$SITE"
NAGIOS_CFG="$SITEPATH/etc/nagios/nagios.d/tuning.cfg"
GLOBAL_MK="$SITEPATH/etc/check_mk/conf.d/wato/global.mk"
BACKUP_DIR="/root/checkmk_tuning_backup_$(date +%Y%m%d_%H%M%S)"
MODE="${1:-interactive}"

G='\033[1;32m'
Y='\033[1;33m'
C='\033[1;36m'
R='\033[1;31m'
N='\033[0m'

require() {
    for b in "$@"; do
        command -v "$b" >/dev/null 2>&1 || { echo -e "${R}Manca $b${N}"; exit 1; }
    done
}

require mpstat bc awk sed grep head tail

clear
echo -e "${C}=== Checkmk Tuning Tool v5.1.1 (fail-safe) ===${N}"
echo "Sito: $SITE | Modalità: $MODE"
echo "Backup in: $BACKUP_DIR"

mkdir -p "$BACKUP_DIR"
cp -a "$NAGIOS_CFG" "$BACKUP_DIR/" 2>/dev/null || true
cp -a "$GLOBAL_MK" "$BACKUP_DIR/" 2>/dev/null || true
echo

CORES=$(nproc)
CPU_NOW=$(mpstat 3 3 | awk '/Average/ && $12 ~ /[0-9.]+/ {s+=100-$12;c++} END{if(c) printf("%.2f",s/c); else print 0}')
LOAD_NOW=$(awk '{print $1}' /proc/loadavg)

echo -e "${Y}Stato sistema:${N} CPU=${CPU_NOW}% | Load=${LOAD_NOW} | Core=${CORES}"
echo

# Autotune semplice (baseline) basato su load/cpu
if (( $(echo "$LOAD_NOW > $CORES*2" | bc -l) )) || (( $(echo "$CPU_NOW > 80" | bc -l) )); then
    NEW_CONC=20
    NEW_SLEEP=0.35
elif (( $(echo "$LOAD_NOW > $CORES*1" | bc -l) )) || (( $(echo "$CPU_NOW > 70" | bc -l) )); then
    NEW_CONC=25
    NEW_SLEEP=0.30
elif (( $(echo "$LOAD_NOW < $CORES*0.6" | bc -l) )) && (( $(echo "$CPU_NOW < 40" | bc -l) )); then
    NEW_CONC=35
    NEW_SLEEP=0.20
else
    NEW_CONC=30
    NEW_SLEEP=0.25
fi

NEW_SVC_TO=60
NEW_HOST_TO=60
NEW_DELAY="s"

echo -e "${C}=== Riepilogo tuning ===${N}"
cat <<EOF
max_concurrent_checks = $NEW_CONC
service_check_timeout = $NEW_SVC_TO
host_check_timeout    = $NEW_HOST_TO
sleep_time            = $NEW_SLEEP
service_inter_check_delay_method = $NEW_DELAY
EOF
echo

if [[ "$MODE" != "--auto" && "$MODE" != "auto" ]]; then
    read -r -p "Applico queste modifiche? (s/n): " CONFIRM
    if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
        echo -e "${R}Operazione annullata.${N}"
        exit 0
    fi
else
    echo -e "${Y}Applicazione automatica tra 5 secondi (CTRL+C per annullare)...${N}"
    for i in 5 4 3 2 1; do
        echo -ne "  ${i}s...\r"
        sleep 1
    done
    echo
fi

mkdir -p "$(dirname "$NAGIOS_CFG")"
cat > "$NAGIOS_CFG" <<EOF
# Autotune generato automaticamente (v5.1.1 fail-safe)
max_concurrent_checks=$NEW_CONC
service_check_timeout=$NEW_SVC_TO
host_check_timeout=$NEW_HOST_TO
sleep_time=$NEW_SLEEP
service_inter_check_delay_method=$NEW_DELAY
EOF

grep -q "^use_cache_for_checking" "$GLOBAL_MK" 2>/dev/null || echo "use_cache_for_checking = True" >> "$GLOBAL_MK"

echo -e "${Y}Riavvio del sito...${N}"
omd restart "$SITE" >/dev/null

echo -e "${Y}Attesa 30s di quiete...${N}"
sleep 30

CPU_AFTER=$(mpstat 3 3 | awk '/Average/ && $12 ~ /[0-9.]+/ {s+=100-$12;c++} END{if(c) printf("%.2f",s/c); else print 0}')
LOAD_AFTER=$(awk '{print $1}' /proc/loadavg)
CHECKS_AFTER=$(ps -eo comm= | awk '$1 ~ /^check_/ {c++} END{print c+0}' 2>/dev/null || echo 0)

clear
echo -e "${C}=== Benchmark prima e dopo ===${N}"
printf "%-28s %-12s %-12s\n" "Parametro" "Prima" "Dopo"
printf "%-28s %-12s %-12s\n" "CPU Utilization (%)" "$CPU_NOW" "$CPU_AFTER"
printf "%-28s %-12s %-12s\n" "Load Average (1m)" "$LOAD_NOW" "$LOAD_AFTER"
printf "%-28s %-12s %-12s\n" "Processi check_*" "?" "$CHECKS_AFTER"
echo
echo -e "${G}Backup:${N} $BACKUP_DIR"
echo -e "${G}Fine (fail-safe).${N}"
