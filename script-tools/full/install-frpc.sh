#!/usr/bin/env bash
# ==================================================
# install-frpc.sh
# Installazione e configurazione FRPC client (0.64.0)
# RockyLinux / NethServer / Debian / Proxmox
# ==================================================

set -e

FRP_VERSION="0.64.0"
FRP_URL_DEFAULT="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"

# Optional default from environment (no hardcoded secret)
FRP_TOKEN_DEFAULT="${FRP_TOKEN:-}"

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        echo "Errore: eseguire come root." >&2
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        if grep -qi "rocky" /etc/os-release; then echo "rockylinux"; return; fi
        if grep -qi "nethserver" /etc/os-release; then echo "nethserver"; return; fi
        if grep -qi "debian" /etc/os-release; then
            if command -v dpkg >/dev/null 2>&1 && dpkg -l 2>/dev/null | grep -q pve-manager; then
                echo "proxmox"; return
            fi
            echo "debian"; return
        fi
    fi
    echo "altro"
}

install_frpc_binary() {
    local url="$1"
    local tmpdir
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    mkdir -p /usr/local/bin /usr/local/src
    echo "Download: $url"
    curl -fsSL "$url" -o "$tmpdir/frp.tgz"
    tar -xzf "$tmpdir/frp.tgz" -C "$tmpdir"
    local dir
    dir="$(find "$tmpdir" -maxdepth 1 -type d -name "frp_*_linux_amd64" | head -n1)"
    if [[ -z "$dir" || ! -f "$dir/frpc" ]]; then
        echo "Errore: archivio FRP non valido" >&2
        exit 1
    fi
    install -m 0755 "$dir/frpc" /usr/local/bin/frpc
}

write_config() {
    local proxy_name="$1"
    local remote_port="$2"
    local token="$3"

    mkdir -p /etc/frp /var/log
    cat > /etc/frp/frpc.toml <<EOF
[common]
server_addr = "monitor.nethlab.it"
server_port = 7000
auth.method = "token"
auth.token  = "$token"
tls.enable = true
log.to = "/var/log/frpc.log"
log.level = "info"

[$proxy_name]
type        = "tcp"
local_ip    = "127.0.0.1"
local_port  = 6556
remote_port = $remote_port
EOF
}

write_systemd_unit() {
    cat > /etc/systemd/system/frpc.service <<'EOF'
[Unit]
Description=FRP Client Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=on-failure
RestartSec=5s
User=root

[Install]
WantedBy=multi-user.target
EOF
}

write_nethserver_template() {
    mkdir -p /etc/e-smith/templates-custom/etc/systemd/system/frpc.service
    cat > /etc/e-smith/templates-custom/etc/systemd/system/frpc.service/10base <<'EOF'
[Unit]
Description=FRP Client Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=on-failure
RestartSec=5s
User=root

[Install]
WantedBy=multi-user.target
EOF
}

main() {
    require_root

    echo "=== Installazione FRPC Client ==="
    local os
    os="$(detect_os)"
    echo "Rilevato sistema operativo: $os"

    read -r -p "URL pacchetto FRP [default: $FRP_URL_DEFAULT]: " FRP_URL
    FRP_URL=${FRP_URL:-$FRP_URL_DEFAULT}
    read -r -p "Nome host/proxy (es: rl94ns8): " PROXY_NAME
    read -r -p "Porta remota da usare: " REMOTE_PORT
    read -r -p "Token FRP (obbligatorio) [default: ${FRP_TOKEN_DEFAULT:-<none>}]: " FRP_TOKEN
    FRP_TOKEN=${FRP_TOKEN:-${FRP_TOKEN_DEFAULT:-}}

    if [[ -z "$PROXY_NAME" || -z "$REMOTE_PORT" || -z "$FRP_TOKEN" ]]; then
        echo "Errore: PROXY_NAME, REMOTE_PORT e FRP_TOKEN sono obbligatori" >&2
        exit 1
    fi

    if [[ "$os" == "rockylinux" || "$os" == "debian" || "$os" == "proxmox" ]]; then
        systemctl stop frpc 2>/dev/null || true
    fi

    install_frpc_binary "$FRP_URL"
    write_config "$PROXY_NAME" "$REMOTE_PORT" "$FRP_TOKEN"

    case "$os" in
        rockylinux|debian|proxmox)
            echo "--- Configurazione systemd ($os) ---"
            write_systemd_unit
            systemctl daemon-reload
            systemctl enable frpc
            systemctl restart frpc
            ;;
        nethserver)
            echo "--- Configurazione systemd via e-smith (NethServer) ---"
            command -v config >/dev/null 2>&1 && config set frpc service status enabled || true
            write_nethserver_template
            command -v signal-event >/dev/null 2>&1 && signal-event runlevel-adjust || true
            systemctl enable frpc || true
            systemctl restart frpc || true
            ;;
        *)
            echo "Sistema operativo non riconosciuto: configurazione manuale necessaria" >&2
            ;;
    esac

    echo "=== Installazione completata su $os ==="
    if command -v systemctl >/dev/null 2>&1; then
        systemctl status frpc -l --no-pager || true
    fi
}

main "$@"

: <<'__CORRUPTED_ORIGINAL_CONTENT__'
# ----------------------------
# 1. Rileva sistema operativo
# ----------------------------
if grep -qi "rocky" /etc/os-release; then
    OS_TYPE="rockylinux"
elif grep -qi "nethserver" /etc/os-release; then
    OS_TYPE="nethserver"
elif grep -qi "debian" /etc/os-release; then
    if dpkg -l | grep -q pve-manager; then
        OS_TYPE="proxmox"
    else
        OS_TYPE="debian"
    fi
else
    OS_TYPE="altro"
fi
echo "Rilevato sistema operativo: $OS_TYPE"
# ----------------------------
# 2. Parametri richiesti
# ----------------------------read -r -p "URL pacchetto FRP [default: $FRP_URL_DEFAULT]: " 
FRP_URLFRP_URL=${FRP_URL:-$FRP_URL_DEFAULT}read -r -p "Nome host (es: rl94ns8): " HOSTNAMEread -r -p "Porta remota da usare: " REMOTE_PORT
# ----------------------------
# 3. Download e installazione
# ----------------------------cd /usr/local/src || exit 1wget -q "$FRP_URL" -O frp.tar.gztar xzf frp.tar.gzcd frp_${FRP_VERSION}_linux_amd64 || exit 1systemctl stop frpc 2>/dev/null || truecp frpc /usr/local/bin/frpcchmod +x /usr/local/bin/frpc
# ----------------------------
# 4. Configurazione TOML
# ----------------------------mkdir -p /etc/frpcat > /etc/frp/frpc.toml <<EOF[common]server_addr = "monitor.nethlab.it"server_port = 7000auth.method = "token"auth.token  = "<REDACTED_FRP_TOKEN>"tls.enable = truelog.to = "/var/log/frpc.log"log.level = "info"[$HOSTNAME]type        = "tcp"local_ip    = "127.0.0.1"local_port  = 6556remote_port = $REMOTE_PORTEOF
# ----------------------------
# 5. Configura servizio
# ----------------------------if [ "$OS_TYPE" = "rockylinux" ] || [ "$OS_TYPE" = "debian" ] || [ "$OS_TYPE" = "proxmox" ]; then
    echo "--- Configurazione systemd ($OS_TYPE) ---"    cat > /etc/systemd/system/frpc.service <<EOF[Unit]Description=FRP Client Service ($OS_TYPE)After=network.target[Service]Type=simpleExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.tomlRestart=on-failureRestartSec=5sUser=root[Install]WantedBy=multi-user.targetEOF    systemctl daemon-reload    systemctl enable frpc    systemctl restart frpc
elif [ "$OS_TYPE" = "nethserver" ]; then
    echo "--- Configurazione systemd via e-smith (NethServer) ---"    config set frpc service status enabled    mkdir -p /etc/e-smith/templates-custom/etc/systemd/system/frpc.service    cat > /etc/e-smith/templates-custom/etc/systemd/system/frpc.service/10base <<EOF[Unit]Description=FRP Client Service (NethServer)After=network.target[Service]Type=simpleExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.tomlRestart=on-failureRestartSec=5sUser=root[Install]WantedBy=multi-user.targetEOF    signal-event runlevel-adjust    systemctl enable frpc    systemctl restart frpc
else    
echo "├ó┼í┬á├»┬©┬Å  Sistema operativo non riconosciuto: configurazione manuale necessaria"
fi # ----------------------------
# 6. Verifica finale
# ----------------------------
echo "=== Installazione completata su $OS_TYPE ==="systemctl status frpc -l --no-pager

__CORRUPTED_ORIGINAL_CONTENT__
