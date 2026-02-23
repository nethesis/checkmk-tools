#!/usr/bin/env bash
set -euo pipefail

UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${UTILS_DIR}/menu.sh"

has_cmd() { command -v "$1" >/dev/null 2>&1; }

validate_port() {
	local port="$1"
	[[ "$port" =~ ^[0-9]+$ ]] || return 1
	(( port >= 1 && port <= 65535 ))
}

validate_email() {
	local email="$1"
	[[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

validate_url() {
	local url="$1"
	[[ "$url" =~ ^https?://[^[:space:]]+$ ]] || return 1
	[[ "$url" =~ [[:cntrl:]] ]] && return 1
	return 0
}

input_port() {
	local prompt="$1" default="$2" port
	while true; do
		port=$(input_text "$prompt" "$default")
		validate_port "$port" && { echo "$port"; return 0; }
		echo "Invalid port (1-65535)"
	done
}

input_email() {
	local prompt="$1" default="$2" email
	while true; do
		email=$(input_text "$prompt" "$default")
		validate_email "$email" && { echo "$email"; return 0; }
		echo "Invalid email"
	done
}

input_url() {
	local prompt="$1" default="$2" url
	while true; do
		url=$(input_text "$prompt" "$default")
		url="$(printf '%s' "$url" | tr -d '\r')"
		[[ -z "$url" ]] && { echo ""; return 0; }
		validate_url "$url" && { echo "$url"; return 0; }
		echo "Invalid URL (must start with http:// or https://)"
	done
}

validate_system_requirements() {
	local ok=0

	if [[ "$(uname -s 2>/dev/null || echo '')" != "Linux" ]]; then
		print_warning "Non-Linux environment detected; installer expects Linux"
		ok=1
	fi

	for cmd in bash curl wget systemctl apt-get; do
		if ! has_cmd "$cmd"; then
			print_warning "Missing command: $cmd"
			ok=1
		fi
	done

	return $ok
}

# shellcheck disable=SC2317
: <<'__CORRUPTED_TAIL__'
#!/usr/bin/env bash
set -euo pipefail

has_cmd() { command -v "$1" >/dev/null 2>&1; }

validate_system_requirements() {
	local ok=0

	if [[ "$(uname -s 2>/dev/null || echo '')" != "Linux" ]]; then
		print_warning "Non-Linux environment detected; installer expects Linux"
		ok=1
	fi

	for cmd in bash curl wget systemctl apt-get; do
		if ! has_cmd "$cmd"; then
			print_warning "Missing command: $cmd"
			ok=1
		fi
	done

	return $ok
}
#!/usr/bin/env bash

# validate.sh - Input validation and basic system checks

UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=colors.sh
source "${UTILS_DIR}/colors.sh"
# shellcheck source=menu.sh
source "${UTILS_DIR}/menu.sh" 2>/dev/null || true

validate_ip() {
	local ip="$1"
	[[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
	local IFS='.'
	local -a octets
	read -r -a octets <<<"$ip"
	local octet
	for octet in "${octets[@]}"; do
		[[ "$octet" =~ ^[0-9]+$ ]] || return 1
		(( octet >= 0 && octet <= 255 )) || return 1
	done
	return 0
}

validate_port() {
	local port="$1"
	[[ "$port" =~ ^[0-9]+$ ]] || return 1
	(( port >= 1 && port <= 65535 ))
}

validate_email() {
	local email="$1"
	[[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

validate_hostname() {
	local hostname="$1"
	[[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

validate_url() {
	local url="$1"
	[[ "$url" =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]
}

validate_domain() {
	local domain="$1"
	[[ "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]
}

validate_path_exists() { [[ -e "$1" ]]; }
validate_dir_exists() { [[ -d "$1" ]]; }
validate_file_exists() { [[ -f "$1" ]]; }
validate_not_empty() { [[ -n "$1" ]]; }
validate_number() { [[ "$1" =~ ^[0-9]+$ ]]; }

validate_number_range() {
	local num="$1" min="$2" max="$3"
	validate_number "$num" || return 1
	(( num >= min && num <= max ))
}

validate_disk_space() {
	local path="$1" required_mb="$2"
	command -v df >/dev/null 2>&1 || return 0
	local available_mb
	available_mb=$(df -Pm "$path" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d ' ') || return 0
	validate_number "$available_mb" || return 0
	(( available_mb >= required_mb ))
}

validate_system_requirements() {
	local errors=0
	print_info "Checking system requirements..."

	if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
		print_error "This script must be run as root"
		((errors++))
	else
		print_success "Root privileges: OK"
	fi

	if validate_disk_space "/" 5000; then
		print_success "Disk space: OK"
	else
		print_warning "Disk space: low (recommended >= 5GB free)"
	fi

	if command -v free >/dev/null 2>&1; then
		local mem_mb
		mem_mb=$(free -m | awk 'NR==2 {print $2}')
		if validate_number "$mem_mb" && (( mem_mb >= 2000 )); then
			print_success "Memory: OK (${mem_mb}MB)"
		else
			print_warning "Memory: low (${mem_mb:-unknown}MB, recommended >= 2GB)"
		fi
	fi


	if command -v ping >/dev/null 2>&1; then
		if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
			print_success "Internet connectivity: OK"
		else
			print_warning "Internet connectivity: not available (offline mode)"
		fi
	fi

	local required_commands=(curl wget jq systemctl apt-get)
	local cmd
	for cmd in "${required_commands[@]}"; do
		if command -v "$cmd" >/dev/null 2>&1; then
			print_success "Command '$cmd': OK"
		else
			print_warning "Command '$cmd': not found (may be installed by modules)"
		fi
	done

	return $errors
}

# Input helpers (optional)
input_ip() {
	local prompt="$1" default="$2" ip
	while true; do
		ip=$(input_text "$prompt" "$default")
		validate_ip "$ip" && { echo "$ip"; return 0; }
		print_error "Invalid IP address"
	done
}

input_port() {
	local prompt="$1" default="$2" port
	while true; do
		port=$(input_text "$prompt" "$default")
		validate_port "$port" && { echo "$port"; return 0; }
		print_error "Invalid port (1-65535)"
	done
}

input_email() {
	local prompt="$1" default="$2" email
	while true; do
		email=$(input_text "$prompt" "$default")
		validate_email "$email" && { echo "$email"; return 0; }
		print_error "Invalid email"
	done
}

input_url() {
	local prompt="$1" default="$2" url
	while true; do
		url=$(input_text "$prompt" "$default")
		validate_url "$url" && { echo "$url"; return 0; }
		print_error "Invalid URL (must start with http:// or https://)"
	done
}

input_hostname() {
	local prompt="$1" default="$2" host
	while true; do
		host=$(input_text "$prompt" "$default")
		validate_hostname "$host" && { echo "$host"; return 0; }
		print_error "Invalid hostname"
	done
}
#!/bin/bash
/usr/bin/env bash
# validate.sh - Input validation functions
# Source dependencies
UTILS_DIR="$(dirname "${BASH_SOURCE[0]}")"source "${UTILS_DIR}/colors.sh"
# Validate IP addressvalidate_ip() {  local ip="$1"    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then    local 
IFS='.'    local -a octets=($ip)    for octet in "${octets[@]}"; do      [[ $octet -gt 255 ]] && return 1    done    return 0  fi    return 1}
# Validate port numbervalidate_port() {  local port="$1"    if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then    return 0  fi    return 1}
# Validate email addressvalidate_email() {  local email="$1"    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then    return 0  fi    return 1}
# Validate hostnamevalidate_hostname() {  local hostname="$1"    if [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then    return 0  fi    return 1}
# Validate URLvalidate_url() {  local url="$1"    if [[ "$url" =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$ ]]; then    return 0  fi    return 1}
# Validate domainvalidate_domain() {  local domain="$1"    if [[ "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then    return 0  fi    return 1}
# Validate path existsvalidate_path_exists() {  local path="$1"  [[ -e "$path" ]]}
# Validate directory existsvalidate_dir_exists() {  local dir="$1"  [[ -d "$dir" ]]}
# Validate file existsvalidate_file_exists() {  local file="$1"  [[ -f "$file" ]]}
# Validate not emptyvalidate_not_empty() {  local value="$1"  [[ -n "$value" ]]}
# Validate numbervalidate_number() {  local num="$1"  [[ "$num" =~ ^[0-9]+$ ]]}
# Validate number in rangevalidate_number_range() {  local num="$1"  local min="$2"  local max="$3"    if validate_number "$num"; then    [[ $num -ge $min ]] && [[ $num -le $max ]]  else    return 1  fi}
# Validate password strengthvalidate_password() {  local password="$1"  local min_length="${2:-8}"    
# Check minimum length  [[ ${
#password} -ge $min_length ]] || return 1    
# Check for at least one letter  [[ "$password" =~ [a-zA-Z] ]] || return 1    
# Check for at least one number  [[ "$password" =~ [0-9] ]] || return 1    return 0}
# Validate usernamevalidate_username() {  local username="$1"    
# Must start with letter, contain only alphanumeric and underscore  if [[ "$username" =~ ^[a-z][a-z0-9_-]{2,31}$ ]]; then    return 0  fi    return 1}
# Validate disk space available (in MB)validate_disk_space() {  local path="$1"  local required_mb="$2"  local available_mblocal available_mbavailable_mb=$(df -BM "$path" | awk '
NR==2 {print $4}' | sed 's/M//')    [[ $available_mb -ge $required_mb ]]}
# Validate system requirementsvalidate_system_requirements() {  local errors=0    print_info "Verifica requisiti sistema..."    
# Check if running as root  if [[ $EUID -ne 0 ]]; then    print_error "Questo script deve essere eseguito come root"    ((errors++))  else    print_success "Permessi root: OK"  fi    
# Check disk space (at least 5GB)  if validate_disk_space "/" 5000; then    print_success "Spazio disco: OK"
else    print_error "Spazio disco insufficiente (minimo 5GB richiesti)"    ((errors++))  fi    
# Check memory (at least 2GB)local mem_mblocal mem_mbmem_mb=$(free -m | awk '
NR==2 {print $2}')  if [[ $mem_mb -ge 2000 ]]; then    print_success "Memoria RAM: OK (${mem_mb}MB)"
else    print_warning "Memoria RAM bassa (${mem_mb}MB, consigliati almeno 2GB)"  fi    
# Check internet connection (optional)  if ping -c 1 8.8.8.8 &>/dev/null; then    print_success "Connessione internet: OK"
else    print_warning "Connessione internet non disponibile (modalit├á offline)"  fi    
# Check required commands  local required_commands=("curl" "wget" "jq" "systemctl" "apt-get")  for cmd in "${required_commands[@]}"; do    if command -v "$cmd" &>/dev/null; then      print_success "Coman
do '$cmd': OK"
else      print_warning "Coman
do '$cmd': NON TROVATO (verr├á installato)"    fi  done    return $errors}
# Input validation wrappersinput_ip() {  local prompt="$1"  local default="$2"    while true; dolocal iplocal ipip=$(input_text "$prompt" "$default")    if validate_ip "$ip"; then
    echo "$ip"      return 0    else      print_error "Indirizzo IP non vali
do"    fi  done}input_port() {  local prompt="$1"  local default="$2"    while true; dolocal portlocal portport=$(input_text "$prompt" "$default" "^[0-9]+$")    if validate_port "$port"; then
    echo "$port"      return 0    else      print_error "Porta non valida (1-65535)"    fi  done}input_email() {  local prompt="$1"  local default="$2"    while true; dolocal emaillocal emailemail=$(input_text "$prompt" "$default")    if validate_email "$email"; then
    echo "$email"      return 0    else      print_error "Email non valida"    fi  done}input_url() {  local prompt="$1"  local default="$2"    while true; dolocal urllocal urlurl=$(input_text "$prompt" "$default")    if validate_url "$url"; then
    echo "$url"      return 0    else      print_error "URL non vali
do (deve iniziare con http:// o https://)"    fi  done}input_hostname() {  local prompt="$1"  local default="$2"    while true; dolocal hostnamelocal hostnamehostname=$(input_text "$prompt" "$default")    if validate_hostname "$hostname"; then
    echo "$hostname"      return 0    else      print_error "Hostname non vali
do"    fi  done}

__CORRUPTED_TAIL__
