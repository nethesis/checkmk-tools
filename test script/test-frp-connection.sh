#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: test-frp-connection.sh [--host HOST] [--port PORT] [--site SITE] [--user USER]

Diagnostica di base per connessione FRP + Checkmk.

Opzioni:
    --host HOST   Host Checkmk (default: WS2022AD)
    --port PORT   Porta FRP server da verificare (default: 6045)
    --site SITE   Nome sito OMD (default: monitoring)
    --user USER   Utente site (default: monitoring)

Note:
    - Alcuni step richiedono accesso a `su` e ai comandi Checkmk (`cmk`).
    - Il test TCP usa `nc` se disponibile, altrimenti /dev/tcp.
USAGE
}

HOST_NAME="WS2022AD"
FRP_PORT="6045"
OMD_SITE="monitoring"
SITE_USER="monitoring"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host) HOST_NAME="${2:-}"; shift 2 ;;
        --port) FRP_PORT="${2:-}"; shift 2 ;;
        --site) OMD_SITE="${2:-}"; shift 2 ;;
        --user) SITE_USER="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
    esac
done

if [[ -z "$HOST_NAME" || -z "$FRP_PORT" || -z "$OMD_SITE" || -z "$SITE_USER" ]]; then
    echo "ERROR: missing required value" >&2
    usage
    exit 2
fi

say() { printf '%s\n' "$*"; }
section() { say; say "=== $* ==="; }

check_listen_port() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -ltnp 2>/dev/null | grep -E "[:\.]${port}[[:space:]]" >/dev/null 2>&1
        return $?
    fi
    if command -v netstat >/dev/null 2>&1; then
        netstat -tlnp 2>/dev/null | grep ":${port} " >/dev/null 2>&1
        return $?
    fi
    return 127
}

tcp_probe() {
    local host="$1"
    local port="$2"
    local out_file="$3"
    : >"$out_file"

    if command -v timeout >/dev/null 2>&1; then
        if command -v nc >/dev/null 2>&1; then
            timeout 5 bash -c "printf '<<<check_mk>>>\\n' | nc -w 4 '$host' '$port'" >"$out_file" 2>&1 || true
            return 0
        fi
        timeout 5 bash -c "exec 3<>/dev/tcp/$host/$port; printf '<<<check_mk>>>\\n' >&3; cat <&3" >"$out_file" 2>&1 || true
        return 0
    fi

    if command -v nc >/dev/null 2>&1; then
        printf '<<<check_mk>>>\n' | nc -w 4 "$host" "$port" >"$out_file" 2>&1 || true
        return 0
    fi
    bash -c "exec 3<>/dev/tcp/$host/$port; printf '<<<check_mk>>>\\n' >&3; cat <&3" >"$out_file" 2>&1 || true
}

run_as_site() {
    local cmd="$1"
    if command -v su >/dev/null 2>&1; then
        su - "$SITE_USER" -c "$cmd"
        return $?
    fi
    echo "WARN: 'su' not available; cannot run as site user ($SITE_USER)" >&2
    return 127
}

section "DIAGNOSTICA CONNESSIONE FRP"
say "Host Checkmk: $HOST_NAME"
say "Site: $OMD_SITE (user: $SITE_USER)"
say "Porta FRP: $FRP_PORT"

section "1) Verifica listen FRP server"
if check_listen_port "$FRP_PORT"; then
    say "OK: una porta in ascolto su :$FRP_PORT"
else
    rc=$?
    if [[ $rc -eq 127 ]]; then
        say "WARN: impossibile verificare (manca ss/netstat)"
    else
        say "WARN: nessun listener trovato su :$FRP_PORT"
    fi
    if command -v systemctl >/dev/null 2>&1; then
        systemctl status frps 2>/dev/null || true
    fi
fi

section "2) Test TCP verso localhost:$FRP_PORT"
TMP_FILE="/tmp/frp_test_${HOST_NAME}_${FRP_PORT}_$$.txt"
tcp_probe "localhost" "$FRP_PORT" "$TMP_FILE"
if [[ -s "$TMP_FILE" ]]; then
    say "OK: output ricevuto (prime righe):"
    head -n 20 "$TMP_FILE" || true
else
    say "WARN: nessun output ricevuto"
    if [[ -f "$TMP_FILE" ]]; then
        say "Dettaglio:"; sed -n '1,40p' "$TMP_FILE" || true
    fi
fi
rm -f "$TMP_FILE" || true

section "3) Config Checkmk (cmk -D $HOST_NAME)"
run_as_site "cmk -D '$HOST_NAME'" 2>&1 | grep -E "(Address|IP|Port|datasource_programs|datasource_program)" | head -n 50 || true

section "4) Test connessione Checkmk (cmk -d $HOST_NAME)"
run_as_site "cmk -d '$HOST_NAME'" 2>&1 | head -n 60 || true

section "5) Ricerca regole agent port/tcp timeout (conf.d)"
run_as_site "cd '/omd/sites/$OMD_SITE/etc/check_mk/conf.d' 2>/dev/null && grep -RInE 'tcp_connect_timeout|agent.*port' ." 2>/dev/null | head -n 80 || true

section "6) Nota su frpc lato client"
say "Verifica sul client Windows che frpc sia in esecuzione e connesso."
say "Esempi (PowerShell):"
say "  Get-Service frpc"
say "  netstat -ano | findstr 6556"

section "FINE"

# Nota: il contenuto precedente (corrotto) è stato rimosso; usare git history se serve.

