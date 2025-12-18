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

install_frps() {
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
	bin=$(find "$tmp_dir" -type f -name frps -print -quit)
	install -m 0755 "$bin" /usr/local/bin/frps
	rm -rf "$tmp_dir"
}

write_config() {
	mkdir -p /etc/frp
	cat >/etc/frp/frps.toml <<EOF
bindPort = ${FRPS_BIND_PORT:-7000}

[auth]
token = "${FRP_TOKEN:-}"
EOF
}

write_service() {
	cat >/etc/systemd/system/frps.service <<'EOF'
[Unit]
Description=FRP Server Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
}

main() {
	require_root
	load_env

	print_header "FRPS Setup"
	local version="${FRP_VERSION:-0.61.0}"

	install_frps "$version"
	write_config
	write_service
	systemctl daemon-reload
	systemctl enable --now frps || true
	print_success "FRPS setup completed"
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

install_frps() {
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
	bin=$(find "$tmp_dir" -type f -name frps -print -quit)
	install -m 0755 "$bin" /usr/local/bin/frps
	rm -rf "$tmp_dir"
}

write_config() {
	mkdir -p /etc/frp
	cat >/etc/frp/frps.toml <<EOF
bindPort = ${FRPS_BIND_PORT:-7000}

[auth]
token = "${FRP_TOKEN:-}"
EOF
}

write_service() {
	cat >/etc/systemd/system/frps.service <<'EOF'
[Unit]
Description=FRP Server Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
}

main() {
	require_root
	load_env

	print_header "FRPS Setup"
	local version="${FRP_VERSION:-0.61.0}"

	install_frps "$version"
	write_config
	write_service
	systemctl daemon-reload
	systemctl enable --now frps || true
	print_success "FRPS setup completed"
}

main "$@"
#!/usr/bin/env bash
set -euo pipefail

MODULE_NAME="FRPS Server Setup"

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

download_and_install_frps() {
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
	[[ -n "$extracted" && -f "${extracted}/frps" ]] || { log_error "frps not found in archive"; rm -rf "$tmpdir"; return 1; }

	install -m 0755 "${extracted}/frps" /usr/local/bin/frps
	rm -rf "$tmpdir"
	log_success "Installed frps to /usr/local/bin/frps"
}

write_frps_config() {
	local cfg_dir="/etc/frp"
	local log_dir="/var/log/frp"
	mkdir -p "$cfg_dir" "$log_dir"
	chmod 700 "$cfg_dir" || true

	local bind_port="${FRPS_BIND_PORT:-7000}"
	local dashboard_port="${FRPS_DASHBOARD_PORT:-7500}"
	local dashboard_user="${FRPS_DASHBOARD_USER:-admin}"
	local dashboard_pwd="${FRPS_DASHBOARD_PWD:-}"
	local token="${FRPS_TOKEN:-}"

	if [[ -z "$token" ]]; then
		token=$(input_password "FRPS token")
	fi
	if [[ -z "$dashboard_pwd" ]]; then
		dashboard_pwd=$(input_password "FRPS dashboard password")
	fi

	log_info "Writing /etc/frp/frps.toml"
	cat >"${cfg_dir}/frps.toml" <<EOF
bindPort = ${bind_port}

auth.method = "token"
auth.token = "${token}"

webServer.addr = "0.0.0.0"
webServer.port = ${dashboard_port}
webServer.user = "${dashboard_user}"
webServer.password = "${dashboard_pwd}"

log.to = "${log_dir}/frps.log"
log.level = "info"
EOF

	chmod 600 "${cfg_dir}/frps.toml"
}

install_systemd_service() {
	if ! command -v systemctl >/dev/null 2>&1; then
		log_warning "systemctl not available; skipping service setup"
		return 0
	fi

	local unit="/etc/systemd/system/frps.service"
	log_info "Creating systemd unit: frps.service"
	cat >"$unit" <<'EOF'
[Unit]
Description=FRP Server (frps)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload
	systemctl enable --now frps.service || true
	log_success "frps.service enabled"
}

main() {
	require_root
	log_module_start "$MODULE_NAME"

	apt_install ca-certificates wget tar
	download_and_install_frps
	write_frps_config
	install_systemd_service

	if command -v ufw >/dev/null 2>&1; then
		ufw allow "${FRPS_BIND_PORT:-7000}"/tcp >/dev/null 2>&1 || true
		ufw allow "${FRPS_DASHBOARD_PORT:-7500}"/tcp >/dev/null 2>&1 || true
	fi

	log_module_end "$MODULE_NAME" "success"
}

main "$@"
#!/bin/bash
/usr/bin/env bash
# 06-frps-setup.sh - FRPS Server installation and configuration
# Installs and configures FRP Server for accepting client connectionsset -euo pipefail
MODULE_NAME="FRPS Server Setup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(dirname "$SCRIPT_DIR")"
# Source utilitiessource "${INSTALLER_ROOT}/utils/colors.sh"source "${INSTALLER_ROOT}/utils/logger.sh"source "${INSTALLER_ROOT}/utils/validate.sh"source "${INSTALLER_ROOT}/utils/menu.sh"
# Load configuration
if [[ -f "${INSTALLER_ROOT}/.env" ]]; then  set -a  source "${INSTALLER_ROOT}/.env"  set +a
fi
# Module startlog_module_start "$MODULE_NAME"
# Installation paths
FRP_INSTALL_DIR="/usr/local/bin"
FRP_CONFIG_DIR="/etc/frp"
FRP_LOG_DIR="/var/log"
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Check existing installation
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#check_existing_installation() {  local frps_exists=false  local service_exists=false    if [[ -f "$FRP_INSTALL_DIR/frps" ]]; then
    frps_exists=true  fi    if systemctl list-units --full --all | grep -q "frps.service"; then
    service_exists=true  fi    if [[ "$frps_exists" == "true" ]] || [[ "$service_exists" == "true" ]]; then
    echo ""    
echo "${YELLOW}ÔÜá´©Å  FRPS installation detected${NC}"    
echo ""        if [[ "$frps_exists" == "true" ]]; then
    echo "Binary found: $FRP_INSTALL_DIR/frps"    fi        if [[ "$service_exists" == "true" ]]; then
    echo "Service found: frps.service"      if systemctl is-active --quiet frps.service; then
    echo "Status: ${GREEN}Active${NC}"
else        
echo "Status: ${RED}Inactive${NC}"      fi    fi        if [[ -f "$FRP_CONFIG_DIR/frps.toml" ]]; then
    echo "Config found: $FRP_CONFIG_DIR/frps.toml"    fi
echo ""    read -r -p "Reinstall FRPS? This will overwrite existing installation (y/n): " reinstall        if [[ "$reinstall" != "y" ]]; then      log_info "Installation cancelled by user"
    exit 0    fi        
# Stop existing service    if systemctl is-active --quiet frps.service; then      log_info "Stopping existing FRPS service..."      systemctl stop frps.service    fi        log_info "Proceeding with reinstallation..."  fi}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
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
# Download FRPS
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#download_frps() {  log_info "Downloading FRPS..."    local version="${FRPC_VERSION:-0.52.3}"local archlocal archarch=$(detect_architecture)  local download_url="https://github.com/fatedier/frp/releases/download/v${version}/frp_${version}_linux_${arch}.tar.gz"  local dest="/tmp/frp.tar.gz"    log_debug "Download URL: $download_url"    
# Download from GitHub  if ! log_command "wget -O '$dest' '$download_url'"; then    log_error "Failed to download FRP"    return 1  fi    
# Extract  log_command "tar -xzf '$dest' -C /tmp/"    
# Find and copy FRPS binarylocal frps_binlocal frps_binfrps_bin=$(find /tmp -name "frps" -type f | head -1)  if [[ -n "$frps_bin" ]]; then    cp "$frps_bin" "$FRP_INSTALL_DIR/frps"    chmod +x "$FRP_INSTALL_DIR/frps"    log_success "FRPS binary installed"
else    log_error "FRPS binary not found in archive"    return 1  fi    
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
# Configure FRPS
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_frps() {  log_info "Configuring FRPS server..."    
# Get configuration from .env or ask interactively  local bind_port="${FRPC_SERVER_PORT:-}"  local token="${FRPC_TOKEN:-}"  local dashboard_port="7500"  local dashboard_user="${FRPC_ADMIN_USER:-}"  local dashboard_pwd="${FRPC_ADMIN_PWD:-}"  local enable_tls="n"  local cert_file=""  local key_file=""    
# Ask for missing configuration  if [[ -z "$bind_port" ]] || [[ -z "$token" ]] || [[ -z "$dashboard_user" ]] || [[ -z "$dashboard_pwd" ]]; then
    echo ""    
echo "${YELLOW}FRPS Server Configuration${NC}"    
echo ""        if [[ -z "$bind_port" ]]; then      read -r -p "Bind port [7000]: " bind_port      bind_port="${bind_port:-7000}"    fi        if [[ -z "$token" ]]; then      read -r -p "Authentication token: " token    fi
read -r -p "Dashboard port [7500]: " dashboard_port    dashboard_port="${dashboard_port:-7500}"        if [[ -z "$dashboard_user" ]]; then      read -r -p "Dashboard username [admin]: " dashboard_user      dashboard_user="${dashboard_user:-admin}"    fi        if [[ -z "$dashboard_pwd" ]]; then      read -r -p "Dashboard password: " dashboard_pwd    fi
echo ""    read -r -p "Enable TLS? (y/n) [n]: " enable_tls    enable_tls="${enable_tls:-n}"        if [[ "$enable_tls" == "y" ]]; then      read -r -p "TLS certificate file path: " cert_file      read -r -p "TLS key file path: " key_file    fi  fi    
# Create config directory  mkdir -p "$FRP_CONFIG_DIR"    local config_file="$FRP_CONFIG_DIR/frps.toml"    
# Create FRPS configuration  cat > "$config_file" <<EOF[common]bindPort = $bind_port
# Authenticationauth.method = "token"auth.token  = "$token"EOF  if [[ "$enable_tls" == "y" ]] && [[ -n "$cert_file" ]] && [[ -n "$key_file" ]]; then    cat >> "$config_file" <<EOF
# TLS configurationtls.enable   = truetls.certFile = "$cert_file"tls.keyFile  = "$key_file"EOF  fi  cat >> "$config_file" <<EOF
# Dashboarddashboard_port = $dashboard_portdashboard_user = "$dashboard_user"dashboard_pwd  = "$dashboard_pwd"
# Logginglog.to = "$FRP_LOG_DIR/frps.log"log.level = "info"EOF    chmod 600 "$config_file"    log_success "FRPS configured: $config_file"    
# Store config for later display  
FRPS_BIND_PORT="$bind_port"  
FRPS_DASHBOARD_PORT="$dashboard_port"  
FRPS_TOKEN="$token"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
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
#create_systemd_service() {  log_info "Creating systemd service..."    local service_file="/etc/systemd/system/frps.service"    cat > "$service_file" <<EOF[Unit]Description=FRP ServerAfter=network.targetWants=network-online.target[Service]Type=simpleUser=rootExecStart=$FRP_INSTALL_DIR/frps -c $FRP_CONFIG_DIR/frps.tomlRestart=on-failureRestartSec=10StandardOutput=journalStandardError=journal
# Security settingsNoNewPrivileges=truePrivateTmp=trueProtectSystem=strictProtectHome=trueReadWritePaths=$FRP_LOG_DIR[Install]WantedBy=multi-user.targetEOF    
# Reload and enable service  log_command "systemctl daemon-reload"  log_command "systemctl enable frps.service"  log_command "systemctl start frps.service"    
# Wait and check status  sleep 2    if systemctl is-active --quiet frps.service; then    log_success "FRPS service started successfully"
else    log_error "FRPS service failed to start"    log_info "Check logs: journalctl -u frps.service -n 50"    return 1  fi}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
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
#configure_firewall() {  log_info "Configuring firewall..."    
# Open FRP server port  log_command "ufw allow ${FRPS_BIND_PORT}/tcp comment 'FRP Server'"    
# Open dashboard port  log_command "ufw allow ${FRPS_DASHBOARD_PORT}/tcp comment 'FRP Dashboard'"    log_success "Firewall configured"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
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
#display_summary() {local server_iplocal server_ipserver_ip=$(hostname -I | awk '{print $1}')    
echo ""  print_separator "="  
echo ""    display_box "FRPS Server Installation Complete!" \    "" \    "Binary: $FRP_INSTALL_DIR/frps" \    "Config: $FRP_CONFIG_DIR/frps.toml" \    "Logs: $FRP_LOG_DIR/frps.log" \    "" \    "Server listening on port: $FRPS_BIND_PORT" \    "Dashboard: http://${server_ip}:$FRPS_DASHBOARD_PORT" \    "Token: $FRPS_TOKEN" \    "" \    "Commands:" \    "  systemctl status frps" \    "  journalctl -u frps -f" \    "  tail -f $FRP_LOG_DIR/frps.log" \    "" \    "Service: Active and enabled"    
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
#main() {  log_info "Starting FRPS server setup..."    
# Check existing installation  check_existing_installation    
# Download FRPS  download_frps    
# Configure  configure_frps    
# Create systemd service  create_systemd_service    
# Configure firewall  configure_firewall    log_module_end "$MODULE_NAME" "success"    display_summary}
# Run main functionmain "$@"

__CORRUPTED_TAIL__
