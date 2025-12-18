#!/usr/bin/env bash
set -euo pipefail

echo "ERROR: this script was quarantined because it was syntactically broken." >&2
echo "A copy of the previous content was saved next to this file." >&2
exit 1

: <<'CORRUPTED_11c31165644947cd9d82191de0db3458'
#!/bin/bash
/usr/bin/env bash
# cleanup-full.sh - Complete cleanup of CheckMK installation
# Removes all components installed by the installerset -euo pipefail
echo "=========================================="
echo "CheckMK Complete Cleanup Script"
echo "=========================================="
echo ""
echo "This will remove:"
echo "  - CheckMK Server (site: monitoring)"
echo "  - CheckMK Agent"
echo "  - FRPS Server"
echo "  - All monitoring scripts"
echo "  - Ydea Toolkit"
echo "  - Configuration files"
echo ""read -r -p "Continue? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi echo ""
echo "Starting cleanup..."
# Stop all services
echo "[1/12] Stopping services..."su
do systemctl stop checkmk-agent-async.socket 2>/dev/null || truesu
do systemctl stop check-mk-agent@.service 2>/dev/null || truesu
do systemctl stop frps.service 2>/dev/null || truesu
do systemctl stop ydea-toolkit.timer 2>/dev/null || truesu
do systemctl stop ydea-toolkit.service 2>/dev/null || truesu
do systemctl stop ydea-ticket-monitor.timer 2>/dev/null || truesu
do systemctl stop ydea-ticket-monitor.service 2>/dev/null || true
# Stop CheckMK site
echo "[2/12] Stopping CheckMK site..."if [ -d /omd/sites/monitoring ]; then  su
do omd stop monitoring 2>/dev/null || true  sleep 2
fi # Kill all CheckMK/OMD processes BEFORE attempting removal
echo "[2.5/12] Force killing all CheckMK processes..."su
do pkill -9 -f "omd\|monitoring\|/omd/sites" 2>/dev/null || truesleep 2
# Skip omd rm entirely - just clean up manually
echo "[3/12] Removing CheckMK site (manual cleanup)..."
# Don't use omd rm - it hangs. Just remove directories after killing processes
echo "Skipping 'omd rm' command (unreliable), will clean directories manually"
# Unmount any locked directories
echo "[4/12] Unmounting locked directories..."su
do umount /omd/sites/monitoring/tmp 2>/dev/null || truesu
do umount /opt/omd/sites/monitoring/tmp 2>/dev/null || true
# Clean /etc/fstab from monitoring entries
echo "[4.5/12] Cleaning /etc/fstab from monitoring entries..."if grep -q "monitoring" /etc/fstab 2>/dev/null; then
    echo "Removing monitoring entries from /etc/fstab..."  su
do sed -i '/monitoring/d' /etc/fstab  su
do systemctl daemon-reload
fi
# Remove site directories BEFORE uninstalling package
echo "[4.6/12] Removing CheckMK site directories..."if [[ -d /omd/sites/monitoring ]]; then
    echo "Removing /omd/sites/monitoring..."  su
do rm -rf /omd/sites/monitoring
fi
# Uninstall CheckMK Server
echo "[5/12] Uninstalling CheckMK Server..."if dpkg -l | grep -q check-mk-raw; then  
# Remove corrupted dpkg metadata files first (critical for clean state)  
echo "Removing dpkg metadata..."  su
do rm -rf /var/lib/dpkg/info/check-mk-agent.* 2>/dev/null || true  su
do rm -f /var/lib/dpkg/info/check-mk-raw-* 2>/dev/null || true    
# Force remove check-mk-agent if in broken state  
echo "Force removing check-mk-agent..."  su
do dpkg --remove --force-remove-reinstreq check-mk-agent 2>/dev/null || true  su
do dpkg --purge check-mk-agent 2>/dev/null || true    
# Method 1: dpkg remove CheckMK server  su
do dpkg --remove --force-remove-reinstreq check-mk-raw-2.4.0p16 2>/dev/null || true    
# Method 2: apt-get remove with wildcard  su
do apt-get remove --purge -y check-mk-raw-2.4.0p16 2>/dev/null || true    
# Method 3: autoremove dependencies  su
do apt-get autoremove -y 2>/dev/null || true  su
do apt-get autoclean 2>/dev/null || true
fi
# Final cleanup of any remaining check-mk-agent corruption
echo "Final check for check-mk-agent corruption..."if dpkg -l | grep -q check-mk-agent; then
    echo "Forcing final removal of check-mk-agent..."  su
do rm -rf /var/lib/dpkg/info/check-mk-agent.* 2>/dev/null || true  su
do dpkg --remove --force-remove-reinstreq check-mk-agent 2>/dev/null || true  su
do dpkg --purge check-mk-agent 2>/dev/null || true
fi
# Remove files manuallysu
do rm -rf /omd /opt/omd /etc/alternatives/omd* /usr/bin/omdsu
do rm -f /tmp/check-mk-raw.debsu
do rm -rf /var/lib/cmk-agent
# Clean package cachesu
do apt-get cleansu
do apt-get update
# Remove CheckMK Agent
echo "[6/12] Removing CheckMK Agent..."su
do systemctl disable checkmk-agent-async.socket 2>/dev/null || truesu
do systemctl disable check-mk-agent@.service 2>/dev/null || truesu
do rm -f /etc/systemd/system/checkmk-agent-async.socketsu
do rm -f /etc/systemd/system/check-mk-agent@.servicesu
do rm -f /usr/bin/check_mk_agentsu
do rm -rf /etc/check_mksu
do rm -rf /var/lib/check_mk_agent
# Remove FRPS
echo "[7/12] Removing FRPS..."su
do systemctl disable frps.service 2>/dev/null || truesu
do rm -f /etc/systemd/system/frps.servicesu
do rm -f /usr/local/bin/frpssu
do rm -rf /etc/frp
# Remove monitoring scripts
echo "[8/12] Removing monitoring scripts..."su
do rm -rf /usr/lib/check_mk_agent/localsu
do rm -rf /usr/lib/check_mk_agent/pluginssu
do rm -f /usr/local/bin/launcher_remote_*
# Remove Ydea Toolkit
echo "[9/12] Removing Ydea Toolkit..."su
do systemctl disable ydea-toolkit.timer 2>/dev/null || truesu
do systemctl disable ydea-toolkit.service 2>/dev/null || truesu
do systemctl disable ydea-ticket-monitor.timer 2>/dev/null || truesu
do systemctl disable ydea-ticket-monitor.service 2>/dev/null || truesu
do rm -f /etc/systemd/system/ydea-toolkit.timersu
do rm -f /etc/systemd/system/ydea-toolkit.servicesu
do rm -f /etc/systemd/system/ydea-ticket-monitor.timersu
do rm -f /etc/systemd/system/ydea-ticket-monitor.servicesu
do rm -rf /opt/ydea-toolkit
# Remove OMD directories
echo "[10/12] Removing OMD directories..."su
do rm -rf /omdsu
do rm -rf /opt/omd
# Remove users and groups
echo "[10.5/12] Removing CheckMK users and groups..."su
do userdel monitoring 2>/dev/null || truesu
do groupdel monitoring 2>/dev/null || true
# Remove firewall rules (optional - commented out to preserve security)
# 
echo "[11/12] Removing firewall rules..."
# su
do ufw delete allow 5000/tcp 2>/dev/null || true
# su
do ufw delete allow 6556/tcp 2>/dev/null || true
# su
do ufw delete allow 7000/tcp 2>/dev/null || true
# su
do ufw delete allow 7500/tcp 2>/dev/null || true
echo "[11/12] Keeping firewall rules (manual cleanup if needed)"
# Reload systemd and reset failed units
echo "[12/12] Reloading systemd..."su
do systemctl daemon-reloadsu
do systemctl reset-failed
echo ""
echo "=========================================="
echo "Cleanup completed!"
echo "=========================================="
echo ""
echo "System is ready for fresh installation."
echo ""
echo "To reinstall, run:"
echo "  cd ~/checkmk-tools/Install/checkmk-installer"
echo "  su
do bash install.sh"
echo ""

CORRUPTED_11c31165644947cd9d82191de0db3458

