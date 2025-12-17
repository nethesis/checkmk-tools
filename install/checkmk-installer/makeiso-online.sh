#!/bin/bash
/usr/bin/env bash
# makeiso-online.sh - Create lightweight bootable ISO with online bootstrap
# Generates a minimal ISO that downloads and runs the CheckMK installer onlineset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source utilitiessource "${SCRIPT_DIR}/utils/colors.sh"source "${SCRIPT_DIR}/utils/logger.sh"
# Simple display_box function for ISO builderdisplay_box() {  local title="$1"  shift  
echo ""  
echo "============================================================"  
echo "  $title"  
echo "============================================================"  for line in "$@"; do    
echo "  $line"  done
echo "============================================================"  
echo ""}
# Configuration
ISO_NAME="checkmk-installer-online-v1.0-amd64.iso"
ISO_OUTPUT_DIR="${SCRIPT_DIR}/iso-output"
WORK_DIR="/tmp/checkmk-iso-online-build"
UBUNTU_VERSION="24.04.3"
UBUNTU_ISO_URL="https://releases.ubuntu.com/noble/ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"
UBUNTU_ISO_NAME="ubuntu-${UBUNTU_VERSION}-live-server-amd64.iso"init_loggingprint_header "CheckMK Installer Online ISO Builder"
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Check dependencies
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#check_dependencies() {  log_info "Checking dependencies..."    local deps=("wget" "xorriso" "mksquashfs" "genisoimage" "7z")  local missing=()    for dep in "${deps[@]}"; do    if ! command -v "$dep" &>/dev/null; then      missing+=("$dep")    fi  done    
# Check for isolinux files  if [[ ! -f "/usr/lib/ISOLINUX/isolinux.bin" ]] && [[ ! -f "/usr/lib/isolinux/isolinux.bin" ]]; then    missing+=("isolinux")  fi    if [[ ${
#missing[@]} -gt 0 ]]; then    log_error "Missing dependencies: ${missing[*]}"    log_info "Install with: su
do apt-get install xorriso isolinux squashfs-tools genisoimage p7zip-full wget"    return 1  fi    log_success "All dependencies installed"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Download Ubuntu ISO
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#download_ubuntu_iso() {  local iso_cache="${SCRIPT_DIR}/${UBUNTU_ISO_NAME}"    if [[ -f "$iso_cache" ]]; then    log_info "Using cached Ubuntu ISO" >&2    
echo "$iso_cache"    return 0  fi    log_info "Downloading Ubuntu ${UBUNTU_VERSION} ISO..." >&2  log_warning "This may take several minutes (~2.5GB download)" >&2    if ! wget --progress=bar:force -O "$iso_cache" "$UBUNTU_ISO_URL" 2>&1 |        stdbuf -o0 tr '\r' '\n' |        grep --line-buffered -oP '\d+%' |        while read -r percent; do         
echo -ne "\r${CYAN}Progress: ${WHITE}${percent}${NC} " >&2       done; then    
echo "" >&2    log_error "Failed to download Ubuntu ISO" >&2    return 1  fi
echo "" >&2    log_success "Ubuntu ISO downloaded" >&2  
echo "$iso_cache"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Extract Ubuntu ISO
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#extract_iso() {  local iso_file="$1"  local extract_dir="$2"    log_info "Extracting Ubuntu ISO..."    mkdir -p "$extract_dir"    
# Extract using 7z (compatible with Kali Linux)  log_info "Extracting ISO contents with 7z..."  cd "$extract_dir"    
# Show spinner during extraction  7z x -y "$iso_file" > "$LOG_FILE" 2>&1 &  local pid=$!    local spin='-\|/'  local i=0  while kill -0 $pid 2>/dev/null; do    i=$(( (i+1) %4 ))    
echo -ne "\r${CYAN}Extracting... ${spin:$i:1}${NC} "    sleep 0.1  done  wait $pid  local exit_code=$?  
echo -ne "\r${CYAN}Extracting... Done!${NC}\n"    cd - > /dev/null    if [ $exit_code -ne 0 ]; then    log_error "Failed to extract ISO"    return 1  fi    
# Make files writable  chmod -R u+w "$extract_dir"    log_success "ISO extracted"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Add bootstrap script to ISO
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#add_bootstrap_to_iso() {  local iso_root="$1"    log_info "Adding bootstrap script to ISO..."    
# Create checkmk-installer directory  local installer_dir="${iso_root}/checkmk-installer"  mkdir -p "$installer_dir"    
# Copy only the bootstrap script  local bootstrap_source="${SCRIPT_DIR}/../bootstrap-installer.sh"  if [[ ! -f "$bootstrap_source" ]]; then    log_error "Bootstrap script not found at: $bootstrap_source"    return 1  fi    cp "$bootstrap_source" "${installer_dir}/bootstrap-installer.sh"  chmod +x "${installer_dir}/bootstrap-installer.sh"    
# Create convenience launcher  cat > "${installer_dir}/install.sh" <<'EOF'
#!/bin/bash
# Quick install launcher
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"exec bash "${SCRIPT_DIR}/bootstrap-installer.sh" "$@"EOF    chmod +x "${installer_dir}/install.sh"    
# Create README  cat > "${installer_dir}/README.txt" <<'EOF'ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòùÔòæ                                                              ÔòæÔòæ         CheckMK Installer - Online Edition                  ÔòæÔòæ                                                              ÔòæÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØThis is a lightweight online installer that downloads the completeCheckMK installation tools from GitHub.QUICK START:------------After booting from this ISO, open a terminal and run:  su
do bash /cdrom/checkmk-installer/install.shOr the full command:  su
do bash /cdrom/checkmk-installer/bootstrap-installer.shWHAT IT DOES:-------------1. Clones/updates repository to /opt/checkmk-tools/2. Makes all .sh files executable3. Launches the interactive installerREQUIREMENTS:-------------- Internet connection (required!)- Git (will be installed automatically)- Root privilegesREPOSITORY:-----------https://github.com/Coverup20/checkmk-toolsADVANTAGES:------------ Small ISO size (base Ubuntu only)- Always installs latest version- No outdated scriptsDISADVANTAGES:--------------- Requires internet connection- Download time on first runFor offline installation, use the full ISO instead.EOF    log_success "Bootstrap script added to ISO"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Setup hybrid boot (isolinux for USB)
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#setup_hybrid_boot() {  local iso_root="$1"    log_info "Setting up hybrid boot support..."    
# Create isolinux directory if doesn't exist  local isolinux_dir="${iso_root}/isolinux"  mkdir -p "$isolinux_dir"    
# Copy isolinux files  if [[ -f "/usr/lib/ISOLINUX/isolinux.bin" ]]; then    cp /usr/lib/ISOLINUX/isolinux.bin "$isolinux_dir/"  elif [[ -f "/usr/lib/syslinux/modules/bios/isolinux.bin" ]]; then    cp /usr/lib/syslinux/modules/bios/isolinux.bin "$isolinux_dir/"  fi    
# Copy required syslinux modules  for module in ldlinux.c32 libcom32.c32 libutil.c32 vesamenu.c32; do    if [[ -f "/usr/lib/syslinux/modules/bios/$module" ]]; then      cp "/usr/lib/syslinux/modules/bios/$module" "$isolinux_dir/"    fi  done    
# Create isolinux.cfg  cat > "${isolinux_dir}/isolinux.cfg" <<'EOF'DEFAULT vesamenu.c32TIMEOUT 300PROMPT 0MENU TITLE CheckMK Installer Online Boot MenuLABEL ubuntu  MENU LABEL Boot CheckMK Online Installer (Ubuntu Live)  KERNEL /casper/vmlinuz  APPEND initrd=/casper/initrd boot=casper quiet splash ---LABEL grub  MENU LABEL Boot using GRUB (UE
FI)  COM32 chain.c32  APPEND grubLABEL local  MENU LABEL Boot from local disk  LOCALBOOT 0EOF    log_success "Hybrid boot configured"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Create autostart script
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#create_autostart() {  local iso_root="$1"    log_info "Creating autostart configuration..."    
# Create autostart script  cat > "${iso_root}/autostart.sh" <<'EOF'
#!/bin/bash
# CheckMK Online Installer Autostartclear
echo "=========================================="
echo "  CheckMK Online Installer"
echo "=========================================="
echo ""
echo "This is a lightweight online installer."
echo ""
echo "To install CheckMK, run:"
echo ""
echo "  su
do bash /cdrom/checkmk-installer/install.sh"
echo ""
echo "Requirements:"
echo "  - Internet connection (REQUIRED)"
echo "  - Root privileges"
echo ""
echo "=========================================="
echo ""EOF    chmod +x "${iso_root}/autostart.sh"    log_success "Autostart script created"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Customize GRUB menu
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#customize_grub() {  local iso_root="$1"    log_info "Customizing GRUB menu..."    local grub_cfg="${iso_root}/boot/grub/grub.cfg"    if [[ ! -f "$grub_cfg" ]]; then    log_warning "GRUB config not found, skipping customization"    return 0  fi    
# Backup original  cp "$grub_cfg" "${grub_cfg}.bak"    
# Update menu title  sed -i 's/Ubuntu/CheckMK Installer Online/g' "$grub_cfg"    log_success "GRUB menu customized"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Build final ISO
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#build_iso() {  local iso_root="$1"  local output_iso="${ISO_OUTPUT_DIR}/${ISO_NAME}"    log_info "Building final ISO image..."    mkdir -p "$ISO_OUTPUT_DIR"    
# Check if E
FI boot is available  local efi_boot_args=""  if [[ -f "${iso_root}/boot/grub/e
fi.img" ]]; then    log_debug "E
FI boot image found, enabling UE
FI support"    efi_boot_args="-eltorito-alt-boot -e boot/grub/e
fi.img -no-emul-boot -isohybrid-gpt-basdat"  else    log_warning "E
FI boot image not found, creating BIOS-only ISO"  fi    
# Build ISO with xorriso  if [[ -n "$efi_boot_args" ]]; then    
# Build with UE
FI support    xorriso -as mkisofs \      -iso-level 3 \      -full-iso9660-filenames \      -volid "CHECKMK_ONLINE" \      -appid "CheckMK Online Installer" \      -publisher "CheckMK Tools" \      -preparer "makeiso-online.sh" \      -eltorito-boot isolinux/isolinux.bin \      -eltorito-catalog isolinux/boot.cat \      -no-emul-boot \      -boot-load-size 4 \      -boot-info-table \      -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \      $efi_boot_args \      -output "$output_iso" \      "$iso_root" 2>&1 | grep -v "^$" || true  else    
# Build BIOS-only    xorriso -as mkisofs \      -iso-level 3 \      -full-iso9660-filenames \      -volid "CHECKMK_ONLINE" \      -appid "CheckMK Online Installer" \      -publisher "CheckMK Tools" \      -preparer "makeiso-online.sh" \      -eltorito-boot isolinux/isolinux.bin \      -eltorito-catalog isolinux/boot.cat \      -no-emul-boot \      -boot-load-size 4 \      -boot-info-table \      -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \      -output "$output_iso" \      "$iso_root" 2>&1 | grep -v "^$" || true  fi    if [[ ! -f "$output_iso" ]]; then    log_error "Failed to create ISO"    return 1  fi    
# Make ISO hybrid (bootable from USB)  if command -v isohybrid &>/dev/null; then    log_info "Making ISO hybrid bootable..."    if [[ -n "$efi_boot_args" ]]; then      isohybrid --ue
fi "$output_iso" 2>/dev/null || log_warning "Hybrid boot setup failed (non-critical)"    else      isohybrid "$output_iso" 2>/dev/null || log_warning "Hybrid boot setup failed (non-critical)"    fi  fi    log_success "ISO created: $output_iso"}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Cleanup
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#cleanup() {  if [[ -d "$WORK_DIR" ]]; then    log_info "Cleaning up temporary files..."    rm -rf "$WORK_DIR"    log_success "Cleanup completed"  fi}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
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
#main() {  log_info "Starting online ISO build process..."    
# Check dependencies  if ! check_dependencies; then    exit 1  fi    
# Download Ubuntu ISO  local ubuntu_iso  ubuntu_iso=$(download_ubuntu_iso)    if [[ ! -f "$ubuntu_iso" ]]; then    log_error "Ubuntu ISO not available"    exit 1  fi    
# Clean previous work directory  if [[ -d "$WORK_DIR" ]]; then    log_info "Removing previous work directory..."    rm -rf "$WORK_DIR"  fi    
# Extract ISO  local iso_root="${WORK_DIR}/iso"  if ! extract_iso "$ubuntu_iso" "$iso_root"; then    exit 1  fi    
# Add bootstrap script (lightweight)  if ! add_bootstrap_to_iso "$iso_root"; then    exit 1  fi    
# Setup boot  setup_hybrid_boot "$iso_root"    
# Create autostart  create_autostart "$iso_root"    
# Customize GRUB  customize_grub "$iso_root"    
# Build ISO  if ! build_iso "$iso_root"; then    cleanup    exit 1  fi    
# Cleanup  cleanup    
# Show summary  local output_iso="${ISO_OUTPUT_DIR}/${ISO_NAME}"local iso_sizelocal iso_sizeiso_size=$(du -h "$output_iso" | cut -f1)    
echo ""  display_box "Online ISO Build Complete!" \    "" \    "ISO Location: $output_iso" \    "ISO Size: $iso_size" \    "" \    "This is a LIGHTWEIGHT online installer that:" \    "  - Requires internet connection" \    "  - Downloads latest code from GitHub" \    "  - Always up-to-date" \    "" \    "Usage:" \    "  1. Boot from ISO/USB" \    "  2. Open terminal" \    "  3. Run: su
do bash /cdrom/checkmk-installer/install.sh" \    "" \    "To write to USB:" \    "  su
do dd if=$output_iso of=/dev/sdX bs=4M status=progress"    log_success "Online ISO build completed successfully!"}
# Trap cleanup on exittrap cleanup EXIT
# Run mainmain "$@"
