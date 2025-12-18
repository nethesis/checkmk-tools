#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: test-warning-alert.sh [--launcher PATH] [--log PATH] [--cache PATH] [--host HOST] [--service NAME]

Simula un alert WARNING di Checkmk impostando le variabili NOTIFY_* ed esegue il launcher.

Opzioni:
    --launcher PATH   Percorso launcher (default: /opt/checkmk-tools/script-notify-checkmk/remote/rydea_realip)
    --log PATH        File log da tailare (default: /var/log/ydea_notify.log)
    --cache PATH      File cache tickets (default: /tmp/ydea_checkmk_tickets.json)
    --host HOST       Hostname simulato (default: test-host-warning-<timestamp>)
    --service NAME    Servizio simulato (default: Test Service WARNING)
USAGE
}

LAUNCHER="/opt/checkmk-tools/script-notify-checkmk/remote/rydea_realip"
LOG_FILE="/var/log/ydea_notify.log"
CACHE_FILE="/tmp/ydea_checkmk_tickets.json"
HOST_NAME="test-host-warning-$(date +%s)"
SERVICE_DESC="Test Service WARNING"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --launcher) LAUNCHER="${2:-}"; shift 2 ;;
        --log) LOG_FILE="${2:-}"; shift 2 ;;
        --cache) CACHE_FILE="${2:-}"; shift 2 ;;
        --host) HOST_NAME="${2:-}"; shift 2 ;;
        --service) SERVICE_DESC="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
    esac
done

if [[ -z "$LAUNCHER" || -z "$LOG_FILE" || -z "$CACHE_FILE" || -z "$HOST_NAME" || -z "$SERVICE_DESC" ]]; then
    echo "ERROR: missing required value" >&2
    usage
    exit 2
fi

say() { printf '%s\n' "$*"; }
section() { say; say "=== $* ==="; }

export NOTIFY_WHAT="SERVICE"
export NOTIFY_HOSTNAME="$HOST_NAME"
export NOTIFY_SERVICEDESC="$SERVICE_DESC"
export NOTIFY_SERVICESTATE="WARNING"
export NOTIFY_LASTSERVICESTATE="OK"
export NOTIFY_NOTIFICATIONTYPE="PROBLEM"
export NOTIFY_SERVICEOUTPUT="Test WARNING output - simulazione alert"
export NOTIFY_LONGSERVICEOUTPUT="Dettagli aggiuntivi del test WARNING"
export NOTIFY_SERVICEACKAUTHOR=""
export NOTIFY_SERVICEACKCOMMENT=""
export NOTIFY_LONGDATETIME="$(date '+%Y-%m-%d %H:%M:%S')"
export NOTIFY_SHORTDATETIME="$(date '+%Y-%m-%d %H:%M:%S')"
export NOTIFY_CONTACTNAME="checkmk-notify"
export NOTIFY_HOSTADDRESS="192.168.1.100"
export NOTIFY_HOSTATTEMPT="1"
export NOTIFY_HOSTMAXATTEMPTS="3"
export NOTIFY_SERVICESTATETYPE="HARD"

section "TEST WARNING ALERT"
say "Host: $NOTIFY_HOSTNAME"
say "Service: $NOTIFY_SERVICEDESC"
say "State: $NOTIFY_LASTSERVICESTATE -> $NOTIFY_SERVICESTATE"
say "Output: $NOTIFY_SERVICEOUTPUT"
say "Launcher: $LAUNCHER"

section "1) Verifica launcher"
if [[ ! -f "$LAUNCHER" ]]; then
    say "ERROR: launcher non trovato: $LAUNCHER" >&2
    exit 1
fi
if [[ ! -x "$LAUNCHER" ]]; then
    say "WARN: launcher non eseguibile; provo con /bin/bash" >&2
fi

section "2) Esecuzione launcher"
set +e
if [[ -x "$LAUNCHER" ]]; then
    "$LAUNCHER"
    LAUNCHER_RC=$?
else
    /bin/bash "$LAUNCHER"
    LAUNCHER_RC=$?
fi
set -e
say "Exit code: $LAUNCHER_RC"

section "3) Ultimi log"
if [[ -f "$LOG_FILE" ]]; then
    tail -n 30 "$LOG_FILE" || true
else
    say "WARN: log non disponibile: $LOG_FILE"
fi

section "4) Cache tickets"
if [[ -f "$CACHE_FILE" ]]; then
    if command -v jq >/dev/null 2>&1; then
        jq -r --arg hn "$NOTIFY_HOSTNAME" 'to_entries[] | select(.key | contains($hn)) | "\(.key): ticket #\(.value.ticket_id) - stato \(.value.state)"' "$CACHE_FILE" 2>/dev/null || true
    else
        say "WARN: jq non disponibile; non posso filtrare la cache JSON"
    fi
else
    say "WARN: cache non disponibile: $CACHE_FILE"
fi

section "FINE"

# Nota: il contenuto precedente (corrotto) è stato rimosso; usare git history se serve.
echo "=========================================="
echo "Test completato!"
echo "Controlla:"
echo "1. Ticket creato su Ydea con priorit├á 'high' (3)"
echo "2. SLA_ID = 147 (8-tipologie)"
echo "3. Titolo: [WARNING] $NOTIFY_HOSTNAME - Test Service WARNING"
echo "=========================================="

CORRUPTED_d003f84d013e4aa387e07f95772e91b0

