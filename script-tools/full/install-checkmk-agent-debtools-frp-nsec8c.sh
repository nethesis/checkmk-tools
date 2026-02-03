#!/bin/sh
set -eu

# install-checkmk-agent-debtools-frp-nsec8c.sh
# Install / uninstall Checkmk agent + (opzionale) FRP client su OpenWrt / NethSecurity (init: procd).
# Output semplice (ASCII-only).

CUSTOMFEEDS="${CUSTOMFEEDS:-/etc/opkg/customfeeds.conf}"
TMPDIR="${TMPDIR:-/tmp/checkmk-deb}"

# Rileva automaticamente versione OpenWrt e architettura
detect_openwrt_params() {
    # Leggi versione OpenWrt da /etc/os-release
    if [ -f /etc/os-release ]; then
        OPENWRT_VERSION=$(grep '^VERSION=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | cut -d' ' -f1)
    fi
    
    # Fallback: prova da /etc/openwrt_release
    if [ -z "$OPENWRT_VERSION" ] && [ -f /etc/openwrt_release ]; then
        OPENWRT_VERSION=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d"'" -f2)
    fi
    
    # Default se non trovato
    OPENWRT_VERSION="${OPENWRT_VERSION:-23.05.0}"
    
    # Rileva architettura
    OPENWRT_ARCH=$(opkg print-architecture 2>/dev/null | grep -v 'all' | grep -v 'noarch' | tail -1 | awk '{print $2}')
    OPENWRT_ARCH="${OPENWRT_ARCH:-x86_64}"
    
    log "Sistema: OpenWrt $OPENWRT_VERSION ($OPENWRT_ARCH)"
}

# Repository verranno impostati dopo detect_openwrt_params()
REPO_BASE=""
REPO_PACKAGES=""

# Server CheckMK per download agent
CHECKMK_SERVER="${CHECKMK_SERVER:-https://monitoring.nethlab.it/monitoring}"

# URL del .deb dell'agente - verrà rilevato automaticamente
DEB_URL=""

FRP_VER="${FRP_VER:-0.64.0}"
FRPC_BIN="${FRPC_BIN:-/usr/local/bin/frpc}"
FRPC_CONF="${FRPC_CONF:-/etc/frp/frpc.toml}"
FRPC_INIT="${FRPC_INIT:-/etc/init.d/frpc}"
FRPC_LOG="${FRPC_LOG:-/var/log/frpc.log}"

log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
die() { echo "[ERR] $*" >&2; exit 1; }

is_root() {
    [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ]
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "comando mancante: $1"
}

add_repo() {
    name="$1"
    url="$2"
    grep -q "$url" "$CUSTOMFEEDS" 2>/dev/null || echo "src/gz $name $url" >>"$CUSTOMFEEDS"
}

uninstall_all() {
    log "Disinstallazione Checkmk Agent + FRP client"

    if [ -x "$FRPC_INIT" ]; then
        /etc/init.d/frpc stop >/dev/null 2>&1 || true
        /etc/init.d/frpc disable >/dev/null 2>&1 || true
    fi

    if [ -x /etc/init.d/check_mk_agent ]; then
        /etc/init.d/check_mk_agent stop >/dev/null 2>&1 || true
        /etc/init.d/check_mk_agent disable >/dev/null 2>&1 || true
        rm -f /etc/init.d/check_mk_agent
    fi

    killall frpc socat >/dev/null 2>&1 || true

    rm -rf /etc/frp >/dev/null 2>&1 || true
    rm -f "$FRPC_BIN" "$FRPC_INIT" "$FRPC_LOG" >/dev/null 2>&1 || true

    rm -f /usr/bin/check_mk_agent >/dev/null 2>&1 || true
    rm -rf /etc/check_mk /etc/xinetd.d/check_mk >/dev/null 2>&1 || true

    log "Disinstallazione completata"
}

install_prereqs() {
    need_cmd opkg
    
    # Rileva parametri sistema
    detect_openwrt_params
    
    # Imposta repository con versione/arch rilevate
    REPO_BASE="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/packages/${OPENWRT_ARCH}/base"
    REPO_PACKAGES="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/packages/${OPENWRT_ARCH}/packages"

    log "Configuro repository (customfeeds)"
    mkdir -p "$(dirname "$CUSTOMFEEDS")" 2>/dev/null || true
    [ -f "$CUSTOMFEEDS" ] || : >"$CUSTOMFEEDS"

    add_repo "openwrt_base" "$REPO_BASE"
    add_repo "openwrt_packages" "$REPO_PACKAGES"

    log "opkg update"
    opkg update

    log "Verifica/installa tool necessari (binutils/tar/gzip/wget/socat/ca-certificates)"
    # Verifica quali pacchetti sono già installati
    PKGS_NEEDED=""
    for pkg in binutils tar gzip wget socat ca-certificates; do
        if ! opkg list-installed | grep -q "^$pkg "; then
            PKGS_NEEDED="$PKGS_NEEDED $pkg"
        fi
    done
    
    if [ -n "$PKGS_NEEDED" ]; then
        log "Installo pacchetti mancanti:$PKGS_NEEDED"
        opkg install $PKGS_NEEDED || die "opkg install fallito"
    else
        log "Tutti i pacchetti necessari sono già installati"
    fi

    need_cmd ar
    need_cmd tar
    need_cmd wget
    need_cmd socat
}

install_agent() {
    log "Installazione Checkmk agent"

    # Rileva versione CheckMK disponibile
    if [ -z "$DEB_URL" ]; then
        log "Rilevamento versione CheckMK disponibile..."
        AGENT_LIST=$(wget -qO- "$CHECKMK_SERVER/check_mk/agents/" 2>/dev/null | grep -o 'check-mk-agent_[0-9.p]*-[0-9]*_all\.deb' | sort -V | tail -1)
        
        if [ -z "$AGENT_LIST" ]; then
            die "Impossibile rilevare versione agent da $CHECKMK_SERVER/check_mk/agents/"
        fi
        
        DEB_URL="$CHECKMK_SERVER/check_mk/agents/$AGENT_LIST"
        log "Versione rilevata: $AGENT_LIST"
    fi

    rm -rf "$TMPDIR" >/dev/null 2>&1 || true
    mkdir -p "$TMPDIR/data"
    cd "$TMPDIR" || die "cd fallito: $TMPDIR"

    log "Download .deb agente da: $DEB_URL"
    if ! wget -O check-mk-agent.deb "$DEB_URL" 2>/dev/null; then
        warn "Primo tentativo fallito, retry con --no-check-certificate..."
        wget --no-check-certificate -O check-mk-agent.deb "$DEB_URL" || die "download fallito dopo retry: $DEB_URL (verificare connessione e URL)"
    fi

    log "Estrazione .deb (ar + tar)"
    ar x check-mk-agent.deb || die "ar x fallito"

    # Debian packages: data.tar.gz or data.tar.xz
    if [ -f data.tar.gz ]; then
        tar -xzf data.tar.gz -C data || die "tar -xzf fallito"
    elif [ -f data.tar.xz ]; then
        tar -xJf data.tar.xz -C data || die "tar -xJf fallito"
    else
        die "data.tar.* non trovato nel .deb"
    fi

    if [ ! -f data/usr/bin/check_mk_agent ]; then
        die "file mancante dopo estrazione: data/usr/bin/check_mk_agent"
    fi

    log "Copia binario agente"
    mkdir -p /usr/bin
    cp -f data/usr/bin/check_mk_agent /usr/bin/check_mk_agent
    chmod +x /usr/bin/check_mk_agent

    log "Copia configurazione (best effort)"
    mkdir -p /etc/check_mk
    if [ -d data/etc/check_mk ]; then
        cp -rf data/etc/check_mk/* /etc/check_mk/ 2>/dev/null || true
    fi

    cd / || true
    rm -rf "$TMPDIR" >/dev/null 2>&1 || true

    log "Agente installato: /usr/bin/check_mk_agent"
}

install_agent_service() {
    log "Creo servizio procd (socat listener su 6556)"

    cat >/etc/init.d/check_mk_agent <<'EOF'
#!/bin/sh /etc/rc.common
START=98
STOP=10
USE_PROCD=1

PROG=/usr/bin/check_mk_agent

start_service() {
    procd_open_instance
    procd_set_param respawn
    procd_set_param command socat TCP-LISTEN:6556,reuseaddr,fork,keepalive EXEC:$PROG
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall socat >/dev/null 2>&1 || true
}
EOF

    chmod +x /etc/init.d/check_mk_agent
    /etc/init.d/check_mk_agent enable >/dev/null 2>&1 || true
    /etc/init.d/check_mk_agent restart >/dev/null 2>&1 || /etc/init.d/check_mk_agent start >/dev/null 2>&1 || true

    # Best effort check
    if pgrep -f "socat TCP-LISTEN:6556" >/dev/null 2>&1; then
        log "Checkmk agent in ascolto su TCP 6556 (socat)"
    else
        warn "socat non risulta in esecuzione: verificare /etc/init.d/check_mk_agent e log di sistema"
    fi
}

install_frp() {
    # Skip se non interattivo (curl | bash, script automatico, etc.)
    if ! [ -t 0 ]; then
        log "Skip configurazione FRP (esecuzione non-interattiva)"
        log "Per configurare FRP: eseguire lo script manualmente"
        return 0
    fi
    
    echo ""
    echo "Installazione FRP client (opzionale)"
    echo "Server remoto: monitor.nethlab.it:7000"
    echo ""

    printf "Vuoi installare e configurare il client FRP? [y/N]: "
    read ans || ans=""
    ans_lc=$(printf "%s" "$ans" | tr '[:upper:]' '[:lower:]')
    case "$ans_lc" in
        y|yes|s|si) ;;
        *) return 0 ;;
    esac

    SERVER_ADDR="monitor.nethlab.it"
    SERVER_PORT="7000"

    while :; do
        printf "Inserisci la remote_port da assegnare (es. 6020): "
        read REMOTE_PORT || REMOTE_PORT=""
        echo "$REMOTE_PORT" | grep -Eq '^[0-9]+$' && break
        echo "Valore non valido"
    done

    printf "Inserisci la chiave/token FRP: "
    read FRP_TOKEN || FRP_TOKEN=""
    [ -n "$FRP_TOKEN" ] || die "token FRP vuoto"

    DEFAULT_NAME="$(hostname 2>/dev/null || echo openwrt-host)"
    printf "Nome proxy FRP (default: %s): " "$DEFAULT_NAME"
    read PROXY_NAME || PROXY_NAME=""
    [ -n "$PROXY_NAME" ] || PROXY_NAME="$DEFAULT_NAME"

    cd /tmp || die "cd /tmp fallito"
    FRP_TGZ="frp_${FRP_VER}_linux_amd64.tar.gz"
    FRP_DL="https://github.com/fatedier/frp/releases/download/v${FRP_VER}/${FRP_TGZ}"

    log "Download FRP v$FRP_VER"
    wget -O "$FRP_TGZ" "$FRP_DL" || die "download FRP fallito"

    log "Estrazione FRP"
    tar -xzf "$FRP_TGZ" || die "tar frp fallito"
    FRP_DIR="$(tar -tzf "$FRP_TGZ" | head -n1 | cut -d/ -f1)"

    [ -n "$FRP_DIR" ] || die "impossibile determinare directory estratta"
    [ -f "$FRP_DIR/frpc" ] || die "frpc non trovato nel tarball"

    mkdir -p "$(dirname "$FRPC_BIN")" /etc/frp /var/log
    cp -f "$FRP_DIR/frpc" "$FRPC_BIN"
    chmod +x "$FRPC_BIN"

    rm -f "$FRP_TGZ"
    rm -rf "$FRP_DIR"

    log "Scrivo configurazione TOML: $FRPC_CONF"
    cat >"$FRPC_CONF" <<EOF
serverAddr = "$SERVER_ADDR"
serverPort = $SERVER_PORT

auth.method = "token"
auth.token = "$FRP_TOKEN"

transport.tls.enable = true

log.to = "$FRPC_LOG"
log.level = "info"

[[proxies]]
name = "$PROXY_NAME"
type = "tcp"
localIP = "127.0.0.1"
localPort = 6556
remotePort = $REMOTE_PORT
EOF

    log "Creo servizio procd FRP: $FRPC_INIT"
    cat >"$FRPC_INIT" <<'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param respawn
    procd_set_param command /usr/local/bin/frpc -c /etc/frp/frpc.toml
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall frpc >/dev/null 2>&1 || true
}
EOF

    chmod +x "$FRPC_INIT"
    /etc/init.d/frpc enable >/dev/null 2>&1 || true
    /etc/init.d/frpc restart >/dev/null 2>&1 || /etc/init.d/frpc start >/dev/null 2>&1 || true

    if pgrep -f frpc >/dev/null 2>&1; then
        log "FRP attivo: proxy=$PROXY_NAME remote_port=$REMOTE_PORT"
    else
        warn "FRP non risulta in esecuzione: controllare log $FRPC_LOG"
    fi
}

main() {
    if [ "${1:-}" = "--uninstall" ]; then
        is_root || die "eseguire come root"
        uninstall_all
        exit 0
    fi

    is_root || die "eseguire come root"

    install_prereqs
    install_agent
    install_agent_service
    install_frp

    echo ""
    echo "Installazione completata"
    echo "Test agent locale: nc 127.0.0.1 6556 | head"
    echo "Config FRP: $FRPC_CONF"
    echo "Disinstallazione: sh $0 --uninstall"
}

main "$@"
