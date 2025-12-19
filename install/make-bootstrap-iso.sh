#!/bin/bash
# make-bootstrap-iso.sh - Create bootable ISO with CheckMK installer
# Creates a Debian-based ISO that auto-runs the CheckMK installer

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ISO_OUTPUT="${1:-checkmk-installer.iso}"
DEBIAN_ISO="${DEBIAN_ISO:-debian-12.4.0-amd64-netinst.iso}"
DEBIAN_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/${DEBIAN_ISO}"
WORK_DIR="/tmp/checkmk-iso-build"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
DEPS=("genisoimage" "wget" "xorriso")
for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        log_error "Missing dependency: $dep"
        log_info "Install with: apt-get install genisoimage wget xorriso"
        exit 1
    fi
done

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Clean work directory
log_info "Preparing work directory..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{iso,custom}

# Download Debian if needed
if [[ ! -f "$DEBIAN_ISO" ]]; then
    log_info "Downloading Debian netinst ISO..."
    wget -O "$DEBIAN_ISO" "$DEBIAN_URL"
fi

# Extract ISO
log_info "Extracting ISO..."
mount -o loop "$DEBIAN_ISO" "$WORK_DIR/iso"
rsync -a "$WORK_DIR/iso/" "$WORK_DIR/custom/"
umount "$WORK_DIR/iso"

# Add bootstrap script
log_info "Adding bootstrap installer..."
mkdir -p "$WORK_DIR/custom/scripts"
cp "$(dirname "$0")/bootstrap-installer.sh" "$WORK_DIR/custom/scripts/"

# Create preseed for auto-install
cat > "$WORK_DIR/custom/preseed.cfg" <<'EOF'
d-i debian-installer/locale string en_US
d-i keyboard-configuration/xkb-keymap select us
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string checkmk-installer
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i passwd/root-password password installer
d-i passwd/root-password-again password installer
d-i clock-setup/utc boolean true
d-i time/zone string UTC
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
tasksel tasksel/first multiselect standard
d-i pkgsel/include string openssh-server git curl wget
d-i finish-install/reboot_in_progress note
d-i preseed/late_command string in-target /scripts/bootstrap-installer.sh
EOF

# Rebuild ISO
log_info "Creating new ISO..."
genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -o "$ISO_OUTPUT" "$WORK_DIR/custom"

# Make bootable
log_info "Making ISO bootable..."
isohybrid "$ISO_OUTPUT" 2>/dev/null || true

# Cleanup
rm -rf "$WORK_DIR"

log_success "ISO created: $ISO_OUTPUT"
log_info "Default root password: installer"
log_info "System will auto-run CheckMK installer after first boot"
