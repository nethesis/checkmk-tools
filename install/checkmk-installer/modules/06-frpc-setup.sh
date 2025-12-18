#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${INSTALLER_ROOT}/utils/colors.sh"
source "${INSTALLER_ROOT}/utils/logger.sh"

load_env() {
	if [[ -f "${INSTALLER_ROOT}/.env" ]]; then
		set -a
		source "${INSTALLER_ROOT}/.env"
		set +a
	fi
}

require_root() {
	if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
		print_error "Module must run as root"
		exit 1
	fi
}

detect_arch() {
	case "$(uname -m)" in
		x86_64) echo "amd64" ;;
		aarch64|arm64) echo "arm64" ;;
		*) echo "amd64" ;;
	esac
}

install_frpc() {
	local version="$1"
	local arch
	arch=$(detect_arch)
	local url="https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_linux_${arch}.tar.gz"
	local tmp_dir
	tmp_dir=$(mktemp -d)

	print_info "Downloading FRP: $url"
	curl -fsSL "$url" -o "$tmp_dir/frp.tgz"
	tar -xzf "$tmp_dir/frp.tgz" -C "$tmp_dir"

	local bin
	bin=$(find "$tmp_dir" -type f -name frpc -print -quit)
	install -m 0755 "$bin" /usr/local/bin/frpc
	rm -rf "$tmp_dir"
}

write_config() {
	mkdir -p /etc/frp
	cat >/etc/frp/frpc.toml <<EOF
serverAddr = "${FRPC_SERVER_ADDR:-}"
serverPort = ${FRPC_SERVER_PORT:-7000}

[auth]
token = "${FRP_TOKEN:-}"
EOF
}

write_service() {
	cat >/etc/systemd/system/frpc.service <<'EOF'
[Unit]
Description=FRP Client Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
}

main() {
	require_root
	load_env

	print_header "FRPC Setup"
	local version="${FRP_VERSION:-0.61.0}"

	if [[ -z "${FRPC_SERVER_ADDR:-}" ]]; then
		print_warning "FRPC_SERVER_ADDR is empty; frpc will not connect until configured"
	fi

	install_frpc "$version"
	write_config
	write_service
	systemctl daemon-reload
	systemctl enable --now frpc || true
	print_success "FRPC setup completed"
}

main "$@"
: <<'__CORRUPTED_TAIL__'
#!/usr/bin/env bash
set -euo pipefail

INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${INSTALLER_ROOT}/utils/colors.sh"
source "${INSTALLER_ROOT}/utils/logger.sh"

load_env() {
	if [[ -f "${INSTALLER_ROOT}/.env" ]]; then
		set -a
		source "${INSTALLER_ROOT}/.env"
		set +a
	fi
}

require_root() {
	if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
		print_error "Module must run as root"
		exit 1
	fi
}

detect_arch() {
	case "$(uname -m)" in
		x86_64) echo "amd64" ;;
		aarch64|arm64) echo "arm64" ;;
		*) echo "amd64" ;;
	esac
}

install_frpc() {
	local version="$1"
	local arch
	arch=$(detect_arch)
	local url="https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_linux_${arch}.tar.gz"
	local tmp_dir
	tmp_dir=$(mktemp -d)

	print_info "Downloading FRP: $url"
	curl -fsSL "$url" -o "$tmp_dir/frp.tgz"
	tar -xzf "$tmp_dir/frp.tgz" -C "$tmp_dir"

	local bin
	bin=$(find "$tmp_dir" -type f -name frpc -print -quit)
	install -m 0755 "$bin" /usr/local/bin/frpc
	rm -rf "$tmp_dir"
}

write_config() {
	mkdir -p /etc/frp
	cat >/etc/frp/frpc.toml <<EOF
serverAddr = "${FRPC_SERVER_ADDR:-}"
serverPort = ${FRPC_SERVER_PORT:-7000}

[auth]
token = "${FRP_TOKEN:-}"
EOF
}

write_service() {
	cat >/etc/systemd/system/frpc.service <<'EOF'
[Unit]
Description=FRP Client Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
}

main() {
	require_root
	load_env

	print_header "FRPC Setup"
	local version="${FRP_VERSION:-0.61.0}"

	if [[ -z "${FRPC_SERVER_ADDR:-}" ]]; then
		print_warning "FRPC_SERVER_ADDR is empty; frpc will not connect until configured"
	fi

	install_frpc "$version"
	write_config
	write_service
	systemctl daemon-reload
	systemctl enable --now frpc || true
	print_success "FRPC setup completed"
}

main "$@"
#!/usr/bin/env bash
set -euo pipefail

MODULE_NAME="FRPC Client Setup"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../utils/colors.sh
source "${INSTALLER_ROOT}/utils/colors.sh"
# shellcheck source=../utils/logger.sh
source "${INSTALLER_ROOT}/utils/logger.sh"
# shellcheck source=../utils/menu.sh
source "${INSTALLER_ROOT}/utils/menu.sh"

if [[ -f "${INSTALLER_ROOT}/.env" ]]; then
	set -a
	# shellcheck disable=SC1091
	source "${INSTALLER_ROOT}/.env"
	set +a
fi

require_root() {
	if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
		log_error "This module must be run as root"
		exit 1
	fi
}

apt_install() {
	local packages=("$@")
	DEBIAN_FRONTEND=noninteractive apt-get update -y
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
}

frp_arch() {
	local arch
	arch=$(uname -m)
	case "$arch" in
		x86_64|amd64) echo "amd64" ;;
		aarch64|arm64) echo "arm64" ;;
		armv7l|armv7) echo "arm" ;;
		*) echo "amd64" ;;
	esac
}

download_and_install_frpc() {
	local version="${FRPC_VERSION:-0.52.3}"
	local arch
	arch=$(frp_arch)
	local url="https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_linux_${arch}.tar.gz"
	local tmpdir
	tmpdir=$(mktemp -d)

	log_info "Downloading FRP v${version} (${arch})"
	log_command "wget -O '${tmpdir}/frp.tgz' '${url}'"
	log_command "tar -xzf '${tmpdir}/frp.tgz' -C '${tmpdir}'"

	local extracted
	extracted=$(find "$tmpdir" -maxdepth 1 -type d -name "frp_*" | head -n 1 || true)
	[[ -n "$extracted" && -f "${extracted}/frpc" ]] || { log_error "frpc not found in archive"; rm -rf "$tmpdir"; return 1; }

	install -m 0755 "${extracted}/frpc" /usr/local/bin/frpc
	rm -rf "$tmpdir"
	log_success "Installed frpc to /usr/local/bin/frpc"
}

write_frpc_config() {
	local cfg_dir="/etc/frp"
	local log_dir="/var/log/frp"
	mkdir -p "$cfg_dir" "$log_dir"
	chmod 700 "$cfg_dir" || true

	local server_addr="${FRPC_SERVER_ADDR:-}"
	local server_port="${FRPC_SERVER_PORT:-7000}"
	local token="${FRPC_TOKEN:-}"
	local remote_port="${FRPC_REMOTE_PORT:-}"
	local ssh_remote_port="${FRPC_SSH_REMOTE_PORT:-}"

	if [[ -z "$server_addr" ]]; then
		server_addr=$(input_text "FRPC server address" "")
	fi
	if [[ -z "$token" ]]; then
		token=$(input_password "FRPC token")
	fi
	if [[ -z "$remote_port" ]]; then
		remote_port=$(input_text "FRPC remote port for CheckMK agent (6556)" "")
	fi

	log_info "Writing /etc/frp/frpc.toml"
	cat >"${cfg_dir}/frpc.toml" <<EOF
serverAddr = "${server_addr}"
serverPort = ${server_port}

auth.method = "token"
auth.token = "${token}"

log.to = "${log_dir}/frpc.log"
log.level = "info"

[[proxies]]
name = "checkmk_agent"
type = "tcp"
localIP = "127.0.0.1"
localPort = 6556
remotePort = ${remote_port}
EOF

	if [[ -n "$ssh_remote_port" ]]; then
		cat >>"${cfg_dir}/frpc.toml" <<EOF

[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = ${ssh_remote_port}
EOF
	fi

	chmod 600 "${cfg_dir}/frpc.toml"
}

install_systemd_service() {
	if ! command -v systemctl >/dev/null 2>&1; then
		log_warning "systemctl not available; skipping service setup"
		return 0
	fi

	local unit="/etc/systemd/system/frpc.service"
	log_info "Creating systemd unit: frpc.service"
	cat >"$unit" <<'EOF'
[Unit]
Description=FRP Client (frpc)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload
	systemctl enable --now frpc.service || true
	log_success "frpc.service enabled"
}

main() {
	require_root
	log_module_start "$MODULE_NAME"

	apt_install ca-certificates wget tar
	download_and_install_frpc
	write_frpc_config
	install_systemd_service

	if command -v ufw >/dev/null 2>&1; then
		ufw allow 6556/tcp >/dev/null 2>&1 || true
	fi

	log_module_end "$MODULE_NAME" "success"
}

main "$@"
#!/bin/bash
/usr/bin/env bash
# 06-frpc-setup.sh - FRPC Client installation and configuration
# Installs and configures FRP client for reverse proxyset -euo pipefail
MODULE_NAME="FRPC Client Setup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(dirname "$SCRIPT_DIR")"
# Source utilitiessource "${INSTALLER_ROOT}/utils/colors.sh"source "${INSTALLER_ROOT}/utils/logger.sh"source "${INSTALLER_ROOT}/utils/validate.sh"source "${INSTALLER_ROOT}/utils/menu.sh"
# Load configuration
if [[ -f "${INSTALLER_ROOT}/.env" ]]; then  set -a  source "${INSTALLER_ROOT}/.env"  set +a
fi
# Module startlog_module_start "$MODULE_NAME"
# Installation paths
FRPC_INSTALL_DIR="/usr/local/bin"
FRPC_CONFIG_DIR="/etc/frp"
FRPC_LOG_DIR="/var/log"
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Detect system architecture
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#detect_architecture() {local archlocal archarch=$(uname -m)    case "$arch" in    x86_64)      
echo "amd64"      ;;    aarch64|arm64)      
echo "arm64"      ;;    armv7l)      
echo "arm"      ;;    *)      log_error "Unsupported architecture: $arch"      return 1      ;;  esac}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Download FRPC
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#download_frpc() {  log_info "Downloading FRPC..."    local version="${FRPC_VERSION:-0.52.3}"local archlocal archarch=$(detect_architecture)  local download_url="https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_linux_${arch}.tar.gz"  local dest="/tmp/frpc.tar.gz"    log_debug "Download URL: $download_url"    
# Try local copy first  local local_frpc="${INSTALLER_ROOT}/scripts/Install/Agent-FRPC/frpc"  if [[ -f "$local_frpc" ]]; then    log_info "Using local FRPC binary"    cp "$local_frpc" "$FRPC_INSTALL_DIR/frpc"    chmod +x "$FRPC_INSTALL_DIR/frpc"    log_success "FRPC binary installed from local copy"    return 0  fi    
# Download from GitHub  if ! log_command "wget -O '$dest' '$download_url'"; then    log_error "Failed to download FRPC"    return 1  fi    
# Extract  log_command "tar -xzf '$dest' -C /tmp/"    
# Find and copy binarylocal frpc_binlocal frpc_binfrpc_bin=$(find /tmp -name "frpc" -type f | grep -v ".tar.gz" | head -1)  if [[ -n "$frpc_bin" ]]; then    cp "$frpc_bin" "$FRPC_INSTALL_DIR/frpc"    chmod +x "$FRPC_INSTALL_DIR/frpc"    log_success "FRPC binary installed"
else    log_error "FRPC binary not found in archive"    return 1  fi    
# Cleanup  rm -rf /tmp/frp_* "$dest"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Configure FRPC
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_frpc() {  log_info "Configuring FRPC..."    
# Check required configuration  if [[ -z "${FRPC_SERVER_ADDR:-}" ]]; then    log_error "FRPC_SERVER_ADDR not configured"    return 1  fi    
# Create config directory  mkdir -p "$FRPC_CONFIG_DIR"    local config_file="$FRPC_CONFIG_DIR/frpc.ini"local hostnamelocal hostnamehostname=$(hostname)    
# Use template if available  local template="${INSTALLER_ROOT}/templates/frpc.ini.template"    if [[ -f "$template" ]]; then    log_debug "Using configuration template"    cp "$template" "$config_file"        
# Replace placeholders    sed -i "s|{{FRPC_SERVER_ADDR}}|${FRPC_SERVER_ADDR}|g" "$config_file"    sed -i "s|{{FRPC_SERVER_PORT}}|${FRPC_SERVER_PORT:-7000}|g" "$config_file"    sed -i "s|{{FRPC_TOKEN}}|${FRPC_TOKEN:-}|g" "$config_file"    sed -i "s|{{HOSTNAME}}|${hostname}|g" "$config_file"    sed -i "s|{{FRPC_REMOTE_PORT}}|${FRPC_REMOTE_PORT:-}|g" "$config_file"    sed -i "s|{{FRPC_SSH_REMOTE_PORT}}|${FRPC_SSH_REMOTE_PORT:-}|g" "$config_file"    sed -i "s|{{FRPC_ADMIN_USER}}|${FRPC_ADMIN_USER:-admin}|g" "$config_file"    sed -i "s|{{FRPC_ADMIN_PWD}}|${FRPC_ADMIN_PWD:-admin}|g" "$config_file"    sed -i "s|{{FRPC_DOMAIN}}|${FRPC_DOMAIN:-example.com}|g" "$config_file"
else    
# Create basic configuration    log_warning "Template not found, creating basic configuration"        cat > "$config_file" <<EOF[common]server_addr = ${FRPC_SERVER_ADDR}server_port = ${FRPC_SERVER_PORT:-7000}token = ${FRPC_TOKEN:-}log_file = ${FRPC_LOG_DIR}/frpc.loglog_level = infolog_max_days = 7
# Admin interfaceadmin_addr = 127.0.0.1admin_port = 7400admin_user = ${FRPC_ADMIN_USER:-admin}admin_pwd = ${FRPC_ADMIN_PWD:-admin}
# CheckMK Agent Proxy[checkmk-${hostname}]type = tcplocal_ip = 127.0.0.1local_port = 6556remote_port = ${FRPC_REMOTE_PORT:-}use_encryption = trueuse_compression = trueEOF  fi    chmod 600 "$config_file"    log_success "FRPC configured: $config_file"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Create systemd service
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#create_systemd_service() {  log_info "Creating systemd service..."    local service_file="/etc/systemd/system/frpc.service"  local template="${INSTALLER_ROOT}/templates/systemd/frpc.service"    if [[ -f "$template" ]]; then    cp "$template" "$service_file"
else    cat > "$service_file" <<EOF[Unit]Description=FRPC Client ServiceAfter=network.targetWants=network-online.target[Service]Type=simpleUser=rootExecStart=$FRPC_INSTALL_DIR/frpc -c $FRPC_CONFIG_DIR/frpc.iniRestart=on-failureRestartSec=10StandardOutput=journalStandardError=journal
# Security settingsNoNewPrivileges=truePrivateTmp=trueProtectSystem=strictProtectHome=trueReadWritePaths=${FRPC_LOG_DIR}[Install]WantedBy=multi-user.targetEOF  fi    
# Reload and enable service  log_command "systemctl daemon-reload"  log_command "systemctl enable frpc.service"    log_success "Systemd service created"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Test FRPC connection
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#test_frpc_connection() {  log_info "Testing FRPC connection..."    
# Start service temporarily  systemctl start frpc.service    
# Wait a moment  sleep 3    
# Check if running  if systemctl is-active --quiet frpc.service; then    log_success "FRPC service is running"        
# Check logs for connection    if journalctl -u frpc.service -n 20 | grep -q "login to server success"; then      log_success "FRPC connected to server successfully"      return 0    else      log_warning "FRPC started but connection status unknown"      log_info "Check logs: journalctl -u frpc.service -f"    fi
else    log_error "FRPC service failed to start"    log_info "Check logs: journalctl -u frpc.service -n 50"    return 1  fi}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Configure firewall
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_frpc_firewall() {  log_info "Configuring firewall for FRPC..."    
# Allow outgoing connections to FRPC server  local server_ip="${FRPC_SERVER_ADDR}"  local server_port="${FRPC_SERVER_PORT:-7000}"    if [[ -n "$server_ip" ]]; then    log_command "ufw allow out to $server_ip port $server_port proto tcp comment 'FRPC to server'"  fi    log_success "Firewall configured"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Create management scripts
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#create_management_scripts() {  log_info "Creating management scripts..."    
# FRPC status script  cat > /usr/local/bin/frpc-status <<'EOF'
#!/bin/bash
# FRPC Status Check
echo "=== FRPC Service Status ==="systemctl status frpc.service --no-pager
echo ""
echo "=== FRPC Connections ==="if command -v ss &>/dev/null; then  ss -tnp | grep frpc || 
echo "No active connections"
else  netstat -tnp | grep frpc || 
echo "No active connections"
fi
echo ""
echo "=== Recent Logs ==="journalctl -u frpc.service -n 10 --no-pagerEOF    chmod +x /usr/local/bin/frpc-status    
# FRPC restart script  cat > /usr/local/bin/frpc-restart <<'EOF'
#!/bin/bash
# FRPC Service Restart
echo "Restarting FRPC service..."systemctl restart frpc.servicesleep 2
if systemctl is-active --quiet frpc.service; then
    echo "Ô£à FRPC service restarted successfully"
else  
echo "ÔØî FRPC service failed to restart"  
echo "Check logs: journalctl -u frpc.service -n 20"
    exit 1fiEOF    chmod +x /usr/local/bin/frpc-restart    log_success "Management scripts created"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Create monitoring check
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#create_monitoring_check() {  log_info "Creating monitoring check..."    local check_script="/usr/lib/check_mk_agent/local/frpc_status"    mkdir -p "$(dirname "$check_script")"    cat > "$check_script" <<'EOF'
#!/bin/bash
# CheckMK Local Check: FRPC Status
if systemctl is-active --quiet frpc.service; then
  if journalctl -u frpc.service -n 5 | grep -q "login to server success\|start proxy success"; then
    echo "0 FRPC_Status - FRPC service is running and connected"
else    
echo "1 FRPC_Status - FRPC service is running but connection unclear"  fi
else  
echo "2 FRPC_Status - FRPC service is not running"fiEOF    chmod +x "$check_script"    log_success "Monitoring check created"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Display installation summary
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#display_installation_summary() {local hostnamelocal hostnamehostname=$(hostname)    print_separator "="  
echo ""  display_box "FRPC Installation Complete!" \    "" \    "Binary: $FRPC_INSTALL_DIR/frpc" \    "Config: $FRPC_CONFIG_DIR/frpc.ini" \    "Logs: ${FRPC_LOG_DIR}/frpc.log" \    "" \    "Server: ${FRPC_SERVER_ADDR}:${FRPC_SERVER_PORT:-7000}" \    "Hostname: $hostname" \    "" \    "Commands:" \    "  systemctl status frpc" \    "  frpc-status" \    "  frpc-restart" \    "  journalctl -u frpc -f" \    "" \    "Service: Active and enabled"  
echo ""  print_separator "="}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Main execution
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#main() {  log_info "Starting FRPC client setup..."    
# Check configuration  if [[ -z "${FRPC_SERVER_ADDR:-}" ]]; then    log_error "FRPC_SERVER_ADDR not configured"    log_info "Please configure FRPC settings and run this module again"
    exit 1  fi    
# Install FRPC  download_frpc  configure_frpc  create_systemd_service  configure_frpc_firewall    
# Create additional components  create_management_scripts  create_monitoring_check    
# Test connection  test_frpc_connection || log_warning "Connection test inconclusive"    log_module_end "$MODULE_NAME" "success"    display_installation_summary}
# Run main functionmain "$@"

__CORRUPTED_TAIL__
