#!/bin/bash
# /usr/bin/env bash
# make-iso.sh - Create bootable ISO with CheckMK installer
# Generates a custom Ubuntu 24.04 ISO with the installer pre-loaded

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "${SCRIPT_DIR}/utils/colors.sh"
source "${SCRIPT_DIR}/utils/logger.sh"

# Simple display_box function for ISO builder
display_box() {
  local title="$1"
  shift
  echo ""
  echo "============================================================"
  echo "  $title"
  echo "============================================================"
  for line in "$@"; do
    echo "  $line"
  done
  echo "============================================================"
  echo ""
}

# Configuration
ISO_NAME="checkmk-installer-v1.0-amd64.iso"
ISO_OUTPUT_DIR="${SCRIPT_DIR}/iso-output"
WORK_DIR="/tmp/checkmk-iso-build"
UBUNTU_VERSION="24.04.3"
UBUNTU_ISO_URL="https://releases.ubuntu.com/noble/ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
UBUNTU_ISO_NAME="ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"

init_logging
print_header "CheckMK Installer ISO Builder"

# ================================================================
# Dependency Checking
# ================================================================

check_dependencies() {
  log_info "Checking dependencies..."
  
  local deps=("wget" "xorriso" "mksquashfs" "genisoimage" "7z")
  local missing=()
  
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done
  
  # Check for isolinux files
  if [[ ! -f "/usr/lib/ISOLINUX/isolinux.bin" ]] && [[ ! -f "/usr/lib/isolinux/isolinux.bin" ]]; then
    missing+=("isolinux")
  fi
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing dependencies: ${missing[*]}"
    log_info "Install with: sudo apt-get install xorriso isolinux squashfs-tools genisoimage wget"
    return 1
  fi
  
  log_success "All dependencies installed"
}

# ================================================================
# Download Ubuntu ISO
# ================================================================

download_ubuntu_iso() {
  local iso_cache="${SCRIPT_DIR}/${UBUNTU_ISO_NAME}"
  
  if [[ -f "$iso_cache" ]]; then
    log_info "Using cached Ubuntu ISO" >&2
    echo "$iso_cache"
    return 0
  fi
  
  log_info "Downloading Ubuntu ${UBUNTU_VERSION} ISO..." >&2
  log_warning "This may take several minutes (~2.5GB download)" >&2
  
  if ! wget --progress=bar:force -O "$iso_cache" "$UBUNTU_ISO_URL" 2>&1 | \
       stdbuf -o0 tr '\r' '\n' | \
       grep --line-buffered -oP '\d+%' | \
       while read -r percent; do
         echo -ne "\r${CYAN}Progress: ${WHITE}${percent}${NC} " >&2
       done; then
    echo "" >&2
    log_error "Failed to download Ubuntu ISO" >&2
    return 1
  fi
  
  echo "" >&2
  log_success "Ubuntu ISO downloaded" >&2
  echo "$iso_cache"
}

# ================================================================
# Extract Ubuntu ISO
# ================================================================

extract_iso() {
  local iso_file="$1"
  local extract_dir="$2"
  
  log_info "Extracting Ubuntu ISO..."
  
  mkdir -p "$extract_dir"
  
  # Extract using 7z (compatible with Kali Linux)
  log_info "Extracting ISO contents with 7z..."
  cd "$extract_dir"
  
  # Show spinner during extraction
  7z x -y "$iso_file" > "$LOG_FILE" 2>&1 &
  local pid=$!
  
  local spin='-\|/'
  local i=0
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) %4 ))
    echo -ne "\r${CYAN}Extracting... ${spin:$i:1}${NC} "
    sleep 0.1
  done
  wait $pid
  local exit_code=$?
  echo -ne "\r${CYAN}Extracting... Done!${NC}\n"
  
  cd - > /dev/null
  
  if [ $exit_code -ne 0 ]; then
    log_error "Failed to extract ISO"
    return 1
  fi
  
  # Make files writable
  chmod -R u+w "$extract_dir"
  
  log_success "ISO extracted"
}

# ================================================================
# Add complete installer to ISO
# ================================================================

add_scripts_to_iso() {
  local iso_root="$1"
  
  log_info "Adding CheckMK installer to ISO..."
  
  # Create checkmk-installer directory
  local installer_dir="${iso_root}/checkmk-installer"
  mkdir -p "$installer_dir"
  
  # Copy entire checkmk-installer directory structure
  local source_dir="${SCRIPT_DIR}"
  
  log_info "Copying installer scripts..."
  
  # Copy all necessary directories and files
  for dir in scripts utils modules; do
    if [[ -d "${source_dir}/${dir}" ]]; then
      cp -r "${source_dir}/${dir}" "$installer_dir/"
      log_debug "Copied ${dir}/"
    fi
  done
  
  # Copy main installer files
  for file in installer.sh README.md LICENSE; do
    if [[ -f "${source_dir}/${file}" ]]; then
      cp "${source_dir}/${file}" "$installer_dir/"
      log_debug "Copied ${file}"
    fi
  done
  
  # Copy bootstrap script if available
  local bootstrap_source="${SCRIPT_DIR}/../bootstrap-installer.sh"
  if [[ -f "$bootstrap_source" ]]; then
    cp "$bootstrap_source" "${installer_dir}/bootstrap-installer.sh"
    chmod +x "${installer_dir}/bootstrap-installer.sh"
    log_debug "Copied bootstrap-installer.sh"
  fi
  
  # Make all .sh files executable
  log_info "Setting execute permissions..."
  find "$installer_dir" -type f -name "*.sh" -exec chmod +x {} \;
  
  # Create convenience launcher
  cat > "${installer_dir}/install.sh" <<'EOF'
#!/bin/bash
# Quick install launcher
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try installer.sh first, fallback to bootstrap
if [[ -f "${SCRIPT_DIR}/installer.sh" ]]; then
  exec bash "${SCRIPT_DIR}/installer.sh" "$@"
elif [[ -f "${SCRIPT_DIR}/bootstrap-installer.sh" ]]; then
  exec bash "${SCRIPT_DIR}/bootstrap-installer.sh" "$@"
else
  echo "ERROR: No installer found!"
  exit 1
fi
EOF
  
  chmod +x "${installer_dir}/install.sh"
  
  # Create README
  cat > "${installer_dir}/README.txt" <<'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║        CheckMK Installer - Complete Edition             ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

This is a complete offline installer with all CheckMK
installation tools pre-loaded.

QUICK START:
------------
After booting from this ISO, open a terminal and run:

  sudo bash /cdrom/checkmk-installer/install.sh

Or the full installer:

  sudo bash /cdrom/checkmk-installer/installer.sh

WHAT IT DOES:
-------------
1. Interactive guided installation
2. CheckMK server setup
3. Agent deployment
4. Monitoring configuration

FEATURES:
---------
- Offline installation (no internet required)
- All scripts included
- Latest stable version
- Production-ready configuration

REQUIREMENTS:
-------------
- Root privileges
- Supported OS: Ubuntu 22.04+, Debian 11+, NethServer 7/8

REPOSITORY:
-----------
https://github.com/Coverup20/checkmk-tools

ADVANTAGES:
-----------
- Complete offline installer
- No dependencies to download
- Faster installation
- Fixed version (tested)

DISADVANTAGES:
--------------
- Larger ISO size
- May have outdated scripts

For always-latest version with smaller size,
use the online ISO instead.
EOF
  
  log_success "Installer scripts added to ISO"
}

# ================================================================
# Setup hybrid boot (isolinux for USB)
# ================================================================

setup_hybrid_boot() {
  local iso_root="$1"
  
  log_info "Setting up hybrid boot support..."
  
  # Create isolinux directory if doesn't exist
  local isolinux_dir="${iso_root}/isolinux"
  mkdir -p "$isolinux_dir"
  
  # Copy isolinux files
  if [[ -f "/usr/lib/ISOLINUX/isolinux.bin" ]]; then
    cp /usr/lib/ISOLINUX/isolinux.bin "$isolinux_dir/"
  elif [[ -f "/usr/lib/syslinux/modules/bios/isolinux.bin" ]]; then
    cp /usr/lib/syslinux/modules/bios/isolinux.bin "$isolinux_dir/"
  fi
  
  # Copy required syslinux modules
  for module in ldlinux.c32 libcom32.c32 libutil.c32 vesamenu.c32; do
    if [[ -f "/usr/lib/syslinux/modules/bios/$module" ]]; then
      cp "/usr/lib/syslinux/modules/bios/$module" "$isolinux_dir/"
    fi
  done
  
  # Create isolinux.cfg
  cat > "${isolinux_dir}/isolinux.cfg" <<'EOF'
DEFAULT vesamenu.c32
TIMEOUT 300
PROMPT 0

MENU TITLE CheckMK Installer Boot Menu

LABEL ubuntu
  MENU LABEL Boot CheckMK Installer (Ubuntu Live)
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd boot=casper quiet splash ---

LABEL grub
  MENU LABEL Boot using GRUB (UEFI)
  COM32 chain.c32
  APPEND grub

LABEL local
  MENU LABEL Boot from local disk
  LOCALBOOT 0
EOF
  
  log_success "Hybrid boot configured"
}

# ================================================================
# Create autostart script
# ================================================================

create_autostart() {
  local iso_root="$1"
  
  log_info "Creating autostart configuration..."
  
  # Create autostart script
  cat > "${iso_root}/autostart.sh" <<'EOF'
#!/bin/bash
# CheckMK Installer Autostart

clear
echo "=========================================="
echo "  CheckMK Installer"
echo "=========================================="
echo ""
echo "This is a complete offline installer"
echo "with all tools pre-loaded."
echo ""
echo "To install CheckMK, run:"
echo ""
echo "  sudo bash /cdrom/checkmk-installer/install.sh"
echo ""
echo "Requirements:"
echo "  - Root privileges"
echo "  - Supported OS (Ubuntu/Debian/NethServer)"
echo ""
echo "=========================================="
echo ""
EOF
  
  chmod +x "${iso_root}/autostart.sh"
  
  log_success "Autostart script created"
}

# ================================================================
# Customize GRUB menu
# ================================================================

customize_grub() {
  local iso_root="$1"
  
  log_info "Customizing GRUB menu..."
  
  local grub_cfg="${iso_root}/boot/grub/grub.cfg"
  
  if [[ ! -f "$grub_cfg" ]]; then
    log_warning "GRUB config not found, skipping customization"
    return 0
  fi
  
  # Backup original
  cp "$grub_cfg" "${grub_cfg}.bak"
  
  # Update menu title
  sed -i 's/Ubuntu/CheckMK Installer/g' "$grub_cfg"
  
  log_success "GRUB menu customized"
}

# ================================================================
# Build final ISO
# ================================================================

build_iso() {
  local iso_root="$1"
  local output_iso="${ISO_OUTPUT_DIR}/${ISO_NAME}"
  
  log_info "Building final ISO image..."
  
  mkdir -p "$ISO_OUTPUT_DIR"
  
  # Check if UEFI boot is available
  local efi_boot_args=""
  if [[ -f "${iso_root}/boot/grub/efi.img" ]]; then
    log_debug "UEFI boot image found, enabling UEFI support"
    efi_boot_args="-eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat"
  else
    log_warning "UEFI boot image not found, creating BIOS-only ISO"
  fi
  
  # Build ISO with xorriso
  if [[ -n "$efi_boot_args" ]]; then
    # Build with UEFI support
    xorriso -as mkisofs \
      -iso-level 3 \
      -full-iso9660-filenames \
      -volid "CHECKMK_INSTALLER" \
      -appid "CheckMK Complete Installer" \
      -publisher "CheckMK Tools" \
      -preparer "make-iso.sh" \
      -eltorito-boot isolinux/isolinux.bin \
      -eltorito-catalog isolinux/boot.cat \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
      $efi_boot_args \
      -output "$output_iso" \
      "$iso_root" 2>&1 | grep -v "^$" || true
  else
    # Build BIOS-only
    xorriso -as mkisofs \
      -iso-level 3 \
      -full-iso9660-filenames \
      -volid "CHECKMK_INSTALLER" \
      -appid "CheckMK Complete Installer" \
      -publisher "CheckMK Tools" \
      -preparer "make-iso.sh" \
      -eltorito-boot isolinux/isolinux.bin \
      -eltorito-catalog isolinux/boot.cat \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
      -output "$output_iso" \
      "$iso_root" 2>&1 | grep -v "^$" || true
  fi
  
  if [[ ! -f "$output_iso" ]]; then
    log_error "Failed to create ISO"
    return 1
  fi
  
  # Make ISO hybrid (bootable from USB)
  if command -v isohybrid &>/dev/null; then
    log_info "Making ISO hybrid bootable..."
    if [[ -n "$efi_boot_args" ]]; then
      isohybrid --uefi "$output_iso" 2>/dev/null || log_warning "Hybrid boot setup failed (non-critical)"
    else
      isohybrid "$output_iso" 2>/dev/null || log_warning "Hybrid boot setup failed (non-critical)"
    fi
  fi
  
  log_success "ISO created: $output_iso"
}

# ================================================================
# Cleanup
# ================================================================

cleanup() {
  if [[ -d "$WORK_DIR" ]]; then
    log_info "Cleaning up temporary files..."
    rm -rf "$WORK_DIR"
    log_success "Cleanup completed"
  fi
}

# ================================================================
# Main execution
# ================================================================

main() {
  log_info "Starting complete ISO build process..."
  
  # Check dependencies
  if ! check_dependencies; then
    exit 1
  fi
  
  # Download Ubuntu ISO
  local ubuntu_iso
  ubuntu_iso=$(download_ubuntu_iso)
  
  if [[ ! -f "$ubuntu_iso" ]]; then
    log_error "Ubuntu ISO not available"
    exit 1
  fi
  
  # Clean previous work directory
  if [[ -d "$WORK_DIR" ]]; then
    log_info "Removing previous work directory..."
    rm -rf "$WORK_DIR"
  fi
  
  # Extract ISO
  local iso_root="${WORK_DIR}/iso"
  if ! extract_iso "$ubuntu_iso" "$iso_root"; then
    exit 1
  fi
  
  # Add complete installer (full installation)
  if ! add_scripts_to_iso "$iso_root"; then
    exit 1
  fi
  
  # Setup boot
  setup_hybrid_boot "$iso_root"
  
  # Create autostart
  create_autostart "$iso_root"
  
  # Customize GRUB
  customize_grub "$iso_root"
  
  # Build ISO
  if ! build_iso "$iso_root"; then
    cleanup
    exit 1
  fi
  
  # Cleanup
  cleanup
  
  # Show summary
  local output_iso="${ISO_OUTPUT_DIR}/${ISO_NAME}"
  local iso_size
  iso_size=$(du -h "$output_iso" | cut -f1)
  
  echo ""
  display_box "Complete ISO Build Complete!" \
    "" \
    "ISO Location: $output_iso" \
    "ISO Size: $iso_size" \
    "" \
    "This is a COMPLETE offline installer that:" \
    "  - Includes all scripts" \
    "  - No internet required" \
    "  - Production-ready" \
    "" \
    "Usage:" \
    "  1. Boot from ISO/USB" \
    "  2. Open terminal" \
    "  3. Run: sudo bash /cdrom/checkmk-installer/install.sh" \
    "" \
    "To write to USB:" \
    "  sudo dd if=$output_iso of=/dev/sdX bs=4M status=progress"
  
  log_success "Complete ISO build completed successfully!"
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main
main "$@"
