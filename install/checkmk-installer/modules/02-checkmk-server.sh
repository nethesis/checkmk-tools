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

	print_header "CheckMK Server"

	local deb_url="${CHECKMK_DEB_URL:-}"
	local checkmk_version="${CHECKMK_VERSION:-}"
	local checkmk_codename="${CHECKMK_DISTRO_CODENAME:-${CHECKMK_CODENAME:-}}"
	local checkmk_edition="${CHECKMK_EDITION:-raw}"
	local site_name="${CHECKMK_SITE_NAME:-cmk}"
	local http_port="${CHECKMK_HTTP_PORT:-5000}"
	local admin_pwd="${CHECKMK_ADMIN_PASSWORD:-}"

	build_deb_url() {
		local version="$1" codename="$2" edition="$3"
		[[ -n "$version" && -n "$codename" ]] || return 1
		case "$edition" in
			raw) edition="raw" ;;
			enterprise) edition="enterprise" ;;
			*) edition="raw" ;;
		esac
		echo "https://download.checkmk.com/checkmk/${version}/check-mk-${edition}-${version}_0.${codename}_amd64.deb"
	}

	download_deb() {
		local url="$1" dest="$2"
		print_info "Downloading: $url"
		if command -v curl >/dev/null 2>&1; then
				local -a curl_opts=(--fail --location --show-error --connect-timeout 10 --max-time 1200 --retry 5 --retry-connrefused --retry-delay 2 --speed-time 30 --speed-limit 1024)
			if [[ -t 1 ]]; then
				curl "${curl_opts[@]}" --progress-bar -o "$dest" "$url"
			else
				curl "${curl_opts[@]}" --silent -o "$dest" "$url"
			fi
		elif command -v wget >/dev/null 2>&1; then
			wget --tries=5 --timeout=30 --progress=dot:giga -O "$dest" "$url"
		else
			print_error "Neither curl nor wget found"
			return 1
		fi
		[[ -s "$dest" ]] || { print_error "Downloaded file is empty: $dest"; return 1; }
	}

	set_env_kv() {
		local key="$1" value="$2"
		local env_file="${INSTALLER_ROOT}/.env"
		[[ -f "$env_file" ]] || return 0
		local escaped env_line found=0
		local new_file="${env_file}.new"

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
		done <"$env_file"

		if [[ $found -eq 0 ]]; then
			printf '%s\n' "$env_line" >>"$new_file"
		fi

		mv "$new_file" "$env_file"
	}

	if [[ -z "$deb_url" ]]; then
		# Try to build from version+codename first (no prompt needed if already configured)
		if [[ -n "$checkmk_version" && -n "$checkmk_codename" ]]; then
			deb_url=$(build_deb_url "$checkmk_version" "$checkmk_codename" "$checkmk_edition")
			print_info "Using generated URL: $deb_url"
			set_env_kv "CHECKMK_DEB_URL" "$deb_url"
		else
			print_info "CheckMK .deb URL non impostato."
			print_info "Puoi incollare l'URL completo oppure inserire solo versione+distro e lo genero io."
			print_info "Esempio URL: https://download.checkmk.com/checkmk/2.4.0p17/check-mk-raw-2.4.0p17_0.noble_amd64.deb"
			deb_url=$(input_url "Inserisci URL .deb (INVIO per generare)" "")
			if [[ -z "$deb_url" ]]; then
				checkmk_version=$(input_text "CheckMK version (es. 2.4.0p17)" "${checkmk_version}")
				checkmk_codename=$(input_text "Ubuntu/Debian codename (es. noble, jammy)" "${checkmk_codename}")
				checkmk_edition=$(input_text "CheckMK edition (raw/enterprise)" "${checkmk_edition}" "^(raw|enterprise)$")
				deb_url=$(build_deb_url "$checkmk_version" "$checkmk_codename" "$checkmk_edition") || true
				if [[ -z "$deb_url" ]]; then
					print_error "Impossibile costruire l'URL: versione/codename mancanti"
					exit 1
				fi
				set_env_kv "CHECKMK_VERSION" "$checkmk_version"
				set_env_kv "CHECKMK_DISTRO_CODENAME" "$checkmk_codename"
				set_env_kv "CHECKMK_EDITION" "$checkmk_edition"
				set_env_kv "CHECKMK_DEB_URL" "$deb_url"
				print_info "Generated URL: $deb_url"
			else
				set_env_kv "CHECKMK_DEB_URL" "$deb_url"
			fi
		fi
	fi

	local deb_path="/tmp/checkmk-server.deb"
	download_deb "$deb_url" "$deb_path"

	print_info "Installing .deb (may take a while)"
	dpkg -i "$deb_path" || true
	apt-get -f install -y

	if [[ -n "$admin_pwd" ]] && command -v omd >/dev/null 2>&1; then
		# Best-effort: set password after site creation.
		true
	fi

	if command -v omd >/dev/null 2>&1; then
		if ! omd sites 2>/dev/null | awk '{print $1}' | grep -qx "$site_name"; then
			print_info "Creating site: $site_name"
			omd create "$site_name"
		fi
		if [[ -n "$http_port" ]]; then
			omd config "$site_name" set APACHE_TCP_PORT "$http_port" 2>/dev/null || true
		fi
		if [[ -n "$admin_pwd" ]]; then
			omd su "$site_name" -c "htpasswd -b etc/htpasswd cmkadmin '$admin_pwd'" 2>/dev/null || true
		fi
		print_info "Starting site: $site_name"
		omd start "$site_name" || true
	else
		print_warning "omd not found; CheckMK installation may be incomplete"
	fi

	print_success "CheckMK server module completed"
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

	print_header "CheckMK Server"

	local deb_url="${CHECKMK_DEB_URL:-}"
	local site_name="${CHECKMK_SITE_NAME:-cmk}"

	if [[ -z "$deb_url" ]]; then
		print_error "CHECKMK_DEB_URL is not set in .env"
		print_info "Run Configuration Wizard and set a CheckMK .deb URL"
		exit 1
	fi

	local deb_path="/tmp/checkmk-server.deb"
	print_info "Downloading: $deb_url"
	curl -fsSL "$deb_url" -o "$deb_path"

	print_info "Installing .deb (may take a while)"
	dpkg -i "$deb_path" || true
	apt-get -f install -y

	if command -v omd >/dev/null 2>&1; then
		if ! omd sites 2>/dev/null | awk '{print $1}' | grep -qx "$site_name"; then
			print_info "Creating site: $site_name"
			omd create "$site_name"
		fi
		print_info "Starting site: $site_name"
		omd start "$site_name" || true
	else
		print_warning "omd not found; CheckMK installation may be incomplete"
	fi

	print_success "CheckMK server module completed"
}

main "$@"
#!/usr/bin/env bash
set -euo pipefail

MODULE_NAME="CheckMK Server Installation"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../utils/colors.sh
source "${INSTALLER_ROOT}/utils/colors.sh"
# shellcheck source=../utils/logger.sh
source "${INSTALLER_ROOT}/utils/logger.sh"
# shellcheck source=../utils/menu.sh
source "${INSTALLER_ROOT}/utils/menu.sh"
# shellcheck source=../utils/validate.sh
source "${INSTALLER_ROOT}/utils/validate.sh"

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

get_checkmk_url() {
	local url="${CHECKMK_DEB_URL:-}"
	if [[ -n "$url" ]]; then
		echo "$url"
		return 0
	fi

	print_info "CheckMK download URL is not set in .env"
	print_info "Example: https://download.checkmk.com/checkmk/2.4.0p15/check-mk-raw-2.4.0p15_0.jammy_amd64.deb"
	url=$(input_url "CheckMK DEB download URL" "")
	if [[ -z "$url" ]]; then
		log_error "No CheckMK URL provided"
		return 1
	fi
	echo "$url"
}

download_checkmk() {
	local url="$1"
	local dest="/tmp/check-mk-raw.deb"
	log_info "Downloading CheckMK: $url"
	log_command "rm -f '$dest'"
	log_command "wget -O '$dest' '$url'"
	[[ -s "$dest" ]] || { log_error "Downloaded file is empty: $dest"; return 1; }
}

install_checkmk_package() {
	local deb="/tmp/check-mk-raw.deb"
	[[ -f "$deb" ]] || { log_error "Package not found: $deb"; return 1; }
	log_info "Installing CheckMK package"
	set +e
	dpkg -i "$deb"
	local rc=$?
	set -e
	if [[ $rc -ne 0 ]]; then
		log_warning "dpkg reported errors; attempting to fix dependencies"
		DEBIAN_FRONTEND=noninteractive apt-get -f install -y
		dpkg -i "$deb" || true
	fi
}

create_or_update_site() {
	local site="${CHECKMK_SITE_NAME:-monitoring}"
	local port="${CHECKMK_HTTP_PORT:-5000}"
	local password="${CHECKMK_ADMIN_PASSWORD:-}"

	command -v omd >/dev/null 2>&1 || { log_error "omd not found after installation"; return 1; }

	if omd sites 2>/dev/null | awk '{print $1}' | grep -qx "$site"; then
		log_info "Site already exists: $site"
	else
		log_info "Creating site: $site"
		omd create "$site"
		omd enable "$site" || true
	fi

	if [[ -n "$port" ]]; then
		log_info "Setting site Apache port: $port"
		omd config "$site" set APACHE_TCP_PORT "$port" 2>/dev/null || log_warning "Could not set APACHE_TCP_PORT (omd config)"
	fi

	if [[ -n "$password" ]]; then
		log_info "Setting cmkadmin password"
		omd su "$site" -c "htpasswd -b etc/htpasswd cmkadmin '$password'" || log_warning "Failed to set cmkadmin password"
	fi

	log_info "Starting site: $site"
	omd start "$site" || true

	if command -v ufw >/dev/null 2>&1; then
		ufw allow "${port}"/tcp >/dev/null 2>&1 || true
	fi

	local server_ip
	server_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
	server_ip=${server_ip:-localhost}
	print_separator "="
	print_success "CheckMK server installation complete"
	echo "URL: http://${server_ip}:${port}/${site}/"
	echo "User: cmkadmin"
	[[ -n "$password" ]] && echo "Password: (as configured in .env)"
	print_separator "="
}

main() {
	require_root
	log_module_start "$MODULE_NAME"

	if [[ "${INSTALL_CHECKMK_SERVER:-yes}" != "yes" ]]; then
		log_info "INSTALL_CHECKMK_SERVER=no; skipping"
		log_module_end "$MODULE_NAME" "success"
		return 0
	fi

	apt_install ca-certificates wget curl jq apache2-utils xinetd || true

	local url
	url=$(get_checkmk_url)
	download_checkmk "$url"
	install_checkmk_package
	create_or_update_site

	log_module_end "$MODULE_NAME" "success"
}

main "$@"
#!/bin/bash
/usr/bin/env bash
# 02-checkmk-server.sh - CheckMK Server installation module
# Installs and configures CheckMK monitoring serverset -euo pipefail
MODULE_NAME="CheckMK Server Installation"
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
# Get latest CheckMK version URL
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#get_latest_checkmk_url() {  log_info "Finding latest CheckMK RAW version..." >&2    local os_codename  os_codename=$(lsb_release -sc)    
# Scrape the download page to find the latest stable version  local latest_version  latest_version=$(curl -s https://checkmk.com/download | grep -oP 'Stable:.*?v\K[0-9]+\.[0-9]+\.[0-9]+p[0-9]+' | head -1 || 
echo "")    if [[ -z "$latest_version" ]]; then    log_warning "Could not determine latest version from website, trying alternative method..." >&2    
# Try to list versions from download server    latest_version=$(curl -s https://download.checkmk.com/checkmk/ | grep -oP 'href="[0-9]+\.[0-9]+\.[0-9]+p[0-9]+/"' | grep -oP '[0-9]+\.[0-9]+\.[0-9]+p[0-9]+' | sort -V | tail -1 || 
echo "")  fi    if [[ -z "$latest_version" ]]; then    log_warning "Could not auto-detect version, using default 2.4.0p16" >&2    latest_version="2.4.0p16"  fi    local url="https://download.checkmk.com/checkmk/${latest_version}/check-mk-raw-${latest_version}_0.${os_codename}_amd64.deb"    log_info "Latest version: $latest_version for $os_codename" >&2  
echo "$url"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Download CheckMK
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#download_checkmk() {  local url="$1"  local dest="/tmp/check-mk-raw.deb"    log_info "Downloading CheckMK from: $url"    if [[ -f "$dest" ]]; then    log_warning "CheckMK package already exists, using cached version"    return 0  fi    if ! log_command "wget -O '$dest' '$url'"; then    log_error "Failed to download CheckMK"    return 1  fi    log_success "CheckMK downloaded to $dest"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Install CheckMK dependencies
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#install_checkmk_dependencies() {  log_info "Installing CheckMK dependencies..."    
# Detect Python versionlocal python_versionlocal python_versionpython_version=$(python3 --version 2>&1 | grep -oP '\d+\.\d+' | head -1)  log_debug "Detected Python version: $python_version"    local deps=(    "apache2"    "libapache2-mod-fcgid"    "libpython${python_version}"    "librrd8"    "libsensors5"    "python3"    "python3-pip"    "rrdtool"    "snmp"    "php-cli"    "php-gd"    "libxml2"    "libffi8"    "libpcap0.8"    "cron"    "time"    "traceroute"    "graphviz"  )    log_command "apt-get update"  log_command "
DEBIAN_FRONTEND=noninteractive apt-get install -y ${deps[*]}"    log_success "Dependencies installed"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Install CheckMK package
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#install_checkmk_package() {  local package="$1"    log_info "Installing CheckMK package..."    
# Install the package using dpkg (may return non-zero even on success)  log_command "dpkg -i '$package'" || true    
# Fix any dependency issues  log_info "Fixing dependencies..."  if ! log_command "apt-get install -f -y"; then    log_error "Failed to fix dependencies"    return 1  fi    
# Verify omd command is available  if ! command -v omd &> /dev/null; then    log_error "omd command not found after installation"    log_info "Attempting to fix symlinks..."        
# Recreate symlink if needed    if [[ -d /omd/versions ]]; then      local version      version=$(find /omd/versions/ -maxdepth 1 -type d ! -name "versions" ! -name "default" -printf "%f\n" | head -1)      if [[ -n "$version" ]]; then        log_debug "Found version: $version"        ln -sf "/omd/versions/$version/bin/omd" /usr/bin/omd      fi    fi        
# Check again    if ! command -v omd &> /dev/null; then      log_error "Failed to fix omd command"      return 1    fi  fi    
# Ensure /omd/apache directory exists (needed for site enable)  if [[ ! -d /omd/apache ]]; then    log_debug "Creating /omd/apache directory"    mkdir -p /omd/apache    chmod 755 /omd/apache  fi    log_success "CheckMK package installed"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Create CheckMK site
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#create_checkmk_site() {  local site_name="${CHECKMK_SITE_NAME:-monitoring}"    log_info "Creating CheckMK site: $site_name"    
# Ensure /omd/sites directory exists  if [[ ! -d /omd/sites ]]; then    log_debug "Creating /omd/sites directory"    mkdir -p /omd/sites    chmod 755 /omd/sites  fi    
# Check if site already exists (safely handle empty directory)  if [[ -d "/omd/sites/$site_name" ]]; then    log_warning "Site '$site_name' already exists"        
# Enable site if disabled    if omd status "$site_name" 2>&1 | grep -q "This site is disabled"; then      log_info "Enabling existing site..."      omd enable "$site_name" || log_warning "Could not enable site"    fi        return 0  fi    
# Create site and capture the auto-generated password  local create_output  create_output=$(omd create "$site_name" 2>&1)  local exit_code=$?    
# Always show the output for debugging  log_debug "omd create output: $create_output"    if [[ $exit_code -ne 0 ]]; then    log_error "Failed to create site"    log_error "Output: $create_output"    return 1  fi    
# Extract auto-generated password from output  
# Output format: "Created new site monitoring with version 2.4.0p16.cre.  
#                 The site can be started with omd start monitoring.  
#                 The default GUI is available at http://...  
#                 The admin user for the web applications is cmkadmin with password: <PASSWORD>"  
CHECKMK_AUTO_PASSWORD=$(
echo "$create_output" | grep -oP 'password: \K\S+' || 
echo "")    if [[ -z "$CHECKMK_AUTO_PASSWORD" ]]; then    log_warning "Could not extract auto-generated password from output"    log_info "Full omd create output:"    log_info "$create_output"
else    
# SHOW PASSWORD IMMEDIATELY    
echo ""    
echo "=========================================="    
echo "  ÔÜá´©Å  CHECKMK ADMIN PASSWORD"    
echo "=========================================="    
echo "  Username: cmkadmin"    
echo "  Password: $CHECKMK_AUTO_PASSWORD"    
echo "=========================================="    
echo "  ÔÜá´©Å  SAVE THIS PASSWORD NOW!"    
echo "=========================================="    
echo ""        log_success "Auto-generated password captured successfully"        
# Save password to temporary file for summary display    
echo "$CHECKMK_AUTO_PASSWORD" > /tmp/checkmk_admin_password.txt    chmod 600 /tmp/checkmk_admin_password.txt        
# Synchronize password with CheckMK internal database    log_info "Synchronizing password with CheckMK database..."    
echo "$CHECKMK_AUTO_PASSWORD" | su - "$site_name" -c "cmk-passwd cmkadmin" 2>/dev/null || log_warning "Could not sync password with cmk-passwd"  fi    
# Enable the site (required before configuration)  log_info "Enabling site..."  if ! omd enable "$site_name" 2>&1; then    log_error "Failed to enable site"    return 1  fi    log_success "Site '$site_name' created and enabled"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Configure CheckMK site
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_checkmk_site() {  local site_name="${CHECKMK_SITE_NAME:-monitoring}"    log_info "Configuring CheckMK site..."    
# Keep auto-generated password - do not override with htpasswd  log_debug "Using auto-generated admin password from site creation"    
# Configure site settings  log_debug "Configuring site settings"    
# Set Apache to listen on localhost only (for reverse proxy)  omd config "$site_name" set APACHE_TCP_ADDR 127.0.0.1  omd config "$site_name" set APACHE_TCP_PORT "${CHECKMK_HTTP_PORT:-5000}"    
# Update Apache config after changing bind address  log_info "Updating Apache configuration..."  omd update-apache-config "$site_name" || log_warning "Failed to update Apache config"    
# Enable livestatus  omd config "$site_name" set LIVESTATUS_TCP on  omd config "$site_name" set LIVESTATUS_TCP_PORT 6557    
# Configure core  omd config "$site_name" set CORE cmc    
# Configure web server  omd config "$site_name" set AUTOSTART on    log_success "Site configured"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Configure Apache2 as Reverse Proxy
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_apache() {  log_info "Configuring Apache2 as reverse proxy..."    
# Install Apache2 if not present  if ! command -v apache2 &> /dev/null; then    log_info "Installing Apache2..."    log_command "apt-get update"    log_command "
DEBIAN_FRONTEND=noninteractive apt-get install -y apache2"  fi    
# Enable required modules  local modules=("proxy" "proxy_http" "rewrite" "headers" "ssl")    for mod in "${modules[@]}"; do    log_command "a2enmod $mod"  done    
# Create CheckMK virtual host configuration  log_info "Creating Apache virtual host for CheckMK..."    cat > /etc/apache2/sites-available/checkmk.conf <<'EOF'<VirtualHost *:80>    ServerName _default_        
# Redirect HTTP to HTTPS    RewriteEngine On    RewriteCond %{HTTPS} off    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [
R=301,L]</VirtualHost><VirtualHost *:443>    ServerName _default_        
# SSL Configuration (using self-signed certificate)    SSLEngine on    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key        
# Proxy to CheckMK on port 5000    ProxyPreserveHost On    ProxyPass / http://127.0.0.1:5000/    ProxyPassReverse / http://127.0.0.1:5000/        
# WebSocket support for CheckMK    RewriteEngine On    RewriteCond %{HTTP:Upgrade} websocket [NC]    RewriteCond %{HTTP:Connection} upgrade [NC]    RewriteRule ^/?(.*) "ws://127.0.0.1:5000/$1" [P,L]        
# Security headers    Header always set Strict-Transport-Security "max-age=31536000"    Header always set X-Frame-Options "SAMEORIGIN"    Header always set X-Content-Type-Options "nosniff"</VirtualHost>EOF    
# Enable CheckMK site and disable default  log_command "a2ensite checkmk.conf"  log_command "a2dissite 000-default.conf" || true    
# Restart Apache  log_command "systemctl restart apache2"  log_command "systemctl enable apache2"    log_success "Apache2 configured as reverse proxy (HTTP:80 -> HTTPS:443 -> CheckMK:5000)"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Start CheckMK site
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#start_checkmk_site() {  local site_name="${CHECKMK_SITE_NAME:-monitoring}"    log_info "Starting CheckMK site..."    if ! log_command "omd start '$site_name'"; then    log_error "Failed to start site"    return 1  fi    log_success "CheckMK site started"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Configure firewall for CheckMK
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_checkmk_firewall() {  local http_port="${CHECKMK_HTTP_PORT:-5000}"    log_info "Configuring firewall for CheckMK..."    
# Allow Apache HTTP and HTTPS (reverse proxy)  log_command "ufw allow 80/tcp comment 'HTTP (redirect to HTTPS)'"  log_command "ufw allow 443/tcp comment 'HTTPS CheckMK Web Interface'"    
# Allow CheckMK HTTP (internal only, accessed via Apache proxy)  log_command "ufw allow $http_port/tcp comment 'CheckMK Internal Port'"    
# Allow CheckMK agent  log_command "ufw allow 6556/tcp comment 'CheckMK Agent'"    
# Allow Livestatus  log_command "ufw allow 6557/tcp comment 'CheckMK Livestatus'"    log_success "Firewall configured (HTTP:80, HTTPS:443, CheckMK:$http_port, Agent:6556, Livestatus:6557)"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Install CheckMK agent locally
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#install_local_agent() {  local site_name="${CHECKMK_SITE_NAME:-monitoring}"    log_info "Installing CheckMK agent on local system..."    local agent_deb="/omd/sites/$site_name/share/check_mk/agents/check-mk-agent_*.deb"    if ls $agent_deb 1> /dev/null 2>&1; then    
# Use dpkg with force options to handle cleanup issues    if dpkg -i --force-all $agent_deb 2>&1 | tee -a "$LOG_FILE"; then      log_success "Local agent installed"
else      log_warning "Agent installation had errors but continuing..."    fi
else    log_warning "Agent package not found, skipping local agent installation"  fi}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Apply performance tuning
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#apply_performance_tuning() {  local site_name="${CHECKMK_SITE_NAME:-monitoring}"  local omd_root="/omd/sites/$site_name"    log_info "Applying performance tuning..."    
# Apache tuning  cat >> /etc/apache2/conf-available/checkmk-tuning.conf <<EOF
# CheckMK Performance TuningTimeout 300KeepAlive OnMaxKeepAliveRequests 100KeepAliveTimeout 5<IfModule mpm_prefork_module>    StartServers             10    MinSpareServers          5    MaxSpareServers         20    MaxRequestWorkers      150    MaxConnectionsPerChild   0</IfModule>EOF    a2enconf checkmk-tuning 2>/dev/null || true    
# Site-specific tuning  if [[ -f "$omd_root/etc/apache/apache.conf" ]]; then
    echo "
# Performance tuning" >> "$omd_root/etc/apache/apache.conf"  fi    log_success "Performance tuning applied"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Create backup script
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#create_backup_script() {  local site_name="${CHECKMK_SITE_NAME:-monitoring}"    log_info "Creating backup script..."    cat > /usr/local/bin/backup-checkmk.sh <<EOF
#!/bin/bash
# CheckMK Backup Scriptset -euo pipefail
BACKUP_DIR="/opt/backups/checkmk"
SITE_NAME="$site_name"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\${BACKUP_DIR}/\${SITE_NAME}_\${DATE}.tar.gz"mkdir -p "\$BACKUP_DIR"
echo "Creating backup: \$BACKUP_FILE"omd backup "\$SITE_NAME" "\$BACKUP_FILE"
# Keep only last 30 daysfind "\$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
echo "Backup completed: \$BACKUP_FILE"EOF    chmod +x /usr/local/bin/backup-checkmk.sh    
# Add to cron  (crontab -l 2>/dev/null || true; 
echo "0 2 * * * /usr/local/bin/backup-checkmk.sh >> /var/log/checkmk-backup.log 2>&1") | crontab -    log_success "Backup script created (runs daily at 2 AM)"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Display site information
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#display_installation_summary() {  local site_name="${CHECKMK_SITE_NAME:-monitoring}"  local http_port="${CHECKMK_HTTP_PORT:-5000}"  local admin_password="N/A"  local server_ip  server_ip=$(hostname -I | awk '{print $1}')    
# Try to read password from temporary file  if [[ -f /tmp/checkmk_admin_password.txt ]]; then
    admin_password=$(cat /tmp/checkmk_admin_password.txt)  fi
echo ""  
echo "=========================================="  
echo "CheckMK Installation Complete!"  
echo "=========================================="  
echo ""  
echo "  Site Name: $site_name"  
echo "  Web Interface (HTTPS): https://${server_ip}/${site_name}/"  
echo "  Web Interface (HTTP):  http://${server_ip}/${site_name}/ (redirects to HTTPS)"  
echo "  Internal Port:         http://${server_ip}:${http_port}/${site_name}/"  
echo "  Admin User: cmkadmin"    if [[ "$admin_password" == "N/A" ]]; then
    echo "  Admin Password: Could not capture auto-generated password"    
echo "  To set password manually, run:"    
echo "    su
do su - $site_name -c 'cmk-passwd cmkadmin'"
else    
echo "  Admin Password: $admin_password (AUTO-GENERATED)"    
echo ""    
echo "  ÔÜá´©Å  IMPORTANT: Save this password! The temp file will be deleted."  fi
echo ""  
echo "  Commands:"  
echo "    - omd status $site_name"  
echo "    - omd start/stop/restart $site_name"  
echo "    - omd config $site_name"  
echo ""  
echo "  Backup: /usr/local/bin/backup-checkmk.sh"  
echo "=========================================="  
echo ""}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
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
#main() {  log_info "Starting CheckMK server installation..."    
# Auto-detect latest version if URL not provided  local url="${CHECKMK_DEB_URL:-}"  if [[ -z "$url" ]]; then    log_info "No URL provided, auto-detecting latest version..."    url=$(get_latest_checkmk_url)  fi    if [[ -z "${CHECKMK_ADMIN_PASSWORD:-}" ]]; then    log_error "CHECKMK_ADMIN_PASSWORD not set in configuration"
    exit 1  fi    
# Execute installation steps  install_checkmk_dependencies    download_checkmk "$url"  install_checkmk_package "/tmp/check-mk-raw.deb"    create_checkmk_site  configure_checkmk_site  configure_apache  apply_performance_tuning  configure_checkmk_firewall    start_checkmk_site    
# Optional: install local agent  if [[ "${INSTALL_LOCAL_AGENT:-yes}" == "yes" ]]; then    install_local_agent  fi    create_backup_script    log_module_end "$MODULE_NAME" "success"    display_installation_summary}
# Run main functionmain "$@"

__CORRUPTED_TAIL__
