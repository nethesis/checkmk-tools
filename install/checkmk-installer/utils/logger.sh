#!/usr/bin/env bash
set -euo pipefail

LOG_FILE_DEFAULT="/var/log/checkmk-installer.log"
LOG_FILE="${LOG_FILE:-$LOG_FILE_DEFAULT}"

init_logging() {
	if ! (touch "$LOG_FILE" 2>/dev/null); then
		LOG_FILE="/tmp/checkmk-installer.log"
		touch "$LOG_FILE" 2>/dev/null || true
	fi
}

_log_line() {
	local level="$1"; shift
	local ts
	ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
	echo "[$ts][$level] $*" >>"$LOG_FILE" 2>/dev/null || true
}

log_debug() { _log_line "DEBUG" "$@"; }
log_info() { _log_line "INFO" "$@"; }
log_warning() { _log_line "WARN" "$@"; }
log_error() { _log_line "ERROR" "$@"; }

log_command() {
	local cmd="$*"
	log_info "RUN: $cmd"
	bash -lc "$cmd"
}

: <<'__CORRUPTED_TAIL__'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE_DEFAULT="/var/log/checkmk-installer.log"
LOG_FILE="${LOG_FILE:-$LOG_FILE_DEFAULT}"

init_logging() {
	if ! (touch "$LOG_FILE" 2>/dev/null); then
		LOG_FILE="/tmp/checkmk-installer.log"
		touch "$LOG_FILE" 2>/dev/null || true
	fi
}

_log_line() {
	local level="$1"; shift
	local ts
	ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
	echo "[$ts][$level] $*" >>"$LOG_FILE" 2>/dev/null || true
}

log_debug() { _log_line "DEBUG" "$@"; }
log_info() { _log_line "INFO" "$@"; }
log_warning() { _log_line "WARN" "$@"; }
log_error() { _log_line "ERROR" "$@"; }

log_command() {
	local cmd="$*"
	log_info "RUN: $cmd"
	bash -lc "$cmd"
}
#!/usr/bin/env bash

# logger.sh - Centralized logging system

# shellcheck source=colors.sh
[[ -z "${GREEN:-}" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

export LOG_DIR="${LOG_DIR:-/var/log/checkmk-installer}"
export LOG_FILE="${LOG_FILE:-${LOG_DIR}/installer.log}"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"
export LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}" # 10MB
export LOG_MAX_FILES="${LOG_MAX_FILES:-5}"

declare -A LOG_LEVELS=(
	[DEBUG]=0
	[INFO]=1
	[SUCCESS]=2
	[WARNING]=3
	[ERROR]=4
	[CRITICAL]=5
)

_log_filesize() {
	local file="$1"
	if command -v stat >/dev/null 2>&1; then
		stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0
	else
		echo 0
	fi
}

log_rotate() {
	[[ ! -f "$LOG_FILE" ]] && return 0
	local size
	size=$(_log_filesize "$LOG_FILE")
	[[ "$size" =~ ^[0-9]+$ ]] || size=0
	if (( size > LOG_MAX_SIZE )); then
		for i in $(seq $((LOG_MAX_FILES - 1)) -1 1); do
			[[ -f "${LOG_FILE}.$i" ]] && mv -f "${LOG_FILE}.$i" "${LOG_FILE}.$((i + 1))" || true
		done
		mv -f "$LOG_FILE" "${LOG_FILE}.1" || true
		: >"$LOG_FILE" || true
	fi
}

log_write() {
	local level="$1"; shift
	local message="$*"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	local current_level=${LOG_LEVELS[$LOG_LEVEL]:-1}
	local msg_level=${LOG_LEVELS[$level]:-1}
	[[ $msg_level -lt $current_level ]] && return 0

	log_rotate
	echo "[$timestamp] [$level] [PID:$$] $message" >>"$LOG_FILE" 2>/dev/null || true
}

init_logging() {
	if [[ ! -d "$LOG_DIR" ]]; then
		mkdir -p "$LOG_DIR" 2>/dev/null || {
			LOG_DIR="/tmp/checkmk-installer"
			mkdir -p "$LOG_DIR"
			LOG_FILE="${LOG_DIR}/installer.log"
		}
	fi
	: >"$LOG_FILE" 2>/dev/null || {
		LOG_DIR="/tmp/checkmk-installer"
		mkdir -p "$LOG_DIR"
		LOG_FILE="${LOG_DIR}/installer.log"
		: >"$LOG_FILE" || true
	}

	log_write "INFO" "=========================================="
	log_write "INFO" "Logging session started: $(date '+%Y-%m-%d %H:%M:%S')"
	log_write "INFO" "PID: $$"
	log_write "INFO" "User: $(whoami 2>/dev/null || echo unknown)"
	log_write "INFO" "Hostname: $(hostname 2>/dev/null || echo unknown)"
	log_write "INFO" "=========================================="
}

log_debug() {
	log_write "DEBUG" "$*"
	if [[ "${VERBOSE:-0}" == "1" ]]; then
		print_color "$GRAY" "DEBUG: $*"
	fi
	return 0
}

log_info() { log_write "INFO" "$*"; print_info "$*"; }
log_success() { log_write "SUCCESS" "$*"; print_success "$*"; }
log_warning() { log_write "WARNING" "$*"; print_warning "$*"; }
log_error() { log_write "ERROR" "$*"; print_error "$*"; }
log_critical() { log_write "CRITICAL" "$*"; print_error "CRITICAL: $*"; }

log_command() {
	local cmd="$*"
	log_write "DEBUG" "Executing: $cmd"
	set +e
	# shellcheck disable=SC2086
	eval "$cmd"
	local ret=$?
	set -e
	if [[ $ret -eq 0 ]]; then
		log_write "DEBUG" "Command succeeded: $cmd"
	else
		log_write "ERROR" "Command failed (exit code $ret): $cmd"
	fi
	return $ret
}

log_module_start() {
	local module="$1"
	log_write "INFO" "========== MODULE START: $module =========="
	print_header "$module"
}

log_module_end() {
	local module="$1"
	local status="${2:-success}"
	if [[ "$status" == "success" ]]; then
		log_write "INFO" "========== MODULE END: $module (SUCCESS) =========="
		log_success "Module $module completed successfully"
	else
		log_write "ERROR" "========== MODULE END: $module (FAILED) =========="
		log_error "Module $module failed"
	fi
}

log_tail() {
	local lines="${1:-50}"
	[[ -f "$LOG_FILE" ]] && tail -n "$lines" "$LOG_FILE"
}

log_errors() {
	[[ -f "$LOG_FILE" ]] && grep -E "\[ERROR\]|\[CRITICAL\]" "$LOG_FILE" || true
}

log_clear() {
	: >"$LOG_FILE" 2>/dev/null || true
	log_success "Log file cleared"
}

log_location() {
	echo "$LOG_FILE"
}
#!/bin/bash
/usr/bin/env bash
# logger.sh - Centralized logging system
# Source colors if not already loaded[[ -z "$GREEN" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
# Log configurationexport 
LOG_DIR="${LOG_DIR:-/var/log/checkmk-installer}"export 
LOG_FILE="${LOG_FILE:-${LOG_DIR}/installer.log}"export 
LOG_LEVEL="${LOG_LEVEL:-INFO}"export 
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}"  
# 10MBexport 
LOG_MAX_FILES="${LOG_MAX_FILES:-5}"
# Log levels (numeric for comparison)declare -A 
LOG_LEVELS=(  [DEBUG]=0  [INFO]=1  [SUCCESS]=2  [WARNING]=3  [ERROR]=4  [CRITICAL]=5)
# Initialize logginginit_logging() {  
# Create log directory  if [[ ! -d "$LOG_DIR" ]]; then    mkdir -p "$LOG_DIR" 2>/dev/null || {      
LOG_DIR="/tmp/checkmk-installer"      mkdir -p "$LOG_DIR"    }  fi    
# Create log file if not exists  touch "$LOG_FILE" 2>/dev/null || {    
LOG_FILE="/tmp/checkmk-installer/installer.log"    mkdir -p "$(dirname "$LOG_FILE")"    touch "$LOG_FILE"  }    
# Log session start  log_write "INFO" "=========================================="  log_write "INFO" "Logging session started: $(date '+%Y-%m-%d %H:%M:%S')"  log_write "INFO" "PID: $$"  log_write "INFO" "User: $(whoami)"  log_write "INFO" "Hostname: $(hostname)"  log_write "INFO" "=========================================="}
# Rotate log if neededlog_rotate() {  [[ ! -f "$LOG_FILE" ]] && return 0  local sizelocal sizesize=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || 
echo 0)    if [[ $size -gt $LOG_MAX_SIZE ]]; then    
# Rotate existing logs    for i in $(seq $((LOG_MAX_FILES - 1)) -1 1); do      [[ -f "${LOG_FILE}.$i" ]] && mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i + 1))"    done        
# Move current log to .1    mv "$LOG_FILE" "${LOG_FILE}.1"    touch "$LOG_FILE"        log_write "INFO" "Log rotated (size: ${size} bytes)"  fi}
# Write to log filelog_write() {  local level="$1"  shift  local message="$*"local timestamplocal timestamptimestamp=$(date '+%Y-%m-%d %H:%M:%S')    
# Check if we should log this level  local current_level=${LOG_LEVELS[$LOG_LEVEL]:-1}  local msg_level=${LOG_LEVELS[$level]:-1}    [[ $msg_level -lt $current_level ]] && return 0    
# Rotate if needed  log_rotate    
# Write to file  
echo "[$timestamp] [$level] [PID:$$] $message" >> "$LOG_FILE" 2>/dev/null || true}
# Log functionslog_debug() {  log_write "DEBUG" "$*"  if [[ "${VERBOSE:-0}" == "1" ]]; then    print_color "$GRAY" "­ƒöì DEBUG: $*"  fi  return 0}log_info() {  log_write "INFO" "$*"  print_info "$*"}log_success() {  log_write "SUCCESS" "$*"  print_success "$*"}log_warning() {  log_write "WARNING" "$*"  print_warning "$*"}log_error() {  log_write "ERROR" "$*"  print_error "$*"}log_critical() {  log_write "CRITICAL" "$*"  print_error "CRITICAL: $*"}
# Log command execution (fixed - no stdout redirection)log_command() {  local cmd="$*"  log_write "DEBUG" "Executing: $cmd"    
# Execute command normally without redirecting stdout  eval "$cmd"  local ret=$?    if [[ $ret -eq 0 ]]; then    log_write "DEBUG" "Command succeeded: $cmd"
else    log_write "ERROR" "Command failed (exit code $ret): $cmd"  fi    return $ret}
# Log module start/endlog_module_start() {  local module="$1"  log_write "INFO" "========== MODULE START: $module =========="  print_header "$module"}log_module_end() {  local module="$1"  local status="${2:-success}"    if [[ "$status" == "success" ]]; then    log_write "INFO" "========== MODULE END: $module (SUCCESS) =========="    log_success "Module $module completed successfully"
else    log_write "ERROR" "========== MODULE END: $module (FAILED) =========="    log_error "Module $module failed"  fi}
# Show last N lines of loglog_tail() {  local lines="${1:-50}"  [[ -f "$LOG_FILE" ]] && tail -n "$lines" "$LOG_FILE"}
# Show errors from loglog_errors() {  [[ -f "$LOG_FILE" ]] && grep -E "\[ERROR\]|\[CRITICAL\]" "$LOG_FILE"}
# Clear loglog_clear() {  if [[ -f "$LOG_FILE" ]]; then    true > "$LOG_FILE"    log_success "Log file cleared"  fi}
# Export log locationlog_location() {  
echo "$LOG_FILE"}

__CORRUPTED_TAIL__
