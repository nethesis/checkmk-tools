#!/bin/bash
# Script di diagnostica per verificare stato auto-git-sync
echo "========================================="
echo "  Diagnostica Auto Git Sync"
echo "========================================="
echo ""
# Verifica se il servizio esiste
if systemctl list-unit-files | grep -q auto-git-sync.service; then    
echo "Ô£à Servizio auto-git-sync.service trovato"    
echo ""        
echo "--- STATUS SERVIZIO ---"    systemctl status auto-git-sync.service --no-pager    
echo ""        
echo "--- ULTIMI LOG ---"    journalctl -u auto-git-sync.service -n 50 --no-pager    
echo ""else    
echo "ÔØî Servizio auto-git-sync.service NON trovato"    
echo ""fi
# Verifica repository locale
REPO_DIR="/opt/checkmk-tools"
if [ -d "$REPO_DIR" ]; then    
echo "--- STATO REPOSITORY LOCALE ---"    cd "$REPO_DIR"    
echo "­ƒôü Directory: $REPO_DIR"    
echo ""        
echo "Branch corrente:"    git branch --show-current    
echo ""        
echo "Ultimo commit locale:"    git log -1 --oneline    
echo ""        
echo "Ultimo commit remoto (origin/main):"    git fetch origin 2>/dev/null    git log origin/main -1 --oneline    
echo ""        
echo "Stato git:"    git status    
echo ""        
echo "Verifica struttura cartelle:"    
echo ""        
echo "script-tools:"    ls -ld script-tools/remote script-tools/full 2>/dev/null || 
echo "  ÔØî Cartelle remote/full NON trovate"    
echo ""        
echo "Ydea-Toolkit:"    ls -ld Ydea-Toolkit/remote Ydea-Toolkit/full 2>/dev/null || 
echo "  ÔØî Cartelle remote/full NON trovate"    
echo ""        
echo "Fix:"    ls -ld Fix/remote Fix/full 2>/dev/null || 
echo "  ÔØî Cartelle remote/full NON trovate"    
echo ""        
echo "script-notify-checkmk:"    ls -ld script-notify-checkmk/remote script-notify-checkmk/full 2>/dev/null || 
echo "  ÔØî Cartelle remote/full NON trovate"    
echo ""        
echo "script-check-ns7:"    ls -ld script-check-ns7/polling script-check-ns7/nopolling 2>/dev/null || 
echo "  ÔØî Cartelle polling/nopolling NON trovate"    
echo ""        
echo "script-check-ns8:"    ls -ld script-check-ns8/polling script-check-ns8/nopolling 2>/dev/null || 
echo "  ÔØî Cartelle polling/nopolling NON trovate"    
echo ""        
echo "script-check-ubuntu:"    [ -d "script-check-ubuntu/polling" ] && ls -ld script-check-ubuntu/polling 2>/dev/null    [ -d "script-check-ubuntu/nopolling" ] && ls -ld script-check-ubuntu/nopolling 2>/dev/null    [ ! -d "script-check-ubuntu/polling" ] && [ ! -d "script-check-ubuntu/nopolling" ] && 
echo "  ÔØî Cartelle polling/nopolling NON trovate"    
echo ""        
echo "script-check-windows:"    [ -d "script-check-windows/polling" ] && ls -ld script-check-windows/polling 2>/dev/null    [ -d "script-check-windows/nopolling" ] && ls -ld script-check-windows/nopolling 2>/dev/null    [ ! -d "script-check-windows/polling" ] && [ ! -d "script-check-windows/nopolling" ] && 
echo "  ÔØî Cartelle polling/nopolling NON trovate"    
echo ""        
echo "Proxmox:"    [ -d "Proxmox/polling" ] && ls -ld Proxmox/polling 2>/dev/null || 
echo "  ÔÜá´©Å  polling/ vuota (normale)"    [ -d "Proxmox/nopolling" ] && ls -ld Proxmox/nopolling 2>/dev/null    [ ! -d "Proxmox/nopolling" ] && 
echo "  ÔØî nopolling/ NON trovata"    
echo ""else    
echo "ÔØî Repository NON trovato in: $REPO_DIR"
fi
echo ""
echo "========================================="
echo "  Fine Diagnostica"
echo "========================================="
