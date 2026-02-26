#!/bin/bash
# bootstrap.sh - Main CheckMK installation bootstrap
# Orchestrates the modular installation scripts

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="${SCRIPT_DIR}/scripts"

# Installation modules (in order)
MODULES=(
    "10-ssh"
    "15-ntp"
    "20-packages"
    "25-postfix"
    "30-firewall"
    "40-fail2ban"
    "50-certbot"
    "60-checkmk"
    "80-timeshift"
)

log_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Main
log_header "CheckMK Installation Bootstrap"

log_info "Starting modular installation..."
echo ""

for module in "${MODULES[@]}"; do
    script_file="${SCRIPTS_PATH}/${module}.sh"
    
    if [[ -f "$script_file" ]]; then
        log_header "Running module: ${module}"
        
        if bash "$script_file"; then
            log_success "Module ${module} completed"
        else
            log_error "Module ${module} failed"
            exit 1
        fi
    else
        log_info "Skipping ${module} (not found)"
    fi
done

log_header "Installation Complete"
log_success "CheckMK installation finished successfully"
echo ""
log_info "Access CheckMK at: http://$(hostname -I | awk '{print $1}')/monitoring"
log_info "Default credentials: cmkadmin / check_mk"
