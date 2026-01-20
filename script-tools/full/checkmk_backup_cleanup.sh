#!/usr/bin/env bash
set -euo pipefail

# checkmk_backup_cleanup.sh
# Script for cleaning up old CheckMK backups
# Usage:
#   checkmk_backup_cleanup.sh setup     # Setup systemd timer for automatic cleanup
#   checkmk_backup_cleanup.sh run       # Run cleanup manually
#   checkmk_backup_cleanup.sh remove    # Remove systemd timer

SCRIPT_NAME="$(basename "$0")"
DEFAULT_BACKUP_DIR="/var/backups/checkmk"
DEFAULT_RETENTION_DAYS=30
LOGFILE="/var/log/checkmk-backup-cleanup.log"

log() { 
  local msg="[$(date '+%F %T')] $*"
  echo "$msg"
  echo "$msg" >> "$LOGFILE"
}

err() { 
  local msg="[$(date '+%F %T')] ERROR: $*"
  echo "$msg" >&2
  echo "$msg" >> "$LOGFILE"
}

die() { err "$*"; exit 1; }

need_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root."
}

prompt_default() {
  local prompt="$1" def="$2" out
  if [[ -n "${def}" ]]; then
    printf "%s [%s]: " "${prompt}" "${def}" >&2
  else
    printf "%s: " "${prompt}" >&2
  fi
  IFS= read -r out
  [[ -z "${out}" ]] && out="${def}"
  printf "%s" "${out}"
}

confirm_default_yes() {
  local prompt="$1" ans
  printf "%s [Y/n]: " "${prompt}" >&2
  IFS= read -r ans
  [[ -z "${ans}" || "${ans}" =~ ^[Yy]$ ]]
}

cleanup_backups() {
  local backup_dir="${1:-$DEFAULT_BACKUP_DIR}"
  local retention_days="${2:-$DEFAULT_RETENTION_DAYS}"
  
  log "Starting backup rename (local backup - no deletion)"
  log "Backup directory: $backup_dir"
  
  if [[ ! -d "$backup_dir" ]]; then
    err "Backup directory not found: $backup_dir"
    return 1
  fi
  
  # Count backups before processing
  local total_before
  total_before=$(find "$backup_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) 2>/dev/null | wc -l)
  log "Total backups: $total_before"
  
  # Rename only complete backups without timestamp
  log "Looking for completed backups to rename..."
  local renamed=0
  while IFS= read -r -d '' backup; do
    local backup_name
    backup_name="$(basename "$backup")"
    
    # Process only backups ending with -complete
    if [[ ! "$backup_name" =~ -complete$ ]]; then
      continue
    fi
    
    log "Found complete backup: $backup_name"
      continue
    fi
    
    # Check if backup is stable (not modified in last 2 minutes)
    local last_modified current_time age_seconds
    last_modified=$(stat -c %Y "$backup" 2>/dev/null || echo "0")
    current_time=$(date +%s)
    age_seconds=$((current_time - last_modified))
    
    if [[ $age_seconds -lt 120 ]]; then
      log "Backup too recent (${age_seconds}s old), skipping: $backup_name"
      continue
    fi
    
    # Check backup size (must be > 100KB to be valid)
    local backup_size
    if [[ -d "$backup" ]]; then
      backup_size=$(du -sb "$backup" 2>/dev/null | awk '{print $1}')
    else
      backup_size=$(stat -c %s "$backup" 2>/dev/null || echo "0")
    fi
    
    if [[ $backup_size -lt 102400 ]]; then
      log "Backup too small (${backup_size} bytes), skipping: $backup_name"
      continue
    fi
    
    # Check if backup already has timestamp pattern (YYYY-MM-DD-HHhMM)
    if [[ ! "$backup_name" =~ -[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}h[0-9]{2}$ ]]; then
      # Get modification time and create timestamp
      local mtime timestamp new_name new_path
      mtime=$(stat -c %Y "$backup" 2>/dev/null || echo "0")
      if [[ "$mtime" != "0" ]]; then
        timestamp=$(date -d "@${mtime}" '+%Y-%m-%d-%Hh%M' 2>/dev/null || date '+%Y-%m-%d-%Hh%M')
        new_name="${backup_name}-${timestamp}"
        new_path="${backup_dir}/${new_name}"
        
        log "Renaming: $backup_name -> $new_name (age: ${age_seconds}s, size: ${backup_size} bytes)"
        if mv "$backup" "$new_path"; then
          renamed=$((renamed + 1))
        else
          err "Failed to rename $backup"
        fi
      fi
    fi
  done < <(find "$backup_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) -name 'Check_MK-*-complete' -print0 2>/dev/null)
  
  # Count backups after processing
  local total_after
  total_after=$(find "$backup_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) 2>/dev/null | wc -l)
  
  log "Rename completed. Renamed: $renamed, Total backups: $total_after"
  
  # Show disk usage
  if command -v du >/dev/null 2>&1; then
    local disk_usage
    disk_usage=$(du -sh "$backup_dir" 2>/dev/null | awk '{print $1}')
    log "Current backup directory size: $disk_usage"
  fi
}

setup() {
  need_root
  
  log "Setting up automatic backup rename (local backups)"
  
  local backup_dir
  backup_dir="$(prompt_default "Backup directory" "$DEFAULT_BACKUP_DIR")"
  
  # Validate input
  if [[ ! -d "$backup_dir" ]]; then
    if confirm_default_yes "Directory $backup_dir does not exist. Create it?"; then
      mkdir -p "$backup_dir"
      log "Created directory: $backup_dir"
    else
      die "Backup directory does not exist: $backup_dir"
    fi
  fi
  
  # Create systemd service
  local service_file="/etc/systemd/system/checkmk-backup-cleanup.service"
  log "Creating systemd service: $service_file"
  
  cat > "$service_file" <<EOF
[Unit]
Description=CheckMK Backup Rename Service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash $(realpath "$0") run-internal "$backup_dir"
Nice=19
IOSchedulingClass=idle

[Install]
WantedBy=multi-user.target
EOF
  
  # Create systemd timer
  local timer_file="/etc/systemd/system/checkmk-backup-cleanup.timer"
  log "Creating systemd timer: $timer_file"
  
  cat > "$timer_file" <<EOF
[Unit]
Description=CheckMK Backup Rename Timer (Every Minute)

[Timer]
OnCalendar=*:0/1
Persistent=true

[Install]
WantedBy=timers.target
EOF
  
  # Reload and enable
  systemctl daemon-reload
  systemctl enable checkmk-backup-cleanup.timer
  systemctl start checkmk-backup-cleanup.timer
  
  log ""
  log "Setup completed!"
  log "Configuration:"
  log "  - Backup directory: $backup_dir"
  log "  - Mode: Rename complete backups only (no deletion)"
  log "  - Schedule: Every minute (checks for -complete suffix)"
  log ""
  log "Timer status:"
  systemctl status checkmk-backup-cleanup.timer --no-pager || true
  log ""
  log "Manual commands:"
  log "  Run rename now:         $SCRIPT_NAME run"
  log "  Check timer status:     systemctl status checkmk-backup-cleanup.timer"
  log "  Check service logs:     journalctl -u checkmk-backup-cleanup.service"
  log "  Remove cleanup:         $SCRIPT_NAME remove"
}

run() {
  need_root
  
  # Try to read config from systemd service if exists
  local backup_dir="$DEFAULT_BACKUP_DIR"
  
  local service_file="/etc/systemd/system/checkmk-backup-cleanup.service"
  if [[ -f "$service_file" ]]; then
    # Extract parameters from ExecStart line
    local exec_line
    exec_line=$(grep "^ExecStart=" "$service_file" || true)
    if [[ -n "$exec_line" ]]; then
      # Parse: ExecStart=/bin/bash /path/script run-internal <dir>
      backup_dir=$(echo "$exec_line" | awk '{print $4}' || echo "$DEFAULT_BACKUP_DIR")
    fi
  else
    log "No systemd service found. Using defaults or run 'setup' first."
    backup_dir="$(prompt_default "Backup directory" "$DEFAULT_BACKUP_DIR")"
  fi
  
  cleanup_backups "$backup_dir"
}

run_internal() {
  # Called by systemd service with parameters
  local backup_dir="${1:-$DEFAULT_BACKUP_DIR}"
  cleanup_backups "$backup_dir"
}

remove() {
  need_root
  
  log "Removing automatic backup cleanup"
  
  local timer_file="/etc/systemd/system/checkmk-backup-cleanup.timer"
  local service_file="/etc/systemd/system/checkmk-backup-cleanup.service"
  
  if [[ -f "$timer_file" ]] || [[ -f "$service_file" ]]; then
    systemctl stop checkmk-backup-cleanup.timer 2>/dev/null || true
    systemctl disable checkmk-backup-cleanup.timer 2>/dev/null || true
    
    rm -f "$timer_file" "$service_file"
    systemctl daemon-reload
    
    log "Cleanup timer and service removed."
  else
    log "No cleanup timer/service found."
  fi
  
  log "Remove completed."
}

usage() {
  cat <<EOF
CheckMK Backup Cleanup Tool

Usage:
  $SCRIPT_NAME setup     # Setup automatic daily cleanup
  $SCRIPT_NAME run       # Run cleanup manually
  $SCRIPT_NAME remove    # Remove automatic cleanup

Configuration:
  Default backup directory: $DEFAULT_BACKUP_DIR
  Default retention: $DEFAULT_RETENTION_DAYS days
  Log file: $LOGFILE

Examples:
  # Setup automatic cleanup with defaults
  $SCRIPT_NAME setup

  # Run cleanup manually
  $SCRIPT_NAME run

  # Remove automatic cleanup
  $SCRIPT_NAME remove
EOF
}

main() {
  case "${1:-}" in
    setup)
      setup
      ;;
    run)
      run
      ;;
    run-internal)
      shift
      run_internal "$@"
      ;;
    remove)
      remove
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
