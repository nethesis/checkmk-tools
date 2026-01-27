#!/bin/bash
# install-backup-jobs.sh
# Installa systemd timers per gestione automatica backup CheckMK
# - job00: Giornaliero compresso (1.2MB), retention 90, ore 03:00
# - job01: Settimanale normale (362MB), retention 5, domenica 04:00
#
# Uso: ./install-backup-jobs.sh

set -euo pipefail

echo "============================================"
echo "CheckMK Backup Jobs Installation"
echo "============================================"

# Verifica root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   exit 1
fi

# Step 1: Verifica e prepara script
echo "📋 Preparing scripts..."
SCRIPT_DIR="/opt/checkmk-tools/script-tools/full"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$SCRIPT_DIR"

# Copia solo se non siamo già nella directory target
if [[ "$CURRENT_DIR" != "$SCRIPT_DIR" ]]; then
    cp checkmk_manage_job00_daily.sh "$SCRIPT_DIR/"
    cp checkmk_manage_job01_weekly.sh "$SCRIPT_DIR/"
    echo "✅ Scripts copied to $SCRIPT_DIR"
else
    echo "✅ Already in target directory, skipping copy"
fi

chmod +x "$SCRIPT_DIR/checkmk_manage_job00_daily.sh"
chmod +x "$SCRIPT_DIR/checkmk_manage_job01_weekly.sh"

# Step 2: Copia systemd units
echo "⚙️  Installing systemd units..."
cp systemd/checkmk-backup-job00.service /etc/systemd/system/
cp systemd/checkmk-backup-job00.timer /etc/systemd/system/
cp systemd/checkmk-backup-job01.service /etc/systemd/system/
cp systemd/checkmk-backup-job01.timer /etc/systemd/system/
echo "✅ Systemd units installed"

# Step 3: Reload systemd
echo "🔄 Reloading systemd daemon..."
systemctl daemon-reload
echo "✅ Systemd reloaded"

# Step 4: Abilita e avvia timers
echo "🚀 Enabling and starting timers..."
systemctl enable checkmk-backup-job00.timer
systemctl start checkmk-backup-job00.timer
systemctl enable checkmk-backup-job01.timer
systemctl start checkmk-backup-job01.timer
echo "✅ Timers enabled and started"

# Step 5: Verifica status
echo ""
echo "============================================"
echo "Installation Status"
echo "============================================"
echo ""
echo "Job00 Timer (Daily - 03:00):"
systemctl status checkmk-backup-job00.timer --no-pager -l
echo ""
echo "Next run:"
systemctl list-timers checkmk-backup-job00.timer --no-pager
echo ""
echo "============================================"
echo ""
echo "Job01 Timer (Weekly Sunday - 04:00):"
systemctl status checkmk-backup-job01.timer --no-pager -l
echo ""
echo "Next run:"
systemctl list-timers checkmk-backup-job01.timer --no-pager
echo ""
echo "============================================"
echo "✅ Installation Completed Successfully"
echo "============================================"
echo ""
echo "Logs:"
echo "  - Job00: tail -f /var/log/checkmk-backup-job00.log"
echo "  - Job01: tail -f /var/log/checkmk-backup-job01.log"
echo ""
echo "Manual run:"
echo "  - Job00: systemctl start checkmk-backup-job00.service"
echo "  - Job01: systemctl start checkmk-backup-job01.service"
echo ""
echo "Status:"
echo "  - Job00: systemctl status checkmk-backup-job00.timer"
echo "  - Job01: systemctl status checkmk-backup-job01.timer"
echo "============================================"

exit 0
