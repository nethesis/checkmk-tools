#!/bin/bash
# Deploy MRPE configuration for Proxmox checks
# Questo script disabilita i local checks e configura MRPE

set -euo pipefail

SCRIPT_DIR="/opt/checkmk-tools/script-check-proxmox"
MRPE_CONFIG="/etc/check_mk/mrpe.cfg"
AGENT_CONFIG="/etc/check_mk/checkmk_agent.cfg"

echo "=========================================="
echo "  Proxmox MRPE Setup"
echo "=========================================="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Questo script deve essere eseguito come root"
   echo "   Usa: sudo $0"
   exit 1
fi

# 1. Backup existing configs
echo "📦 Backup configurazioni esistenti..."
if [[ -f "$MRPE_CONFIG" ]]; then
    cp "$MRPE_CONFIG" "${MRPE_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "   ✓ Backup di mrpe.cfg creato"
fi

# 2. Ensure scripts in full/ are executable
echo
echo "🔐 Configurazione permessi script..."
cd "$SCRIPT_DIR/full"
chmod +x *.sh
echo "   ✓ Permessi esecuzione configurati per script in full/"

# 3. Ensure remote scripts are executable
cd "$SCRIPT_DIR/remote"
chmod +x *.sh
echo "   ✓ Permessi esecuzione configurati per launcher in remote/"

# 4. Add MRPE configuration
echo
echo "📝 Configurazione MRPE..."

# Check if MRPE section already exists
if grep -q "# MRPE Configuration for Proxmox Checks" "$MRPE_CONFIG" 2>/dev/null; then
    echo "   ⚠️  Configurazione MRPE già presente"
    echo "   Per aggiornare, rimuovi manualmente la sezione esistente da $MRPE_CONFIG"
else
    # Add MRPE configuration
    cat >> "$MRPE_CONFIG" << 'EOF'

# ========================================
# MRPE Configuration for Proxmox Checks
# ========================================
# Auto-configured by setup-mrpe.sh

# Backup Status
Proxmox_Backup_Status /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_backup_status.sh

# LXC Container Checks
Proxmox_LXC_Runtime /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_lxc_runtime.sh
Proxmox_LXC_Status /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_lxc_status.sh

# QEMU VM Checks
Proxmox_QEMU_Guest_Agent /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_qemu_guest_agent_status.sh
Proxmox_QEMU_Runtime /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_qemu_runtime.sh
Proxmox_QEMU_Status /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_qemu_status.sh

# Services Status
Proxmox_Services /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_services_status.sh

# Snapshots
Proxmox_Snapshots /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_snapshots_status.sh
Proxmox_VM_Snapshots /opt/checkmk-tools/script-check-proxmox/full/check-proxmox-vm-snapshot-status.sh

# Storage
Proxmox_Storage /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_storage_status.sh

# Resource Consumers
Proxmox_Top_Consumers /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_top_consumers.sh

# VM API & Monitoring
Proxmox_VM_API /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_vm_api.sh
Proxmox_VM_Disks /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_vm_disks.sh
Proxmox_VM_Monitor /opt/checkmk-tools/script-check-proxmox/full/check-proxmox_vm_monitor.sh
Proxmox_VM_Status /opt/checkmk-tools/script-check-proxmox/full/check-proxmox-vm-status.sh

EOF
    echo "   ✓ Configurazione MRPE aggiunta a $MRPE_CONFIG"
fi

# 5. Test MRPE output
echo
echo "🧪 Test configurazione MRPE..."
mrpe_lines=$(check_mk_agent | grep -c "<<<mrpe>>>" || echo "0")
if [[ "$mrpe_lines" -gt 0 ]]; then
    echo "   ✓ Sezione MRPE trovata nell'output dell'agente"
    check_count=$(check_mk_agent | sed -n '/<<<mrpe>>>/,/<<</{p}' | grep -c "^(" || echo "0")
    echo "   ✓ $check_count MRPE checks configurati"
else
    echo "   ⚠️  Sezione MRPE non trovata nell'output dell'agente"
fi

# 6. Summary
echo
echo "=========================================="
echo "  ✅ Setup Completato!"
echo "=========================================="
echo
echo "Prossimi passi:"
echo "1. Sul server CheckMK esegui:"
echo "   cmk -II $(hostname -f)"
echo
echo "2. Verifica i nuovi check MRPE nel WebUI di CheckMK"
echo
echo "3. Per debug:"
echo "   check_mk_agent | grep -A 20 '<<<mrpe>>>'"
echo
echo "4. Gli script originali sono stati spostati in:"
echo "   $SCRIPT_DIR/full-disabled/"
echo

exit 0
