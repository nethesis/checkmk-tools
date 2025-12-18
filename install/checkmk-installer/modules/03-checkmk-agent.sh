#!/usr/bin/env bash
set -euo pipefail

INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "${INSTALLER_ROOT}/utils/colors.sh"
# shellcheck disable=SC1091
source "${INSTALLER_ROOT}/utils/logger.sh"
# shellcheck disable=SC1091
source "${INSTALLER_ROOT}/utils/menu.sh"
# shellcheck disable=SC1091
source "${INSTALLER_ROOT}/utils/validate.sh"

load_env() {
	if [[ -f "${INSTALLER_ROOT}/.env" ]]; then
		set -a
		# shellcheck disable=SC1091
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

main() {
	require_root
	load_env

	print_header "CheckMK Agent"

	local agent_url="${CHECKMK_AGENT_URL:-}"
	local server="${CHECKMK_SERVER:-}"
	local site="${CHECKMK_SITE_NAME:-cmk}"

	if [[ -z "$agent_url" && -n "$server" ]]; then
		agent_url="http://${server}/${site}/check_mk/agents/check-mk-agent_0.all.deb"
	fi

	if [[ -z "$agent_url" ]]; then
		print_error "CHECKMK_AGENT_URL not set and CHECKMK_SERVER not provided"
		print_info "Set CHECKMK_AGENT_URL (direct .deb URL) in .env"
		exit 1
	fi

	local deb_path="/tmp/checkmk-agent.deb"
	print_info "Downloading agent: $agent_url"
	if command -v curl >/dev/null 2>&1; then
		local -a curl_opts=(--fail --location --show-error --connect-timeout 10 --max-time 600 --retry 5 --retry-connrefused --retry-delay 2 --speed-time 30 --speed-limit 1024)
		if [[ -t 1 ]]; then
			curl "${curl_opts[@]}" --progress-bar -o "$deb_path" "$agent_url"
		else
			curl "${curl_opts[@]}" --silent -o "$deb_path" "$agent_url"
		fi
	elif command -v wget >/dev/null 2>&1; then
		wget --tries=5 --timeout=30 --progress=dot:giga -O "$deb_path" "$agent_url"
	else
		print_error "Neither curl nor wget found"
		exit 1
	fi
	[[ -s "$deb_path" ]] || { print_error "Downloaded file is empty: $deb_path"; exit 1; }

	print_info "Installing agent"
	dpkg -i "$deb_path" || true
	apt-get -f install -y

	systemctl enable --now check-mk-agent.socket 2>/dev/null || true
	if command -v ufw >/dev/null 2>&1; then
		ufw allow 6556/tcp || true
	fi

	print_success "CheckMK agent module completed"
}

main "$@"

exit 0
# shellcheck disable=SC2317
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

main() {
	require_root
	load_env

	print_header "CheckMK Agent"

	local agent_url="${CHECKMK_AGENT_URL:-}"
	local server="${CHECKMK_SERVER:-}"
	local site="${CHECKMK_SITE_NAME:-cmk}"

	if [[ -z "$agent_url" && -n "$server" ]]; then
		agent_url="http://${server}/${site}/check_mk/agents/check-mk-agent_0.all.deb"
	fi

	if [[ -z "$agent_url" ]]; then
		print_error "CHECKMK_AGENT_URL not set and CHECKMK_SERVER not provided"
		print_info "Set CHECKMK_AGENT_URL (direct .deb URL) in .env"
		exit 1
	fi

	local deb_path="/tmp/checkmk-agent.deb"
	print_info "Downloading agent: $agent_url"
	curl -fsSL "$agent_url" -o "$deb_path"

	print_info "Installing agent"
	dpkg -i "$deb_path" || true
	apt-get -f install -y

	systemctl enable --now check-mk-agent.socket 2>/dev/null || true
	if command -v ufw >/dev/null 2>&1; then
		ufw allow 6556/tcp || true
	fi

	print_success "CheckMK agent module completed"
}

main "$@"
#!/usr/bin/env bash
set -euo pipefail

MODULE_NAME="CheckMK Agent Installation"

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

discover_agent_deb_url() {
	local server="$1" port="$2" site="$3"
	local base_http="http://${server}:${port}/${site}/check_mk/agents/"
	local base_https="https://${server}:${port}/${site}/check_mk/agents/"

	local html agent_file
	if html=$(curl -fsSL "$base_http" 2>/dev/null); then
		agent_file=$(echo "$html" | grep -oE 'check-mk-agent_[^" ]+_all\.deb' | head -n 1 || true)
		[[ -n "$agent_file" ]] && { echo "${base_http}${agent_file}"; return 0; }
	fi

	if html=$(curl -kfsSL "$base_https" 2>/dev/null); then
		agent_file=$(echo "$html" | grep -oE 'check-mk-agent_[^" ]+_all\.deb' | head -n 1 || true)
		[[ -n "$agent_file" ]] && { echo "${base_https}${agent_file}"; return 0; }
	fi

	# Fallback: common filename used by many CheckMK installs
	echo "${base_http}check-mk-agent_2.4.0-1_all.deb"
}

download_and_install_agent() {
	local url="$1"
	local dest="/tmp/check-mk-agent.deb"

	log_info "Downloading CheckMK agent: $url"
	log_command "rm -f '$dest'"
	set +e
	wget --no-check-certificate -O "$dest" "$url"
	local rc=$?
	set -e
	if [[ $rc -ne 0 ]] || [[ ! -s "$dest" ]]; then
		log_error "Failed to download agent from $url"
		return 1
	fi

	log_info "Installing CheckMK agent package"
	set +e
	dpkg -i "$dest"
	local dpkg_rc=$?
	set -e
	if [[ $dpkg_rc -ne 0 ]]; then
		log_warning "dpkg reported errors; attempting to fix dependencies"
		DEBIAN_FRONTEND=noninteractive apt-get -f install -y
		dpkg -i "$dest" || true
	fi
}

enable_agent_service() {
	local use_socket="${USE_SYSTEMD_SOCKET:-yes}"
	if [[ "$use_socket" == "yes" ]] && systemctl list-unit-files 2>/dev/null | grep -qE '^check-mk-agent\.socket'; then
		log_info "Enabling CheckMK agent socket"
		systemctl enable --now check-mk-agent.socket || true
	elif systemctl list-unit-files 2>/dev/null | grep -qE '^check-mk-agent\.service'; then
		log_info "Enabling CheckMK agent service"
		systemctl enable --now check-mk-agent.service || true
	else
		log_warning "No check-mk-agent systemd unit found; agent may be started via xinetd or manually"
	fi

	if command -v ufw >/dev/null 2>&1; then
		ufw allow 6556/tcp >/dev/null 2>&1 || true
	fi
}

main() {
	require_root
	log_module_start "$MODULE_NAME"

	apt_install ca-certificates curl wget

	local server="${CHECKMK_SERVER:-}"
	local site="${CHECKMK_SITE_NAME:-monitoring}"
	local port="${CHECKMK_HTTP_PORT:-5000}"

	if [[ -z "$server" ]]; then
		log_info "CHECKMK_SERVER is empty; skipping agent download (this may be the server)"
		enable_agent_service
		log_module_end "$MODULE_NAME" "success"
		return 0
	fi

	local agent_url
	agent_url=$(discover_agent_deb_url "$server" "$port" "$site")
	download_and_install_agent "$agent_url"
	enable_agent_service

	log_module_end "$MODULE_NAME" "success"
}

main "$@"
#!/bin/bash
/usr/bin/env bash
# 03-checkmk-agent.sh - CheckMK Agent installation module
# Installs CheckMK monitoring agent on client systemsset -euo pipefail
MODULE_NAME="CheckMK Agent Installation"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(dirname "$SCRIPT_DIR")"
# Source utilitiessource "${INSTALLER_ROOT}/utils/colors.sh"source "${INSTALLER_ROOT}/utils/logger.sh"source "${INSTALLER_ROOT}/utils/validate.sh"source "${INSTALLER_ROOT}/utils/menu.sh"
# Load configuration
if [[ -f "${INSTALLER_ROOT}/.env" ]]; then  set -a  source "${INSTALLER_ROOT}/.env"  set +a
else  log_error "Configuration file not found. Run config-wizard.sh first."
    exit 1
fi # Module startlog_module_start "$MODULE_NAME"
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Download CheckMK agent
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#download_checkmk_agent() {  local server="${CHECKMK_SERVER:-}"  local site="${CHECKMK_SITE_NAME:-monitoring}"  local dest="/tmp/check-mk-agent.deb"    if [[ -z "$server" ]]; then    log_error "CHECKMK_SERVER not configured"    return 1  fi    log_info "Downloading CheckMK agent from server..."    local agent_url="http://${server}:${CHECKMK_HTTP_PORT:-5000}/${site}/check_mk/agents/check-mk-agent_2.4.0-1_all.deb"    if ! log_command "wget --no-check-certificate -O '$dest' '$agent_url'"; then    log_warning "Failed to download from server, trying alternative method..."        
# Try to use local copy if available    local local_agent="${INSTALLER_ROOT}/scripts/Install/Agent-FRPC/check-mk-agent.deb"    if [[ -f "$local_agent" ]]; then      log_info "Using local agent package"      cp "$local_agent" "$dest"
else      log_error "No agent package available"      return 1    fi  fi    log_success "Agent package downloaded"  
echo "$dest"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Install CheckMK agent
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#install_checkmk_agent() {  local package="$1"    log_info "Installing CheckMK agent..."    
# Install dependencies  log_command "apt-get update"  log_command "
DEBIAN_FRONTEND=noninteractive apt-get install -y xinetd"    
# Install agent package  if ! log_command "dpkg -i '$package'"; then    log_warning "dpkg reported errors, trying to fix..."    log_command "apt-get install -f -y"  fi    log_success "CheckMK agent installed"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Configure agent via xinetd
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_xinetd() {  log_info "Configuring xinetd for CheckMK agent..."    local allowed_hosts="${CHECKMK_SERVER:-127.0.0.1}"    cat > /etc/xinetd.d/check_mk <<EOFservice check_mk{    type           = UNLISTED    port           = 6556    socket_type    = stream    protocol       = tcp    wait           = no    user           = root    server         = /usr/bin/check_mk_agent    only_from      = ${allowed_hosts} 127.0.0.1    disable        = no}EOF    
# Restart xinetd  log_command "systemctl restart xinetd"  log_command "systemctl enable xinetd"    log_success "xinetd configured"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Configure systemd socket (alternative to xinetd)
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_systemd_socket() {  log_info "Configuring systemd socket for CheckMK agent..."    
# Create socket unit  cat > /etc/systemd/system/check-mk-agent.socket <<EOF[Unit]Description=Check_MK Agent SocketDocumentation=http://mathias-kettner.com/checkmk.html[Socket]ListenStream=6556Accept=yes[Install]WantedBy=sockets.targetEOF    
# Create service unit  cat > /etc/systemd/system/check-mk-agent@.service <<EOF[Unit]Description=Check_MK AgentDocumentation=http://mathias-kettner.com/checkmk.html[Service]Type=simpleExecStart=/usr/bin/check_mk_agentStandardInput=socketStandardOutput=socketUser=rootEOF    
# Enable and start socket  log_command "systemctl daemon-reload"  log_command "systemctl enable check-mk-agent.socket"  log_command "systemctl start check-mk-agent.socket"    log_success "Systemd socket configured"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Install agent plugins
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#install_agent_plugins() {  log_info "Installing agent plugins..."    local plugins_dir="/usr/lib/check_mk_agent/plugins"  mkdir -p "$plugins_dir"    
# Copy plugins from local scripts if available  local local_plugins="${INSTALLER_ROOT}/scripts/script-check-ubuntu/polling"    if [[ -d "$local_plugins" ]]; then    log_debug "Copying plugins from: $local_plugins"        for plugin in "$local_plugins"/*; do      if [[ -f "$plugin" ]]; thenlocal plugin_namelocal plugin_nameplugin_name=$(basename "$plugin")        cp "$plugin" "$plugins_dir/"        chmod +x "$plugins_dir/$plugin_name"        log_debug "Installed plugin: $plugin_name"      fi    done        log_success "Agent plugins installed"
else    log_warning "No local plugins found"  fi}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
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
#configure_agent_firewall() {  log_info "Configuring firewall for agent..."    local server_ip="${CHECKMK_SERVER:-}"    if [[ -n "$server_ip" ]]; then    log_command "ufw allow from $server_ip to any port 6556 proto tcp comment 'CheckMK Server'"
else    log_command "ufw allow 6556/tcp comment 'CheckMK Agent'"  fi    log_success "Firewall configured"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Test agent connection
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#test_agent() {  log_info "Testing agent..."    if timeout 5 telnet 127.0.0.1 6556 </dev/null 2>/dev/null | grep -q "<<<check_mk>>>"; then    log_success "Agent is responding correctly"    return 0  else    log_warning "Agent test failed or timed out"    return 1  fi}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Create agent wrapper for custom checks
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#create_agent_wrapper() {  log_info "Creating agent wrapper script..."    cat > /usr/local/bin/check_mk_agent_wrapper.sh <<'EOF'
#!/bin/bash
# CheckMK Agent Wrapper
# Runs custom checks before standard agent output
# Run standard agent/usr/bin/check_mk_agent
# Add custom local checks
if [[ -d /usr/lib/check_mk_agent/local ]]; then  for check in /usr/lib/check_mk_agent/local/*; do    if [[ -x "$check" ]]; then      "$check"    fi  donefiEOF    chmod +x /usr/local/bin/check_mk_agent_wrapper.sh    
# Create local checks directory  mkdir -p /usr/lib/check_mk_agent/local    log_success "Agent wrapper created"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Register agent with server (auto-discovery)
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#register_with_server() {  local server="${CHECKMK_SERVER:-}"  local site="${CHECKMK_SITE_NAME:-monitoring}"    if [[ -z "$server" ]]; then    log_warning "CHECKMK_SERVER not configured, skipping auto-registration"    return 0  fi    log_info "Attempting auto-registration with server..."  local hostnamelocal hostnamehostname=$(hostname)  local api_url="http://${server}:${CHECKMK_HTTP_PORT:-5000}/${site}/check_mk/api/1.0"    
# This would require API credentials - just log the command for manual execution  log_info "To register this host, run on the CheckMK server:"  
echo "  
cmk -I $hostname"  
echo "  
cmk -O"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Display agent info
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#display_agent_info() {local server_iplocal server_ipserver_ip=$(hostname -I | awk '{print $1}')    print_separator "="  
echo ""  display_box "CheckMK Agent Installation Complete!" \    "" \    "Agent listening on: ${server_ip}:6556" \    "Plugins directory: /usr/lib/check_mk_agent/plugins" \    "Local checks: /usr/lib/check_mk_agent/local" \    "" \    "Test agent: telnet localhost 6556" \    "View output: check_mk_agent" \    "" \    "Next: Add this host to CheckMK server"  
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
#main() {  log_info "Starting CheckMK agent installation..."    
# Determine configuration method  local use_systemd="${USE_SYSTEMD_SOCKET:-yes}"    
# Download and install agentlocal packagelocal packagepackage=$(download_checkmk_agent)  install_checkmk_agent "$package"    
# Configure connection method  if [[ "$use_systemd" == "yes" ]]; then    configure_systemd_socket
else    configure_xinetd  fi    
# Additional configuration  install_agent_plugins  create_agent_wrapper  configure_agent_firewall    
# Test agent  sleep 2  test_agent || log_warning "Agent test inconclusive, check manually"    
# Try to register with server  register_with_server    log_module_end "$MODULE_NAME" "success"    display_agent_info}
# Run main functionmain "$@"

__CORRUPTED_TAIL__
