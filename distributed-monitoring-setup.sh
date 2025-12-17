#!/bin/bash
/usr/bin/env bash
# distributed-monitoring-setup.sh
# Setup CheckMK Distributed Monitoring between local central and remote VPS
# 
# Architecture (CORRECTED):
# - Local Site (boxlocale): CENTRAL site managing all hosts, pushes config to VPS via HTTPS:443
# - VPS Site (central): REMOTE site receiving configuration and displaying aggregated data
#
# Network constraints:
# - VPS (public) CANNOT reach local (private IP)
# - Local CAN reach VPS (outbound HTTPS:443)
# - Solution: Local pushes configuration to VPS
#
# Connection: Local (central) ÔåÆ VPS (remote) via HTTPS:443set -euo pipefail
# Colors
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
B='\033[0;34m'
N='\033[0m'
# Configuration
VPS_HOST="${VPS_HOST:-monitor01.nethlab.it}"
VPS_SITE="${VPS_SITE:-central}"
LOCAL_SITE="${LOCAL_SITE:-boxlocale}"
VPS_SITE_ALIAS="${VPS_SITE_ALIAS:-central}"
echo -e "${B}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${N}"
echo -e "${B}Ôòæ      CheckMK Distributed Monitoring Setup                 Ôòæ${N}"
echo -e "${B}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${N}"
echo ""
# Detect if we're on local (central) or VPS (remote)detect_role() {    local hostname    hostname=$(hostname -f 2>/dev/null || hostname)        if [[ "$hostname" == *"$VPS_HOST"* ]] || [[ "$(hostname -I 2>/dev/null)" == *"$(dig +short $VPS_HOST 2>/dev/null)"* ]]; then
    echo "vps"
else        
echo "local"    fi}
ROLE=$(detect_role)
echo -e "${G}Role detected: ${B}$ROLE${N}"
echo -e "${Y}Note: Local = Central (manages all), VPS = Remote (receives config)${N}"
echo ""
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# Local Site Configuration (Central)
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#configure_local() {    
echo -e "${B}ÔòÉÔòÉÔòÉ Configuring Local Site (Central Manager) ÔòÉÔòÉÔòÉ${N}"        local site=$LOCAL_SITE    local site=$CENTRAL_SITE        
# Check if site exists    if ! omd sites | grep -q "^$site"; then
    echo -e "${R}Ô£ù Site '$site' not found${N}"
    exit 1    fi
echo -e "${G}Ô£ô Site '$site' found${N}"        
# Check if already configured    
echo -e "\n${Y}ÔåÆ Checking current configuration...${N}"        if su
do -u "$site" test -f "etc/check_mk/multisite.d/wato/distributed_monitoring.mk"; then
    echo -e "${G}Ô£ô Distributed configuration already exists${N}"        if su
do -u "$site" grep -q "replication.*push" "etc/check_mk/multisite.d/wato/distributed_monitoring.mk" 2>/dev/null; then
    echo -e "${G}Ô£ô Push replication already configured${N}"            
echo -e "\n${Y}ÔåÆ Configuration appears complete. Skipping.${N}"            
echo -e "\n${B}To reconfigure, remove: ~/etc/check_mk/multisite.d/wato/distributed_monitoring.mk${N}"            return 0        fi    fi        
# Switch to site user    
echo -e "\n${Y}ÔåÆ Configuring distributed monitoring on central site...${N}"        su
do -u "$site" bash <<EOFset -e
# Enter OMD environmentcd /omd/sites/$sitesource .profile
# Enable distributed monitoring
echo -e "${Y}ÔåÆ Enabling distributed monitoring in global settings...${N}"    
# Switch to site user    
echo -e "\n${Y}ÔåÆ Configuring local site as central manager...${N}"        
# Get VPS automation credentials    
echo -e "\n${B}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${N}"    
echo -e "${Y}VPS Automation Secret Required:${N}"    
echo -e "Run on VPS: ${B}su
do -u $VPS_SITE cat ~/var/check_mk/web/automation/automation.secret${N}"    
echo -e "${B}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${N}"    read -p "Enter VPS automation secret: " vps_secret        if [[ -z "$vps_secret" ]]; then
    echo -e "${R}Ô£ù VPS automation secret is required${N}"
    exit 1    fi        su
do -u "$site" bash <<EOFset -e
# Enter OMD environmentcd /omd/sites/$sitesource .profile
# Create distributed monitoring configuration
echo -e "${Y}ÔåÆ Creating distributed monitoring configuration...${N}"cat > etc/check_mk/multisite.d/wato/distributed_monitoring.mk <<'MULTISITE'
# Local Site: Central Manager
# Pushes configuration to VPS remote sitesites.update({    "$VPS_SITE_ALIAS": {        "alias": "VPS Remote Site",        "socket": "local",        "disable_wato": False,        "disabled": False,        "insecure": False,        "multisiteurl": "https://$VPS_HOST/$VPS_SITE/check_mk/",        "persist": False,        "replicate_ec": True,        "replicate_mkps": True,        "replication": "push",        "timeout": 10,        "user_sync": "all",        "secret": "$vps_secret",    }})MULTISITE
echo -e "${G}Ô£ô Distributed monitoring configuration created${N}"
# Ensure WATO is enabled
echo -e "${Y}ÔåÆ Ensuring Setup (WATO) is enabled...${N}"if ! grep -q "wato_enabled.*True" etc/check_mk/multisite.mk 2>/dev/null; then
    echo "wato_enabled = True" >> etc/check_mk/multisite.mk
fi
# Restart site
echo -e "${Y}ÔåÆ Restarting site...${N}"omd restart
echo -e "${G}Ô£ô Local site configured as central manager${N}"EOF    
echo -e "\n${G}ÔòÉÔòÉÔòÉ Local Site (Central) Configuration Complete ÔòÉÔòÉÔòÉ${N}"    
echo -e "\n${B}Next steps:${N}"    
echo -e "  1. Run this script on VPS to configure it as remote"    
echo -e "  2. In Local GUI: Setup ÔåÆ Hosts ÔåÆ Bulk operations"    
echo -e "  3. Select all hosts ÔåÆ Edit attributes ÔåÆ Monitored on site: $VPS_SITE_ALIAS"    
echo -e "  4. Activate changes to push configuration to VPS"}       
echo -e "${R}Ô£ù Site '$site' not found${N}"
    exit 1    fi
echo -e "${G}Ô£ô Site '$site' found${N}"        
# Switch to site user    
echo -e "\n${Y}ÔåÆ Configuring distributed monitoring on remote site...${N}"        su
do -u "$site" bash <<EOFset -e
# Enter OMD environmentcd /omd/sites/$sitesource .profile
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# VPS Site Configuration (Remote)    
echo -e "${G}Ô£ô Site '$site' found${N}"        
# Switch to site user    
echo -e "\n${Y}ÔåÆ Configuring VPS as remote receiver...${N}"        su
do -u "$site" bash <<EOFset -e
# Enter OMD environmentcd /omd/sites/$sitesource .profile
# Remove any existing distributed configuration
echo -e "${Y}ÔåÆ Removing any existing distributed configuration...${N}"rm -f etc/check_mk/multisite.d/wato/distributed_monitoring.mkrm -f etc/check_mk/conf.d/wato/distributed.mkrm -f etc/check_mk/multisite.d/wato/distributed_wato.mk
echo -e "${G}Ô£ô VPS configured as clean remote site${N}"
# Ensure WATO is enabled to receive configuration
echo -e "${Y}ÔåÆ Ensuring Setup (WATO) is enabled...${N}"if ! grep -q "wato_enabled.*True" etc/check_mk/multisite.mk 2>/dev/null; then
    echo "wato_enabled = True" >> etc/check_mk/multisite.mk
fi
# Check if automation user exists, create if needed
if [[ ! -f var/check_mk/web/automation/automation.secret ]]; then
    echo -e "${Y}ÔåÆ Creating automation user...${N}"    secret=\$(pwgen -s 32 1 2>/dev/null || openssl rand -base64 24)    htpasswd -bB -c etc/htpasswd automation "\$secret" 2>/dev/null    mkdir -p var/check_mk/web/automation    
echo "\$secret" > var/check_mk/web/automation/automation.secret    chmod 660 var/check_mk/web/automation/automation.secret    
echo -e "${G}Ô£ô Automation user created${N}"else    
echo -e "${G}Ô£ô Automation user already exists${N}"fi
# Restart site
echo -e "${Y}ÔåÆ Restarting site...${N}"omd restart
echo -e "${G}Ô£ô VPS site configured successfully as remote${N}"
# Display automation secret for local site configuration
echo -e "\n${B}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${N}"
echo -e "${B}VPS Automation Credentials for Local Site:${N}"
echo -e "${B}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${N}"
echo -e "${Y}Site ID:${N} $site"
echo -e "${Y}Site URL:${N} https://$VPS_HOST/$site/check_mk/"
echo -e "${Y}Automation User:${N} automation"
echo -e "${Y}Automation Secret:${N}"cat var/check_mk/web/automation/automation.secret
echo ""
echo -e "${B}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${N}"
echo -e "\n${Y}Use these credentials when configuring the local site${N}"EOF    
echo -e "\n${G}ÔòÉÔòÉÔòÉ VPS Site (Remote) Configuration Complete ÔòÉÔòÉÔòÉ${N}"    
echo -e "\n${B}Next steps:${N}"    
echo -e "  1. Run this script on local site with the automation secret above"    
echo -e "  2. Local will push configuration to this VPS"    
echo -e "  3. All hosts assigned to site '$site' will appear here"}    if ! omd sites | grep -q "^$site"; then
    echo -e "${Y}ÔÜá Site '$site' not found. Available sites:${N}"        omd sites || true        return 1    fi
echo -e "${B}Site:${N} $site (${G}$ROLE${N})"    su
do -u "$site" bash -lc 'set -ecd /omd/sites/'"$site"'source .profile
echo "--- OMD status ---"omd status || true
echo "--- WATO flags (wato_enabled) ---"grep -R --line-number "wato_enabled" etc/check_mk/multisite* etc/check_mk/multisite.d/wato/* 2>/dev/null || 
echo "none"
echo "--- Livestatus TCP config ---"omd config show LIVESTATUS_TCP || trueomd config show LIVESTATUS_TCP_PORT || trueaudit() {    
echo -e "${B}ÔòÉÔòÉÔòÉ Audit: Quick Diagnostics ÔòÉÔòÉÔòÉ${N}"    local site    if [[ "$ROLE" == "vps" ]]; then
    site="$VPS_SITE"
else        site="$LOCAL_SITE"    fic/check_mk/multisite.d/wato/distributed_monitoring.mk || true
fi
echo "--- Recent wato.log (last 80) ---"tail -n 80 var/log/wato.log 2>/dev/null || true
echo "--- Recent web.log (last 60) ---"tail -n 60 var/log/web.log 2>/dev/null || true
echo "--- Apache error_log (last 40) ---"tail -n 40 var/log/apache/error_log 2>/dev/null || true
echo "--- Disk space ---"df -h . || true
echo "--- Permissions under etc/check_mk (top 30) ---"find etc/check_mk -maxdepth 2 -type d -printf "%M %u:%g %p\n" | head -n 30 || true
echo "--- Dry-run activation (
cmk --debug -O) ---"
cmk --debug -O || 
echo "
cmk -O returned non-zero (see logs above)"'}
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
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
#main() {    
# Mode switches    if [[ "${1:-}" == "--audit" || "${1:-}" == "audit" ]]; then        audit        return    fi    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [--audit]"        
echo "  --audit  Run non-destructive diagnostics to help troubleshoot activation"        return    fi    
# Check root/su
do for configuration modes    if [[ $EUID -ne 0 ]] && ! su
do -n true 2>/dev/null; then
    echo -e "${R}Ô£ù This script requires root privileges${N}"        
echo -e "${Y}ÔåÆ Run with: su
do $0${N}"
    exit 1    fi        case "$ROLE" in        central)            configure_central            ;;        remote)            configure_remote            ;;        *)            
echo -e "${R}Ô£ù Could not detect role${N}"            
echo -e "${Y}ÔåÆ Set ROLE environment variable: 
ROLE=central or 
ROLE=remote${N}"
    exit 1            ;;    esacmain() {    
# Mode switches    if [[ "${1:-}" == "--audit" || "${1:-}" == "audit" ]]; then        audit        return    fi    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [--audit]"        
echo "  --audit  Run non-destructive diagnostics to help troubleshoot activation"        
echo ""        
echo "Architecture:"        
echo "  Local (boxlocale) = Central site managing all hosts"        
echo "  VPS (central)     = Remote site receiving configuration"        
echo ""        
echo "Network: Local pushes config to VPS via HTTPS:443 (VPS cannot reach local)"        return    fi    
# Check root/su
do for configuration modes    if [[ $EUID -ne 0 ]] && ! su
do -n true 2>/dev/null; then
    echo -e "${R}Ô£ù This script requires root privileges${N}"        
echo -e "${Y}ÔåÆ Run with: su
do $0${N}"
    exit 1    fi        case "$ROLE" in        vps)            configure_vps            ;;        local)            configure_local            ;;        *)            
echo -e "${R}Ô£ù Could not detect role${N}"            
echo -e "${Y}ÔåÆ Set VPS_HOST environment variable or run manually:${N}"            
echo -e "  ${B}
ROLE=vps $0${N}  (on VPS)"            
echo -e "  ${B}
ROLE=local $0${N}  (on local box)"
    exit 1            ;;    esac        
echo -e "\n${G}Ô£ô Configuration complete!${N}"}
