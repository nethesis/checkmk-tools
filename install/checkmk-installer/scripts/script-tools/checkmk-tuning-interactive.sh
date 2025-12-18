#!/usr/bin/env bash
# ===============================================================
# checkmk-tuning-interactive.sh v2.0 (fixed)
# Tuning interattivo per Checkmk Raw Edition (Nagios core)
# ===============================================================

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

clear
echo -e "${CYAN}=== Checkmk Tuning Interattivo (v2.0) ===${NC}"
echo "Sito: $SITE"
echo "Backup in: $BACKUP_DIR"
echo

mkdir -p "$BACKUP_DIR"
cp -a "$NAGIOS_CFG" "$BACKUP_DIR/" 2>/dev/null || true
cp -a "$GLOBAL_MK" "$BACKUP_DIR/" 2>/dev/null || true

get_cfg_value() {
	local key="$1"
	grep -E "^${key}=" "$NAGIOS_CFG" 2>/dev/null | awk -F= '{print $2}' | xargs
}

CURRENT_CONC=$(get_cfg_value "max_concurrent_checks")
CURRENT_SERV_TMOUT=$(get_cfg_value "service_check_timeout")
CURRENT_HOST_TMOUT=$(get_cfg_value "host_check_timeout")
CURRENT_SLEEP=$(get_cfg_value "sleep_time")
CURRENT_DELAY=$(get_cfg_value "service_inter_check_delay_method")

[[ -z "$CURRENT_CONC" ]] && CURRENT_CONC="(non impostato)"
[[ -z "$CURRENT_SERV_TMOUT" ]] && CURRENT_SERV_TMOUT="(non impostato)"
[[ -z "$CURRENT_HOST_TMOUT" ]] && CURRENT_HOST_TMOUT="(non impostato)"
[[ -z "$CURRENT_SLEEP" ]] && CURRENT_SLEEP="(non impostato)"
[[ -z "$CURRENT_DELAY" ]] && CURRENT_DELAY="(non impostato)"

echo -e "${YELLOW}Impostazioni attuali:${NC}"
printf "  - max_concurrent_checks = %s\n" "$CURRENT_CONC"
printf "  - service_check_timeout = %s\n" "$CURRENT_SERV_TMOUT"
printf "  - host_check_timeout    = %s\n" "$CURRENT_HOST_TMOUT"
printf "  - sleep_time            = %s\n" "$CURRENT_SLEEP"
printf "  - inter_check_delay     = %s\n" "$CURRENT_DELAY"
echo

echo -e "${YELLOW}Inserisci i nuovi valori (invio = default consigliato):${NC}"
read -r -p "  max_concurrent_checks [30]: " NEW_CONC
read -r -p "  service_check_timeout (sec) [60]: " NEW_SERV_TMOUT
read -r -p "  host_check_timeout (sec) [60]: " NEW_HOST_TMOUT
read -r -p "  sleep_time (sec fra i check) [0.25]: " NEW_SLEEP
read -r -p "  inter_check_delay (n=none / s=spread / d=smart) [s]: " NEW_DELAY

NEW_CONC=${NEW_CONC:-30}
NEW_SERV_TMOUT=${NEW_SERV_TMOUT:-60}
NEW_HOST_TMOUT=${NEW_HOST_TMOUT:-60}
NEW_SLEEP=${NEW_SLEEP:-0.25}
NEW_DELAY=${NEW_DELAY:-s}

clear
echo -e "${CYAN}=== Riepilogo configurazione ===${NC}"
echo
echo -e "${GREEN}Nuovi valori proposti:${NC}"
cat <<EOF
max_concurrent_checks = $NEW_CONC
service_check_timeout = $NEW_SERV_TMOUT
host_check_timeout    = $NEW_HOST_TMOUT
sleep_time            = $NEW_SLEEP
service_inter_check_delay_method = $NEW_DELAY
EOF
echo

read -r -p "Applico queste modifiche? (s/n): " CONFIRM
if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
	echo -e "${RED}Operazione annullata.${NC}"
	exit 0
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

echo
echo -e "${YELLOW}Riavvio del sito $SITE...${NC}"
omd restart "$SITE"

echo
echo -e "${CYAN}Ultime righe del log Nagios:${NC}"
su -s /bin/bash -c "tail -n 10 '$SITEPATH/var/nagios/nagios.log'" "$SITE" 2>/dev/null || tail -n 10 "$SITEPATH/var/nagios/nagios.log" 2>/dev/null || true

echo
echo -e "${CYAN}Processi di check attivi:${NC}"
ps -eo comm | grep -c '^check_' || true

echo
echo -e "${GREEN}Ottimizzazione completata!${NC}"
echo "Backup salvato in: $BACKUP_DIR"
echo
