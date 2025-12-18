#!/usr/bin/env bash
set -euo pipefail

INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"

# shellcheck disable=SC1091
source "${INSTALLER_ROOT}/utils/colors.sh"
# shellcheck disable=SC1091
source "${INSTALLER_ROOT}/utils/menu.sh"
# shellcheck disable=SC1091
source "${INSTALLER_ROOT}/utils/validate.sh"

TEMPLATE_FILE="${INSTALLER_ROOT}/.env.template"
ENV_FILE="${INSTALLER_ROOT}/.env"

print_header "Configuration Wizard"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
	print_error "Missing template: $TEMPLATE_FILE"
	exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
	cp "$TEMPLATE_FILE" "$ENV_FILE"
	print_info "Created $ENV_FILE from template"
else
	print_info "Using existing $ENV_FILE"
fi

# Load current defaults
set -a
# shellcheck disable=SC1090
source "$ENV_FILE" 2>/dev/null || true
set +a

tmp_file="${ENV_FILE}.tmp"
cp "$ENV_FILE" "$tmp_file"

set_env() {
	local key="$1"
	local value="$2"
	local escaped env_line found=0
	local new_file="${tmp_file}.new"

	escaped=${value//\\/\\\\}
	escaped=${escaped//"/\\"}
	env_line="${key}=\"${escaped}\""

	: >"$new_file"
	while IFS= read -r line || [[ -n "${line:-}" ]]; do
		if [[ "$line" == ${key}=* ]]; then
			printf '%s\n' "$env_line" >>"$new_file"
			found=1
		else
			printf '%s\n' "$line" >>"$new_file"
		fi
	done <"$tmp_file"

	if [[ $found -eq 0 ]]; then
		printf '%s\n' "$env_line" >>"$new_file"
	fi

	mv "$new_file" "$tmp_file"
}

print_info "Premi INVIO per tenere il valore di default."
echo ""

# ===== System base =====
timezone=$(input_text "Timezone" "${TIMEZONE:-Europe/Rome}")
ssh_port=$(input_port "SSH port" "${SSH_PORT:-22}")
permit_root=$(input_text "PermitRootLogin (yes/no)" "${PERMIT_ROOT_LOGIN:-no}" "^(yes|no)$")

fail2ban_email=$(input_email "Fail2Ban notification email" "${FAIL2BAN_EMAIL:-root@localhost}")

open_http_https=$(input_text "Open HTTP/HTTPS in firewall (yes/no)" "${OPEN_HTTP_HTTPS:-no}" "^(yes|no)$")
disable_ipv6=$(input_text "Disable IPv6 (yes/no)" "${DISABLE_IPV6:-no}" "^(yes|no)$")

set_env "TIMEZONE" "$timezone"
set_env "SSH_PORT" "$ssh_port"
set_env "PERMIT_ROOT_LOGIN" "$permit_root"
set_env "FAIL2BAN_EMAIL" "$fail2ban_email"
set_env "OPEN_HTTP_HTTPS" "$open_http_https"
set_env "DISABLE_IPV6" "$disable_ipv6"

echo ""
print_header "Postfix / SMTP relay"
smtp_host=$(input_text "SMTP relay host (blank to disable)" "${SMTP_RELAY_HOST:-smtp-relay.nethesis.it}")
if [[ -z "$smtp_host" ]]; then
	set_env "SMTP_RELAY_HOST" ""
	set_env "SMTP_RELAY_USER" ""
	set_env "SMTP_RELAY_PASSWORD" ""
else
	set_env "SMTP_RELAY_HOST" "$smtp_host"
	smtp_user=$(input_text "SMTP username" "${SMTP_RELAY_USER:-}")
	smtp_pass=$(input_secret "SMTP password" "${SMTP_RELAY_PASSWORD:-}")
	set_env "SMTP_RELAY_USER" "$smtp_user"
	set_env "SMTP_RELAY_PASSWORD" "$smtp_pass"
fi

echo ""
print_header "CheckMK server"
install_server=$(input_text "Install CheckMK server? (yes/no)" "${INSTALL_CHECKMK_SERVER:-yes}" "^(yes|no)$")
deb_url=$(input_url "CheckMK .deb URL (optional; can be asked during install)" "${CHECKMK_DEB_URL:-}")
checkmk_version=$(input_text "CheckMK version (es. 2.4.0p17)" "${CHECKMK_VERSION:-}")
checkmk_codename=$(input_text "Ubuntu/Debian codename (es. noble, jammy)" "${CHECKMK_DISTRO_CODENAME:-${CHECKMK_CODENAME:-}}")
checkmk_edition=$(input_text "CheckMK edition (raw/enterprise)" "${CHECKMK_EDITION:-raw}" "^(raw|enterprise)$")
site_name=$(input_text "CheckMK site name" "${CHECKMK_SITE_NAME:-monitoring}" "^[a-z][a-z0-9_-]*$")
http_port=$(input_port "CheckMK HTTP port" "${CHECKMK_HTTP_PORT:-5000}")
admin_pwd=$(input_secret "CheckMK cmkadmin password" "${CHECKMK_ADMIN_PASSWORD:-}")
install_local_agent=$(input_text "Install agent on server itself? (yes/no)" "${INSTALL_LOCAL_AGENT:-yes}" "^(yes|no)$")

set_env "INSTALL_CHECKMK_SERVER" "$install_server"
set_env "CHECKMK_DEB_URL" "$deb_url"
set_env "CHECKMK_VERSION" "$checkmk_version"
set_env "CHECKMK_DISTRO_CODENAME" "$checkmk_codename"
set_env "CHECKMK_EDITION" "$checkmk_edition"
set_env "CHECKMK_SITE_NAME" "$site_name"
set_env "CHECKMK_HTTP_PORT" "$http_port"
set_env "CHECKMK_ADMIN_PASSWORD" "$admin_pwd"
set_env "INSTALL_LOCAL_AGENT" "$install_local_agent"

echo ""
print_header "CheckMK agent clients"
checkmk_server=$(input_text "CheckMK server IP/host (blank if this is the server)" "${CHECKMK_SERVER:-}")
use_socket=$(input_text "Use systemd socket for agent? (yes/no)" "${USE_SYSTEMD_SOCKET:-yes}" "^(yes|no)$")
set_env "CHECKMK_SERVER" "$checkmk_server"
set_env "USE_SYSTEMD_SOCKET" "$use_socket"

echo ""
print_header "FRPC (optional)"
install_frps=$(input_text "Install FRPS server? (yes/no)" "${INSTALL_FRPS:-no}" "^(yes|no)$")
install_frpc=$(input_text "Install FRPC client? (yes/no)" "${INSTALL_FRPC:-no}" "^(yes|no)$")

set_env "INSTALL_FRPS" "$install_frps"
set_env "INSTALL_FRPC" "$install_frpc"

if [[ "$install_frpc" == "yes" ]]; then
	frpc_addr=$(input_text "FRPC server address" "${FRPC_SERVER_ADDR:-}")
	frpc_port=$(input_port "FRPC server port" "${FRPC_SERVER_PORT:-7000}")
	frpc_token=$(input_secret "FRPC token" "${FRPC_TOKEN:-}")
	frpc_remote=$(input_text "FRPC remote port (agent)" "${FRPC_REMOTE_PORT:-}")
	set_env "FRPC_SERVER_ADDR" "$frpc_addr"
	set_env "FRPC_SERVER_PORT" "$frpc_port"
	set_env "FRPC_TOKEN" "$frpc_token"
	set_env "FRPC_REMOTE_PORT" "$frpc_remote"
else
	# Ensure we don't accidentally configure FRPC when not requested
	set_env "FRPC_SERVER_ADDR" ""
	set_env "FRPC_SERVER_PORT" "7000"
	set_env "FRPC_TOKEN" ""
	set_env "FRPC_REMOTE_PORT" ""
fi

echo ""
print_header "Ydea (optional)"
ydea_id=$(input_text "Ydea ID" "${YDEA_ID:-}")
ydea_key=$(input_secret "Ydea API key" "${YDEA_API_KEY:-}")
set_env "YDEA_ID" "$ydea_id"
set_env "YDEA_API_KEY" "$ydea_key"

mv "$tmp_file" "$ENV_FILE"
chmod 600 "$ENV_FILE" 2>/dev/null || true
print_success "Saved configuration to $ENV_FILE"
exit 0
# shellcheck disable=SC2317
: <<'__CORRUPTED_TAIL__'
#!/usr/bin/env bash
set -euo pipefail

INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${INSTALLER_ROOT}/utils/colors.sh"
source "${INSTALLER_ROOT}/utils/menu.sh"

TEMPLATE_FILE="${INSTALLER_ROOT}/.env.template"
ENV_FILE="${INSTALLER_ROOT}/.env"

print_header "Configuration Wizard"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
	print_error "Missing template: $TEMPLATE_FILE"
	exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
	cp "$TEMPLATE_FILE" "$ENV_FILE"
	print_info "Created $ENV_FILE from template"
else
	print_info "Using existing $ENV_FILE"
fi

tmp_file="${ENV_FILE}.tmp"
cp "$ENV_FILE" "$tmp_file"

set_kv() {
	local key="$1"
	local value="$2"
	if grep -qE "^${key}=" "$tmp_file"; then
		sed -i -E "s|^${key}=.*|${key}=${value}|" "$tmp_file"
	else
		echo "${key}=${value}" >>"$tmp_file"
	fi
}

ssh_port=$(prompt_input "SSH Port" "22")
timezone=$(prompt_input "Timezone" "UTC")
permit_root=$(prompt_input "PermitRootLogin (yes/no)" "no")

site_name=$(prompt_input "CheckMK site name" "cmk")
checkmk_server=$(prompt_input "CheckMK server (hostname/ip for agent downloads)" "")
checkmk_deb_url=$(prompt_input "CheckMK server .deb URL (for server install)" "")

frp_version=$(prompt_input "FRP version" "0.61.0")
frpc_server_addr=$(prompt_input "FRPC server address" "")
frpc_server_port=$(prompt_input "FRPC server port" "7000")

ydea_id=$(prompt_input "Ydea ID" "")
ydea_user=$(prompt_input "Ydea User ID (create ticket)" "")

set_kv "SSH_PORT" "$ssh_port"
set_kv "TIMEZONE" "$timezone"
set_kv "PERMIT_ROOT_LOGIN" "$permit_root"
set_kv "CHECKMK_SITE_NAME" "$site_name"
set_kv "CHECKMK_SERVER" "$checkmk_server"
set_kv "CHECKMK_DEB_URL" "$checkmk_deb_url"
set_kv "FRP_VERSION" "$frp_version"
set_kv "FRPC_SERVER_ADDR" "$frpc_server_addr"
set_kv "FRPC_SERVER_PORT" "$frpc_server_port"
set_kv "YDEA_ID" "$ydea_id"
set_kv "YDEA_USER_ID_CREATE_TICKET" "$ydea_user"

mv "$tmp_file" "$ENV_FILE"
print_success "Saved configuration to $ENV_FILE"
#!/usr/bin/env bash
set -euo pipefail

# config-wizard.sh - Interactive configuration wizard

INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=utils/colors.sh
source "${INSTALLER_ROOT}/utils/colors.sh"
# shellcheck source=utils/menu.sh
source "${INSTALLER_ROOT}/utils/menu.sh"

ENV_FILE="${INSTALLER_ROOT}/.env"
ENV_TEMPLATE="${INSTALLER_ROOT}/.env.template"

replace_kv() {
	local file="$1" key="$2" value="$3"
	# Escape backslashes and quotes for sed replacement
	local escaped
	escaped=$(printf '%s' "$value" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
	if grep -qE "^${key}=\"" "$file"; then
		sed -i -E "s|^${key}=\".*\"|${key}=\"${escaped}\"|" "$file"
	else
		echo "${key}=\"${value}\"" >>"$file"
	fi
}

replace_raw() {
	local file="$1" key="$2" value="$3"
	local escaped
	escaped=$(printf '%s' "$value" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
	if grep -qE "^${key}=" "$file"; then
		sed -i -E "s|^${key}=.*|${key}=\"${escaped}\"|" "$file"
	else
		echo "${key}=\"${value}\"" >>"$file"
	fi
}

main() {
	print_header "Configuration Wizard"

	if [[ ! -f "$ENV_TEMPLATE" ]]; then
		print_error "Template not found: $ENV_TEMPLATE"
		exit 1
	fi

	if [[ -f "$ENV_FILE" ]]; then
		print_warning "An existing .env was found: $ENV_FILE"
		if ! confirm "Overwrite it with defaults from .env.template?" "n"; then
			print_info "Keeping existing .env and updating selected values."
		else
			cp -a "$ENV_TEMPLATE" "$ENV_FILE"
		fi
	else
		cp -a "$ENV_TEMPLATE" "$ENV_FILE"
	fi

	chmod 600 "$ENV_FILE" 2>/dev/null || true

	print_info "Enter values (leave blank to keep defaults)"
	echo ""

	local timezone ssh_port permit_root install_server deb_url site_name http_port admin_pwd
	local checkmk_server ydea_id ydea_key frpc_addr frpc_port frpc_token frpc_remote

	timezone=$(input_text "Timezone" "Europe/Rome")
	ssh_port=$(input_text "SSH port" "22")
	permit_root=$(input_text "PermitRootLogin (yes/no)" "no")
	install_server=$(input_text "Install CheckMK server? (yes/no)" "yes")
	deb_url=$(input_text "CheckMK DEB URL (optional)" "")
	site_name=$(input_text "CheckMK site name" "monitoring")
	http_port=$(input_text "CheckMK HTTP port" "5000")
	admin_pwd=$(input_text "CheckMK cmkadmin password" "")
	checkmk_server=$(input_text "CheckMK server IP/host (clients)" "")

	ydea_id=$(input_text "Ydea ID (optional)" "")
	ydea_key=$(input_text "Ydea API key (optional)" "")

	frpc_addr=$(input_text "FRPC server address (optional)" "")
	frpc_port=$(input_text "FRPC server port" "7000")
	frpc_token=$(input_text "FRPC token (optional)" "")
	frpc_remote=$(input_text "FRPC remote port for CheckMK agent (optional)" "")

	replace_kv "$ENV_FILE" "TIMEZONE" "$timezone"
	replace_kv "$ENV_FILE" "SSH_PORT" "$ssh_port"
	replace_kv "$ENV_FILE" "PERMIT_ROOT_LOGIN" "$permit_root"
	replace_kv "$ENV_FILE" "INSTALL_CHECKMK_SERVER" "$install_server"
	replace_kv "$ENV_FILE" "CHECKMK_SITE_NAME" "$site_name"
	replace_kv "$ENV_FILE" "CHECKMK_HTTP_PORT" "$http_port"
	[[ -n "$deb_url" ]] && replace_raw "$ENV_FILE" "CHECKMK_DEB_URL" "$deb_url" || true
	[[ -n "$admin_pwd" ]] && replace_raw "$ENV_FILE" "CHECKMK_ADMIN_PASSWORD" "$admin_pwd" || true
	[[ -n "$checkmk_server" ]] && replace_raw "$ENV_FILE" "CHECKMK_SERVER" "$checkmk_server" || true

	[[ -n "$ydea_id" ]] && replace_raw "$ENV_FILE" "YDEA_ID" "$ydea_id" || true
	[[ -n "$ydea_key" ]] && replace_raw "$ENV_FILE" "YDEA_API_KEY" "$ydea_key" || true

	[[ -n "$frpc_addr" ]] && replace_raw "$ENV_FILE" "FRPC_SERVER_ADDR" "$frpc_addr" || true
	replace_raw "$ENV_FILE" "FRPC_SERVER_PORT" "$frpc_port"
	[[ -n "$frpc_token" ]] && replace_raw "$ENV_FILE" "FRPC_TOKEN" "$frpc_token" || true
	[[ -n "$frpc_remote" ]] && replace_raw "$ENV_FILE" "FRPC_REMOTE_PORT" "$frpc_remote" || true

	echo ""
	print_success "Configuration saved to: $ENV_FILE"
}

main "$@"
#!/bin/bash
/usr/bin/env bash
# config-wizard.sh - Interactive configuration wizard
# Guides user through complete system configurationset -euo pipefail
INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source utilitiessource "${INSTALLER_ROOT}/utils/colors.sh"source "${INSTALLER_ROOT}/utils/menu.sh"source "${INSTALLER_ROOT}/utils/validate.sh"
ENV_FILE="${INSTALLER_ROOT}/.env"
ENV_TEMPLATE="${INSTALLER_ROOT}/.env.template"
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Welcome
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#show_wizard_welcome() {  clear  print_header "CheckMK Configuration Wizard"  
echo ""  
echo "This wizard will guide you through the configuration process."  
echo "You can press ENTER to accept default values shown in [brackets]."  
echo ""  press_any_key}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Backup existing configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#backup_existing_config() {  if [[ -f "$ENV_FILE" ]]; then    local backup="${ENV_FILE}.bak.$(date +%Y%m%d_%H%M%S)"    cp "$ENV_FILE" "$backup"    print_success "Existing configuration backed up to: $backup"  fi}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# System Base Configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_system_base() {  print_header "System Base Configuration"  
echo ""    
TIMEZONE=$(input_text "Timezone" "Europe/Rome")  
SSH_PORT=$(input_port "SSH Port" "22")  
PERMIT_ROOT_LOGIN=$(select_from_list "Permit root login via SSH?" "no" "yes" "without-password")  
CLIENT_ALIVE_INTERVAL=$(input_text "SSH ClientAliveInterval (seconds)" "300" "^[0-9]+$")  
CLIENT_ALIVE_COUNTMAX=$(input_text "SSH ClientAliveCountMax" "3" "^[0-9]+$")  
LOGIN_GRACE_TIME=$(input_text "SSH LoginGraceTime (seconds)" "60" "^[0-9]+$")  
SSH_PASSWORD_AUTH=$(select_from_list "Allow SSH password authentication?" "yes" "no")    
echo ""  if confirm "Change root password?" "n"; then
    ROOT_PASSWORD=$(input_password "New root password" true)  else    
ROOT_PASSWORD=""  fi
echo ""  
NTP_SERVERS=$(input_text "NTP servers (space-separated)" "0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org")    
echo ""  
OPEN_HTTP_HTTPS=$(select_from_list "Open HTTP/HTTPS ports in firewall?" "no" "yes")  FAIL2
BAN_EMAIL=$(input_email "Fail2Ban notification email" "root@localhost")    
echo ""  
SMTP_RELAY_HOST=$(input_text "SMTP relay host" "smtp-relay.nethesis.it")    if [[ -n "$SMTP_RELAY_HOST" ]]; then
    echo ""    
echo "SMTP relay configured: $SMTP_RELAY_HOST"    
echo "Please provide authentication credentials:"    
SMTP_RELAY_USER=$(input_text "SMTP username" "")    
SMTP_RELAY_PASSWORD=$(input_password "SMTP password" false)  else    
SMTP_RELAY_USER=""    
SMTP_RELAY_PASSWORD=""  fi
echo ""  DISABLE_IPV6=$(select_from_list "Disable IPv6?" "no" "yes")    print_success "System base configuration complete"  press_any_key}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# CheckMK Server Configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_checkmk_server() {  print_header "CheckMK Server Configuration"  
echo ""    if ! confirm "Will this be a CheckMK server?" "y"; then
    INSTALL_CHECKMK_SERVER="no"    return 0  fi    
INSTALL_CHECKMK_SERVER="yes"    
echo ""  print_info "CheckMK download URL"  
echo "Example: https://download.checkmk.com/checkmk/2.4.0p15/check-mk-raw-2.4.0p15_0.jammy_amd64.deb"  
CHECKMK_DEB_URL=$(input_url "CheckMK .deb URL" "")    
echo ""  
CHECKMK_SITE_NAME=$(input_text "CheckMK site name" "monitoring" "^[a-z][a-z0-9_-]*$")  
CHECKMK_HTTP_PORT=$(input_port "CheckMK HTTP port" "5000")  
CHECKMK_ADMIN_PASSWORD=$(input_password "CheckMK admin password" true)    
echo ""  
INSTALL_LOCAL_AGENT=$(select_from_list "Install CheckMK agent locally?" "yes" "no")    print_success "CheckMK server configuration complete"  press_any_key}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# CheckMK Agent Configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_checkmk_agent() {  print_header "CheckMK Agent Configuration"  
echo ""    if ! confirm "Will this be a CheckMK agent (client)?" "n"; then    return 0  fi
echo ""  
CHECKMK_SERVER=$(input_ip "CheckMK server IP address" "")  
CHECKMK_HTTP_PORT=$(input_port "CheckMK server HTTP port" "5000")  
CHECKMK_SITE_NAME=$(input_text "CheckMK site name on server" "monitoring")    
echo ""  
USE_SYSTEMD_SOCKET=$(select_from_list "Use systemd socket (recommended)?" "yes" "no")    print_success "CheckMK agent configuration complete"  press_any_key}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Ydea Toolkit Configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_ydea_toolkit() {  print_header "Ydea Toolkit Configuration"  
echo ""    if ! confirm "Configure Ydea Cloud integration?" "n"; then    return 0  fi
echo ""  print_info "Ydea Cloud API Credentials"  
echo "You can find these in your Ydea Cloud account settings"  
echo ""    
YDEA_ID=$(input_text "Ydea ID" "" "^[0-9]+$")  
YDEA_API_KEY=$(input_password "Ydea API Key" false)    
# User selection  
echo ""  print_info "User Configuration"  
echo "Select which user(s) will create tickets:"  
echo "  1) Lorenzo Angelini (ID: 12336) - uses ydea_la/rydea_la"  
echo "  2) Alessandro Gaggiano (ID: 4675) - uses ydea_ag/rydea_ag"  
echo "  3) Both users (creates both configurations)"  
echo ""    local user_choice  while true; do    read -rp "Select option [1-3]: " user_choice    case "$user_choice" in      1)        
YDEA_USER_SELECTION="lorenzo"        
YDEA_USER_ID_CREATE_TICKET=12336        
YDEA_USER_ID_CREATE_NOTE=12336        print_info "Configuring for Lorenzo Angelini only"        break        ;;      2)        
YDEA_USER_SELECTION="alessandro"        
YDEA_USER_ID_CREATE_TICKET=4675        
YDEA_USER_ID_CREATE_NOTE=4675        print_info "Configuring for Alessandro Gaggiano only"        break        ;;      3)        
YDEA_USER_SELECTION="both"        
YDEA_USER_ID_CREATE_TICKET=12336  
# Default to Lorenzo for backward compatibility        
YDEA_USER_ID_CREATE_NOTE=12336        print_info "Configuring for both users"        break        ;;      *)        print_error "Invalid selection. Please choose 1, 2, or 3"        ;;    esac  done
echo ""  print_info "Tracking Configuration"  
YDEA_TRACKING_RETENTION_DAYS=$(input_text "Ticket tracking retention (days)" "365" "^[0-9]+$")  
YDEA_MONITOR_INTERVAL=$(input_text "Monitoring interval (minutes)" "30" "^[0-9]+$")    
echo ""  
USE_SYSTEMD_TIMER=$(select_from_list "Use systemd timer for monitoring?" "yes" "no")  
YDEA_DEBUG=$(select_from_list "Enable debug logging?" "0" "1")    print_success "Ydea toolkit configuration complete"  press_any_key}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# FRPC Configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_frpc() {  print_header "FRPC Client Configuration"  
echo ""    if ! confirm "Configure FRPC client?" "n"; then    return 0  fi
echo ""  print_info "FRPC Server Details"  
FRPC_SERVER_ADDR=$(input_hostname "FRPC server address" "")  
FRPC_SERVER_PORT=$(input_port "FRPC server port" "7000")  
FRPC_TOKEN=$(input_password "FRPC authentication token" false)    
echo ""  print_info "FRPC Port Mapping"  
FRPC_REMOTE_PORT=$(input_port "Remote port for CheckMK agent" "")  
FRPC_SSH_REMOTE_PORT=$(input_port "Remote port for SSH (optional)" "")    
echo ""  print_info "FRPC Admin Interface"  
FRPC_ADMIN_USER=$(input_text "Admin username" "admin")  
FRPC_ADMIN_PWD=$(input_password "Admin password" false)    
echo ""  
FRPC_VERSION=$(input_text "FRPC version" "0.52.3")  
FRPC_DOMAIN=$(input_text "Domain for HTTP proxies (optional)" "example.com")    print_success "FRPC configuration complete"  press_any_key}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Generate configuration file
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#generate_config_file() {  print_header "Generating Configuration"  
echo ""    print_info "Writing configuration to: $ENV_FILE"    cat > "$ENV_FILE" <<EOF
# CheckMK Installer Configuration
# Generated: $(date)
# Wizard version: 1.0
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# System Base Configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
TIMEZONE="${TIMEZONE:-UTC}"
SSH_PORT="${SSH_PORT:-22}"
PERMIT_ROOT_LOGIN="${PERMIT_ROOT_LOGIN:-no}"
CLIENT_ALIVE_INTERVAL="${CLIENT_ALIVE_INTERVAL:-300}"
CLIENT_ALIVE_COUNTMAX="${CLIENT_ALIVE_COUNTMAX:-3}"
LOGIN_GRACE_TIME="${LOGIN_GRACE_TIME:-60}"
SSH_PASSWORD_AUTH="${SSH_PASSWORD_AUTH:-yes}"
ROOT_PASSWORD="${ROOT_PASSWORD:-}"
NTP_SERVERS="${NTP_SERVERS:-0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org}"
OPEN_HTTP_HTTPS="${OPEN_HTTP_HTTPS:-no}"FAIL2
BAN_EMAIL="${FAIL2BAN_EMAIL:-root@localhost}"
SMTP_RELAY_HOST="${SMTP_RELAY_HOST:-}"
SMTP_RELAY_USER="${SMTP_RELAY_USER:-}"
SMTP_RELAY_PASSWORD="${SMTP_RELAY_PASSWORD:-}"DISABLE_IPV6="${DISABLE_IPV6:-no}"
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# CheckMK Server Configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
INSTALL_CHECKMK_SERVER="${INSTALL_CHECKMK_SERVER:-no}"
CHECKMK_DEB_URL="${CHECKMK_DEB_URL:-}"
CHECKMK_SITE_NAME="${CHECKMK_SITE_NAME:-monitoring}"
CHECKMK_HTTP_PORT="${CHECKMK_HTTP_PORT:-5000}"
CHECKMK_ADMIN_PASSWORD="${CHECKMK_ADMIN_PASSWORD:-}"
INSTALL_LOCAL_AGENT="${INSTALL_LOCAL_AGENT:-yes}"
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# CheckMK Agent Configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
CHECKMK_SERVER="${CHECKMK_SERVER:-}"
USE_SYSTEMD_SOCKET="${USE_SYSTEMD_SOCKET:-yes}"
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Ydea Toolkit Configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
YDEA_ID="${YDEA_ID:-}"
YDEA_API_KEY="${YDEA_API_KEY:-}"
YDEA_USER_SELECTION="${YDEA_USER_SELECTION:-lorenzo}"  
# lorenzo, alessandro, or both
YDEA_USER_ID_CREATE_TICKET="${YDEA_USER_ID_CREATE_TICKET:-4675}"
YDEA_USER_ID_CREATE_NOTE="${YDEA_USER_ID_CREATE_NOTE:-4675}"
YDEA_TRACKING_RETENTION_DAYS="${YDEA_TRACKING_RETENTION_DAYS:-365}"
YDEA_MONITOR_INTERVAL="${YDEA_MONITOR_INTERVAL:-30}"
USE_SYSTEMD_TIMER="${USE_SYSTEMD_TIMER:-yes}"
YDEA_DEBUG="${YDEA_DEBUG:-0}"
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# FRPC Configuration
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
FRPC_SERVER_ADDR="${FRPC_SERVER_ADDR:-}"
FRPC_SERVER_PORT="${FRPC_SERVER_PORT:-7000}"
FRPC_TOKEN="${FRPC_TOKEN:-}"
FRPC_REMOTE_PORT="${FRPC_REMOTE_PORT:-}"
FRPC_SSH_REMOTE_PORT="${FRPC_SSH_REMOTE_PORT:-}"
FRPC_ADMIN_USER="${FRPC_ADMIN_USER:-admin}"
FRPC_ADMIN_PWD="${FRPC_ADMIN_PWD:-admin}"
FRPC_VERSION="${FRPC_VERSION:-0.52.3}"
FRPC_DOMAIN="${FRPC_DOMAIN:-example.com}"
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Advanced Options
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
VERBOSE="${VERBOSE:-0}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"EOF    chmod 600 "$ENV_FILE"    print_success "Configuration file created!"  
echo ""  print_info "Configuration saved to: $ENV_FILE"  
echo ""  press_any_key}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Configuration summary
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#show_configuration_summary() {  print_header "Configuration Summary"  
echo ""    
echo "${CYAN}System Base:${NC}"  
echo "  Timezone: ${TIMEZONE}"  
echo "  SSH Port: ${SSH_PORT}"  
echo "  Root Login: ${PERMIT_ROOT_LOGIN}"  
echo ""    if [[ "${INSTALL_CHECKMK_SERVER:-no}" == "yes" ]]; then
    echo "${CYAN}CheckMK Server:${NC}"    
echo "  Site Name: ${CHECKMK_SITE_NAME}"    
echo "  HTTP Port: ${CHECKMK_HTTP_PORT}"    
echo ""  fi    if [[ -n "${CHECKMK_SERVER:-}" ]]; then
    echo "${CYAN}CheckMK Agent:${NC}"    
echo "  Server: ${CHECKMK_SERVER}"    
echo "  Method: ${USE_SYSTEMD_SOCKET}"    
echo ""  fi    if [[ -n "${YDEA_ID:-}" ]]; then
    echo "${CYAN}Ydea Toolkit:${NC}"    
echo "  Ydea ID: ${YDEA_ID}"    
echo "  Monitoring: Every ${YDEA_MONITOR_INTERVAL} min"    
echo ""  fi    if [[ -n "${FRPC_SERVER_ADDR:-}" ]]; then
    echo "${CYAN}FRPC Client:${NC}"    
echo "  Server: ${FRPC_SERVER_ADDR}:${FRPC_SERVER_PORT}"    
echo "  Remote Port: ${FRPC_REMOTE_PORT}"    
echo ""  fi    press_any_key}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Main wizard flow
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#main() {  show_wizard_welcome    
# Backup existing config  backup_existing_config    
# Run configuration steps  configure_system_base  configure_checkmk_server  configure_checkmk_agent  configure_ydea_toolkit  configure_frpc    
# Generate config file  generate_config_file    
# Show summary  show_configuration_summary    print_separator "="  print_success "Configuration wizard complete!"  print_separator "="  
echo ""  print_info "You can now run the installer to deploy your configuration"  
echo ""}
# Run wizardmain "$@"
__CORRUPTED_TAIL__
