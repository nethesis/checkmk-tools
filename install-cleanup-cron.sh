#!/usr/bin/env bash
set -euo pipefail

# install-cleanup-cron.sh
# Interactive installer for cleanup-checkmk-retention.sh cron job

SCRIPT_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/cleanup-checkmk-retention.sh"
LOG_FILE="/var/log/cleanup-checkmk-retention.log"
CRON_TIME="0 3 * * *"  # Default: 03:00 every day

log() { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
die() { err "$*"; exit 1; }

# Check root
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "This script must be run as root. Use: sudo $0"
fi

# Banner
clear
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║      CLEANUP CHECKMK RETENTION - CRON INSTALLER              ║
║                                                              ║
║  Automated cleanup for CheckMK data retention:              ║
║  • RRD files: 180 days                                       ║
║  • Nagios archives: 180 days (compressed after 30 days)     ║
║  • Notify backups: 30 days (compressed after 1 day)         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF

log "Script URL: $SCRIPT_URL"
log "Log file: $LOG_FILE"
echo ""

# Check if curl is available
if ! command -v curl >/dev/null 2>&1; then
  die "curl is not installed. Please install it first: apt install curl"
fi

# Test script accessibility
log "Testing script accessibility from GitHub..."
if ! curl -fsSL --connect-timeout 5 "$SCRIPT_URL" >/dev/null 2>&1; then
  die "Cannot access script from GitHub. Check your internet connection or URL."
fi
success "Script is accessible from GitHub"

# Check if cron job already exists
CRON_PATTERN="cleanup-checkmk-retention.sh"
if crontab -l 2>/dev/null | grep -q "$CRON_PATTERN"; then
  warn "Cron job already exists!"
  echo ""
  echo "Current cron configuration:"
  echo "─────────────────────────────────────────────────────────────"
  crontab -l 2>/dev/null | grep "$CRON_PATTERN"
  echo "─────────────────────────────────────────────────────────────"
  echo ""
  
  read -p "Do you want to REPLACE it? [y/N]: " -r < /dev/tty
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Installation cancelled."
    exit 0
  fi
  
  # Remove existing cron
  log "Removing existing cron job..."
  crontab -l 2>/dev/null | grep -v "$CRON_PATTERN" | crontab - || true
  success "Existing cron job removed"
fi

# Ask for schedule
echo ""
log "Configure execution schedule"
echo ""
echo "Default schedule: 03:00 AM every day (0 3 * * *)"
echo ""
echo "Common schedules:"
echo "  1) 03:00 AM daily (recommended)"
echo "  2) 02:00 AM daily"
echo "  3) 04:00 AM daily"
echo "  4) Custom time"
echo ""

read -p "Select schedule [1-4, default: 1]: " schedule_choice < /dev/tty

case "${schedule_choice:-1}" in
  1)
    CRON_TIME="0 3 * * *"
    CRON_DESC="03:00 AM daily"
    ;;
  2)
    CRON_TIME="0 2 * * *"
    CRON_DESC="02:00 AM daily"
    ;;
  3)
    CRON_TIME="0 4 * * *"
    CRON_DESC="04:00 AM daily"
    ;;
  4)
    echo ""
    echo "Enter cron schedule (format: MIN HOUR DAY MONTH WEEKDAY)"
    echo "Examples:"
    echo "  0 3 * * *     = 03:00 every day"
    echo "  30 2 * * *    = 02:30 every day"
    echo "  0 3 * * 0     = 03:00 every Sunday"
    echo ""
    read -p "Custom schedule: " CRON_TIME < /dev/tty
    CRON_DESC="custom: $CRON_TIME"
    
    # Validate cron syntax (basic)
    if [[ ! "$CRON_TIME" =~ ^[0-9*,/-]+[[:space:]][0-9*,/-]+[[:space:]][0-9*,/-]+[[:space:]][0-9*,/-]+[[:space:]][0-9*,/-]+$ ]]; then
      die "Invalid cron syntax. Please use format: MIN HOUR DAY MONTH WEEKDAY"
    fi
    ;;
  *)
    CRON_TIME="0 3 * * *"
    CRON_DESC="03:00 AM daily (default)"
    ;;
esac

# Build cron command
CRON_CMD="$CRON_TIME curl -fsSL $SCRIPT_URL | bash >> $LOG_FILE 2>&1"

# Show summary and confirm
echo ""
log "Installation summary:"
echo "─────────────────────────────────────────────────────────────"
echo "Schedule:    $CRON_DESC"
echo "Command:     curl -fsSL $SCRIPT_URL | bash"
echo "Log file:    $LOG_FILE"
echo "Cron entry:  $CRON_CMD"
echo "─────────────────────────────────────────────────────────────"
echo ""

read -p "Proceed with installation? [y/N]: " -r < /dev/tty
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  log "Installation cancelled."
  exit 0
fi

# Install cron job
log "Installing cron job..."

# Get current crontab, add new job
(crontab -l 2>/dev/null || true; echo "$CRON_CMD") | crontab -

success "Cron job installed successfully!"

# Verify installation
echo ""
log "Verifying installation..."
if crontab -l 2>/dev/null | grep -q "$CRON_PATTERN"; then
  success "Cron job verified in crontab"
  echo ""
  echo "Current cron configuration:"
  echo "─────────────────────────────────────────────────────────────"
  crontab -l 2>/dev/null | grep "$CRON_PATTERN"
  echo "─────────────────────────────────────────────────────────────"
else
  die "Cron job installation failed!"
fi

# Ask for test run
echo ""
read -p "Do you want to run the cleanup script now (test)? [y/N]: " -r < /dev/tty
if [[ $REPLY =~ ^[Yy]$ ]]; then
  log "Running cleanup script in dry-run mode..."
  echo ""
  echo "════════════════════════════════════════════════════════════"
  curl -fsSL "$SCRIPT_URL" | bash -s -- --dry-run
  echo "════════════════════════════════════════════════════════════"
  echo ""
  
  read -p "Run REAL cleanup now (not dry-run)? [y/N]: " -r < /dev/tty
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Running REAL cleanup..."
    echo ""
    echo "════════════════════════════════════════════════════════════"
    curl -fsSL "$SCRIPT_URL" | bash | tee -a "$LOG_FILE"
    echo "════════════════════════════════════════════════════════════"
  fi
fi

# Final instructions
echo ""
success "Installation complete!"
echo ""
log "Next automatic execution: $CRON_DESC"
echo ""
echo "Useful commands:"
echo "  • View cron jobs:        crontab -l"
echo "  • Remove cron job:       crontab -e (delete the line)"
echo "  • View logs:             tail -f $LOG_FILE"
echo "  • Manual execution:      curl -fsSL $SCRIPT_URL | bash"
echo "  • Manual dry-run:        curl -fsSL $SCRIPT_URL | bash -s -- --dry-run"
echo ""
