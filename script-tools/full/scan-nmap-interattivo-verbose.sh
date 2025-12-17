#!/bin/bash
/usr/bin/env bash
#
# scan-nmap-interattivo-verbose.sh
# Interattivo Nmap: scelta target (range/file), scelta modalit├â┬á (port-scan / discovery-only),
# e scelta livello di verbosit├â┬á (none, -v, -vv, debug/packet-trace).
# Output: ./scans/nmap-YYYYmmddTHHMMSS_<label>.txt e _summary.txt
#set -euo pipefail
DEFAULT_OUTDIR="./scans"
DEFAULT_PORTS="1-1024"TIMESTAMP() { date +%Y%m%dT%H%M%S; }
NMAP_BIN="$(command -v nmap || true)"if [[ -z "$NMAP_BIN" ]]; then  
echo "Errore: nmap non trovato nel PATH. Installa nmap e riprova." >&2  
echo "Su CentOS/NethServer: yum install -y nmap"  exit 2fi
echo "=== SCAN NMAP INTERATTIVO (opzione discovery verboso) ==="echo
# TARGET MODEwhile true; do  read -rp "Vuoi scansionare (1) subnet/range/host oppure (2) file targets? [1/2] (default 1): " MODE  
MODE="${MODE:-1}"  if [[ "$MODE" == "1" || "$MODE" == "2" ]]; then break; fi  
echo "Risposta non valida. Inserisci 1 o 2."done
TARGET_ARG=""
LABEL=""
TARGET_FILE=""if [[ "$MODE" == "1" ]]; then  read -rp "Inserisci subnet/host/range (es. 192.168.1.0/24 o 10.0.0.1-254 o 192.168.1.10): " RANGE  
RANGE="${RANGE:-}"  if [[ -z "$RANGE" ]]; then    
echo "Errore: nessun target fornito. Uscita." >&2    exit 3  fi  
TARGET_ARG="$RANGE"  
LABEL="$(
echo "$RANGE" | tr -c '[:alnum:]_.' '_')"else  read -rp "Inserisci percorso file targets (uno per riga, IP/host/CIDR): " TARGET_FILE  
TARGET_FILE="${TARGET_FILE:-}"  if [[ -z "$TARGET_FILE" || ! -f "$TARGET_FILE" ]]; then    
echo "Errore: file targets non vali
do o non esistente: $TARGET_FILE" >&2    exit 4  fi  
TARGET_ARG="-iL $TARGET_FILE"  
LABEL="$(basename "$TARGET_FILE" | tr -c '[:alnum:]_-' '_')"fi
# SCAN TYPEwhile true; do  
echo  
echo "Tipo scansione:"  
echo "  1) Scan porte (default)     -- porta scan"  
echo "  2) Discovery only (no port scan) -- nmap -sn"  read -rp "Scegli 1 o 2 [default 1]: " SCAN_CHOICE  
SCAN_CHOICE="${SCAN_CHOICE:-1}"  if [[ "$SCAN_CHOICE" == "1" || "$SCAN_CHOICE" == "2" ]]; then break; fi  
echo "Risposta non valida."done
PORTS="$DEFAULT_PORTS"
if [[ "$SCAN_CHOICE" == "1" ]]; then  read -rp "Porte da scansionare (es. 22,80,443 o 1-65535) [default: ${DEFAULT_PORTS}]: " INPUT_PORTS  
PORTS="${INPUT_PORTS:-$DEFAULT_PORTS}"fi
# VERBOSITY / DEBUG (applies especially to discovery-only if selected)echo
echo "Livello verbosit├â┬á / debug:"
echo "  0) Nessuna verbosit├â┬á extra (default)"
echo "  1) Verbose (-v)"
echo "  2) Very verbose (-vv)"
echo "  3) Debug (+ -d) (dettagli interni) e opzione --packet-trace (traccia pacchetti)"read -rp "Scegli 0|1|2|3 [default 0]: " 
VLEVELVLEVEL="${VLEVEL:-0}"if ! [[ "$VLEVEL" =~ ^[0-3]$ ]]; then 
VLEVEL=0; fi
# OTHER OPTIONSread -rp "Directory output [default: ${DEFAULT_OUTDIR}]: " 
OUTDIROUTDIR="${OUTDIR:-$DEFAULT_OUTDIR}"read -rp "Timing template nmap 0..5 [default 3]: " 
NTNT="${NT:-3}"if ! [[ "$NT" =~ ^[0-5]$ ]]; then 
NT=3; fi
# Confirmecho
echo "Riepilogo:"if [[ "$MODE" == "1" ]]; then  
echo "  Target: $TARGET_ARG"
else  
echo "  Targets file: $TARGET_FILE"fi
if [[ "$SCAN_CHOICE" == "1" ]]; then  
echo "  Modalit├â┬á: Scan porte"  
echo "  Porte: $PORTS"
else  
echo "  Modalit├â┬á: Discovery only (no port scan) - equivalente a -sn"ficase "$VLEVEL" in  0) 
echo "  Verbosit├â┬á: nessuna extra" ;;  1) 
echo "  Verbosit├â┬á: -v" ;;  2) 
echo "  Verbosit├â┬á: -vv" ;;  3) 
echo "  Verbosit├â┬á: debug (-d) + --packet-trace" ;;esac
echo "  Output dir: $OUTDIR"
echo "  Timing template: -T$NT"echoread -rp "Procedere con la scansione? [y/N]: " 
CONFCONF="${CONF:-N}"if [[ ! "$CONF" =~ ^[Yy]$ ]]; then  
echo "Annullato dall'utente."  exit 0fimkdir -p "$OUTDIR"
if [[ ! -w "$OUTDIR" ]]; then  
echo "Errore: directory $OUTDIR non scrivibile." >&2  exit 5fi
TS="$(TIMESTAMP)"
OUTBASE="${OUTDIR%/}/nmap-${TS}_${LABEL}"
OUTTXT="${OUTBASE}.txt"
OUTSUM="${OUTBASE}_summary.txt"
# Build nmap flags depending on choices
NMAP_OPTS=()
# verbosit├â┬áif [[ "$VLEVEL" -eq 1 ]]; then  NMAP_OPTS+=( -v )el
if [[ "$VLEVEL" -eq 2 ]]; then  NMAP_OPTS+=( -vv )el
if [[ "$VLEVEL" -eq 3 ]]; then  NMAP_OPTS+=( -d --packet-trace )fi
# reason to show cause for host/port decisionsNMAP_OPTS+=( --reason -T"${NT}" )if [[ "$SCAN_CHOICE" == "2" ]]; then  
# discovery-only  NMAP_OPTS+=( -sn )else  
# port scan: choose SYN if root, altrimenti connect  if [[ "$(id -u)" -eq 0 ]]; then    NMAP_OPTS+=( -sS -p "$PORTS" )  else    NMAP_OPTS+=( -sT -p "$PORTS" )  fi
fi
# assemble command
NMAP_CMD=( "$NMAP_BIN" "${NMAP_OPTS[@]}" )if [[ "$MODE" == "2" ]]; then  NMAP_CMD+=( -iL "$TARGET_FILE" )else  NMAP_CMD+=( "$TARGET_ARG" )fiNMAP_CMD+=( -oN "$OUTTXT" )echo
echo "Eseguo nmap..."
echo "Coman
do: ${NMAP_CMD[*]}"echo
# Run nmap
if "${NMAP_CMD[@]}"; then  
EC=0else  
EC=$?fi
# Produce summary: adattivo in base alla modalit├â┬áif [[ "$SCAN_CHOICE" == "2" ]]; then  
# discovery: includi host up + eventuale MAC/hostname e (se verbose/debug) linee di packet-trace nel file normale  awk '  /^Nmap scan report for/ { host=$0; next }  /Host is up/ { print host " | Host is up " $0 }  /^MAC Address:/ { print "   " $0 }  ' "$OUTTXT" > "$OUTSUM" || true  
# fallback se vuoto  if [[ ! -s "$OUTSUM" ]]; then    grep -E "Nmap scan report for|Host is up|MAC Address" "$OUTTXT" > "$OUTSUM" || true  fi
else  
# port scan summary: host + porte aperte compatto  awk '  /^Nmap scan report for/ { host=$0 }/^PORT/ { inports=1; next }/^$/ { inports=0 }inports && NF { print host " | " $0 }' "$OUTTXT" > "$OUTSUM" || truefiecho
echo "Fine scansione (exit code: $EC)"
echo "Output: $OUTTXT"
echo "Summary: $OUTSUM"exit $EC
