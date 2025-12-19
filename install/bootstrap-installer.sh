#!/usr/bin/env bash
# bootstrap-installer.sh - Bootstrap and launch CheckMK installer
# This script clones/updates the repository and launches the installer

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_URL="${REPO_URL:-https://github.com/Coverup20/checkmk-tools.git}"
REPO_DIR="${REPO_DIR:-/opt/checkmk-tools}"
INSTALLER_PATH="${REPO_DIR}/install/checkmk-installer/installer.sh"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Install git if needed
if ! command -v git &>/dev/null; then
    log_info "Installing git..."
    if command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y git
    elif command -v yum &>/dev/null; then
        yum install -y git
    else
        log_error "Cannot install git - unsupported package manager"
        exit 1
    fi
fi

# Clone or update repository
if [[ -d "$REPO_DIR/.git" ]]; then
    log_info "Updating repository..."
    cd "$REPO_DIR"
    git fetch origin
    git reset --hard origin/main
    log_success "Repository updated"
else
    log_info "Cloning repository..."
    git clone "$REPO_URL" "$REPO_DIR"
    log_success "Repository cloned"
fi

# Check installer exists
if [[ ! -f "$INSTALLER_PATH" ]]; then
    log_error "Installer not found at $INSTALLER_PATH"
    exit 1
fi

# Make installer executable
chmod +x "$INSTALLER_PATH"

# Launch installer
log_info "Launching CheckMK installer..."
exec "$INSTALLER_PATH" "$@"
