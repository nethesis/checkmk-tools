
#!/bin/bash
/bin/bash
# Smart Deploy per CheckMK Scripts - Sistema Ibrido
# Deploy iniziale + wrapper intelligenti per auto-updateset -euo pipefail
# =====================================================
# CONFIGURAZIONE
# =====================================================
GITHUB_REPO="Coverup20/checkmk-tools"
BASE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main"
# Auto-detection environment CheckMKif [ -d "/omd/sites" ]; then    
# Ambiente CheckMK Server (OMD)    
SITE_NAME=$(ls /omd/sites/ 2>/dev/null | head -n1)    
OMD_ROOT="/omd/sites/${SITE_NAME:-monitoring}"    
CHECKMK_LOCAL_DIR="/usr/lib/check_mk_agent/local"    
CHECKMK_SPOOL_DIR="/usr/lib/check_mk_agent/spool"    
CHECKMK_PLUGIN_DIR="/usr/lib/check_mk_agent/plugins"    
CHECKMK_NOTIFICATION_DIR="$OMD_ROOT/local/share/check_mk/notifications"    
CACHE_DIR="$OMD_ROOT/var/cache/checkmk-scripts"    
MK_CONFDIR="${MK_CONFDIR:-$OMD_ROOT/etc/check_mk}"    
MK_VARDIR="${MK_VARDIR:-$OMD_ROOT/var/check_mk}"    
ENV_TYPE="OMD Server"else    
# Ambiente CheckMK Agent (client)    
CHECKMK_LOCAL_DIR="/usr/lib/check_mk_agent/local"    
CHECKMK_SPOOL_DIR="/usr/lib/check_mk_agent/spool"    
CHECKMK_PLUGIN_DIR="/usr/lib/check_mk_agent/plugins"    
CACHE_DIR="/var/cache/checkmk-scripts"    
MK_CONFDIR="${MK_CONFDIR:-/etc/check_mk}"    
MK_VARDIR="${MK_VARDIR:-/var/lib/check_mk_agent}"    
ENV_TYPE="Agent Client"fi
# Lista script da deployare con i loro tipideclare -A 
SCRIPTS=(    ["check_cockpit_sessions"]="script-check-ns7/check_cockpit_sessions.sh:local"    ["check_dovecot_status"]="script-check-ns7/check_dovecot_status.sh:local"    ["check_ssh_root_sessions"]="script-check-ns7/check_ssh_root_sessions.sh:local"    ["check_postfix_status"]="script-check-ns7/check_postfix_status.sh:local"    ["telegram_realip"]="script-notify-checkmk/telegram_realip:notification")
# =====================================================
# FUNZIONI
# =====================================================log() {    
echo "[$(date '+%H:%M:%S')] $1"}add_version_metadata() {    local script_file="$1"    local version="${2:-1.0.0}"        
# Aggiungi metadata se non presente (pattern CheckMK)    if ! grep -q "CMK_VERSION\|__version__" "$script_file" 2>/dev/null; then        sed -i '2i 
# 
CMK_VERSION="'"$version"'"' "$script_file"        sed -i '3i 
# Auto-deployed via smart-deploy-hybrid' "$script_file"        sed -i '4i 
# Last-update: '"$(date '+%Y-%m-%d %H:%M:%S')" "$script_file"    fi}create_smart_wrapper() {    local script_name="$1"    local github_path="$2"    local script_type="$3"        
# Determina directory target in base al tipo    local target_dir    case "$script_type" in        "local")        target_dir="$CHECKMK_LOCAL_DIR" ;;        "spool")        target_dir="$CHECKMK_SPOOL_DIR" ;;        "plugin")       target_dir="$CHECKMK_PLUGIN_DIR" ;;        "notification") target_dir="$CHECKMK_NOTIFICATION_DIR" ;;        *)              target_dir="$CHECKMK_LOCAL_DIR" ;;    esac        local wrapper_file="$target_dir/${script_name}"        log "­ƒôØ Creando wrapper smart per $script_name ($script_type) in $target_dir..."        
# Crea directory se non esiste    mkdir -p "$target_dir" 2>/dev/null || true        cat > "$wrapper_file" << EOF
#!/bin/bash
# Smart CheckMK Script Wrapper - $script_name
# Auto-aggiorna da GitHub con fallback locale
# Based on CheckMK official patterns
# 
CMK_VERSION="1.0.0"
# Auto-deployed via smart-deploy-hybrid
# Last-update: $(date '+%Y-%m-%d %H:%M:%S')
SCRIPT_NAME="$script_name"
SCRIPT_TYPE="$script_type"
GITHUB_URL="$BASE_URL/$github_path"
CACHE_DIR="$CACHE_DIR"
CACHE_FILE="\$CACHE_DIR/\$SCRIPT_NAME.sh"
TIMEOUT=5
DEBUG=\${DEBUG:-false}
# Setup cache directorymkdir -p "\$CACHE_DIR" 2>/dev/null || true
# CheckMK-style error reportingreport_error() {    local error_msg="\$1"    if [ "\$SCRIPT_TYPE" = "local" ]; then        
echo "<<<check_mk>>>"        
echo "FailedScript: \$SCRIPT_NAME - \$error_msg"    fi    [ "\$DEBUG" = "true" ] && 
echo "ERROR: \$error_msg" >&2}
# Funzione di update (migliorata con pattern CheckMK)update_script() {    local temp_file="\$CACHE_FILE.tmp"        
# Try to download with proper error handling    if curl -s --max-time "\$TIMEOUT" --fail "\$GITHUB_URL" -o "\$temp_file" 2>/dev/null; then        
# Validate script (CheckMK pattern)        if head -n 1 "\$temp_file" | grep -q "^
#!/.*bash"; then            mv "\$temp_file" "\$CACHE_FILE"            chmod +x "\$CACHE_FILE"            
echo "
# Updated from GitHub \$(date)" > "\$CACHE_FILE.info"            return 0        else            rm -f "\$temp_file"            report_error "Invalid script format downloaded"            return 1        fi    else        rm -f "\$temp_file" 2>/dev/null        return 1    fi}
# CheckMK-style logging (pattern dal repository ufficiale)log_info() {    [ "\${DEBUG:-false}" = "true" ] && 
echo "
# CheckMK Wrapper [\$SCRIPT_NAME]: \$1" >&2}
# Main execution logic (CheckMK pattern)main() {    
# Try update (silent, non-blocking)    if ! update_script >/dev/null 2>&1; then        log_info "GitHub update failed, using cached version"    fi    
# Execute cached script with proper error handling    if [ -f "\$CACHE_FILE" ] && [ -x "\$CACHE_FILE" ]; then        log_info "Executing cached script (type: $script_type)"                
# Execute with timeout and error handling (CheckMK pattern)        if timeout 30 "\$CACHE_FILE" 2>/dev/null; then            log_info "Script executed successfully"        else            local exit_code=\$?            report_error "Script execution failed with exit code \$exit_code"                        
# CheckMK standard: still try to provide some output            if [ "\$SCRIPT_TYPE" = "local" ]; then                
echo "2 \$SCRIPT_NAME - CRITICAL: Script execution failed"            fi        fi    else        
# No cached script available - report error in CheckMK format        if [ "\$SCRIPT_TYPE" = "local" ]; then            
echo "2 \$SCRIPT_NAME - CRITICAL: No script available (GitHub unreachable, no cache)"        fi        report_error "No cached script available"        exit 2    fi}
# Execute main functionmain "\$@"EOF        chmod +x "$wrapper_file"        
# Aggiungi metadata al wrapper appena creato    add_version_metadata "$wrapper_file" "1.0.0"        log "Ô£à Wrapper $script_name creato in $target_dir"}
# =====================================================
# FUNZIONI DI MONITORING (pattern CheckMK)
# =====================================================check_plugin_health() {    local plugin_dir="$1"    local plugin_type="$2"        log "­ƒöì Checking $plugin_type plugins in $plugin_dir..."        if [ ! -d "$plugin_dir" ]; then        log "ÔÜá´©Å  Directory $plugin_dir non esiste"        return 1    fi        local count=0    local working=0    local errors=0        for script in "$plugin_dir"/*; do        [ -f "$script" ] || continue        count=$((count + 1))                if [ -x "$script" ]; then            
# Test execution (timeout 5s)            if timeout 5 "$script" >/dev/null 2>&1; then                working=$((working + 1))            else                errors=$((errors + 1))                log "ÔØî $script failed execution test"            fi        else            errors=$((errors + 1))            log "ÔØî $script not executable"        fi    done        log "­ƒôè $plugin_type: $count total, $working working, $errors errors"    return $errors}create_deployment_status() {    local status_file="$CACHE_DIR/deployment_status.json"        cat > "$status_file" << EOF{    "deployment_date": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",    "environment": "$ENV_TYPE",    "cache_dir": "$CACHE_DIR",    "scripts_deployed": $(
echo "${!SCRIPTS[@]}" | wc -w),    "directories": {        "local": "$CHECKMK_LOCAL_DIR",        "plugins": "$CHECKMK_PLUGIN_DIR",        "spool": "$CHECKMK_SPOOL_DIR",        "notifications": "$CHECKMK_NOTIFICATION_DIR"    }}EOF        log "­ƒôï Status saved to $status_file"}
# =====================================================
# SETUP INIZIALE
# =====================================================log "­ƒÜÇ CheckMK Smart Deploy - Sistema Ibrido"log "­ƒÅù´©Å  Environment: $ENV_TYPE"log "­ƒôü Cache: $CACHE_DIR"
# Verifica permessi baseif [ ! -w "/usr/lib/check_mk_agent" ] 2>/dev/null; then    log "ÔØî Errore: Non hai permessi di scrittura su /usr/lib/check_mk_agent"    log "­ƒÆí Esegui come root o con sudo"    exit 1fi
# Crea directory cachemkdir -p "$CACHE_DIR"log "­ƒôé Cache directory: $CACHE_DIR"
# =====================================================
# DEPLOY SCRIPTS
# =====================================================log "­ƒôÑ Deploying scripts..."for script_entry in "${!SCRIPTS[@]}"; do    
# Parse entry: "path:type"    
IFS=':' read -r github_path script_type <<< "${SCRIPTS[$script_entry]}"        log "­ƒöä Processing $script_entry (type: $script_type)..."        
# Download iniziale per popolare la cache    cache_file="$CACHE_DIR/${script_entry}.sh"    if curl -s --max-time 10 --fail "$BASE_URL/$github_path" -o "$cache_file"; then        chmod +x "$cache_file"        log "Ô£à Cache iniziale per $script_entry creata"    else        log "ÔÜá´©Å  Warning: Impossibile scaricare $script_entry (continuo comunque)"    fi        
# Crea wrapper smart    create_smart_wrapper "$script_entry" "$github_path" "$script_type"done
# =====================================================
# POST-DEPLOYMENT: STATUS E MAINTENANCE
# =====================================================log "­ƒöº Creando script di manutenzione..."cat > "$CACHE_DIR/update-all.sh" << 'EOF'
#!/bin/bash
# Aggiorna manualmente tutti gli script CheckMK
# Pattern basato su CheckMK ufficiale
CACHE_DIR="${CACHE_DIR:-/var/cache/checkmk-scripts}"
GITHUB_REPO="Coverup20/checkmk-tools"
BASE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main"cd "$CACHE_DIR" 2>/dev/null || exit 1
echo "­ƒöä Manual update of all CheckMK scripts..."
echo "­ƒôí Repository: $GITHUB_REPO"declare -A 
SCRIPTS=(    ["check_cockpit_sessions"]="script-check-ns7/check_cockpit_sessions.sh"    ["check_dovecot_status"]="script-check-ns7/check_dovecot_status.sh"    ["check_ssh_root_sessions"]="script-check-ns7/check_ssh_root_sessions.sh"    ["check_postfix_status"]="script-check-ns7/check_postfix_status.sh"    ["telegram_realip"]="script-notify-checkmk/telegram_realip")for script_name in "${!SCRIPTS[@]}"; do    github_path="${SCRIPTS[$script_name]}"    cache_file="${script_name}.sh"        
echo "Ô¼¼ Updating $script_name..."        if curl -s --max-time 10 --fail "$BASE_URL/$github_path" -o "$cache_file.tmp"; then        if head -n 1 "$cache_file.tmp" | grep -q "^
#!/.*bash"; then            mv "$cache_file.tmp" "$cache_file"            chmod +x "$cache_file"            
echo "Ô£à $script_name updated"        else            rm -f "$cache_file.tmp"            
echo "ÔØî $script_name invalid format"        fi    else        rm -f "$cache_file.tmp" 2>/dev/null        
echo "ÔØî $script_name download failed"    fidone
echo "­ƒÅü Update completed"EOFchmod +x "$CACHE_DIR/update-all.sh"
# Crea script di status checkcat > "$CACHE_DIR/check-status.sh" << 'EOF'
#!/bin/bash
# CheckMK Scripts Status Check
# Pattern basato su architettura ufficiale CheckMK
echo "­ƒôè CheckMK Scripts Health Status"
echo "=================================="
# Check directoriesfor dir in "/usr/lib/check_mk_agent/local" "/usr/lib/check_mk_agent/plugins" "/usr/lib/check_mk_agent/spool"; do    if [ -d "$dir" ]; then        count=$(find "$dir" -maxdepth 1 -type f -executable | wc -l)        
echo "­ƒôü $dir: $count scripts"    else        
echo "ÔØî $dir: not found"    fidone
# Check cacheif [ -d "${CACHE_DIR:-/var/cache/checkmk-scripts}" ]; then    cache_count=$(find "${CACHE_DIR:-/var/cache/checkmk-scripts}" -name "*.sh" | wc -l)    
echo "­ƒÆ¥ Cache: $cache_count files"else    
echo "ÔØî Cache directory not found"fi
# Check recent activity
echo ""
echo "­ƒôà Recent Activity:"find "/usr/lib/check_mk_agent" -name "*" -type f -mtime -1 2>/dev/null | head -5 | while read -r file; do    
echo "   $(stat -c '%y %n' "$file" 2>/dev/null)"doneEOFchmod +x "$CACHE_DIR/check-status.sh"
# =====================================================
# FINAL STATUS CHECK
# =====================================================log "­ƒÅü Deployment completato!"log ""log "­ƒôï SUMMARY:"log "   ­ƒÅù´©Å  Environment: $ENV_TYPE"log "   ­ƒôª Scripts deployed: $(
echo "${!SCRIPTS[@]}" | wc -w)"log "   ­ƒôü Cache directory: $CACHE_DIR"log ""log "­ƒöº Maintenance scripts created:"log "   ­ƒô£ Update all: $CACHE_DIR/update-all.sh"log "   ­ƒôè Status check: $CACHE_DIR/check-status.sh"log ""
# Health check finalecheck_plugin_health "$CHECKMK_LOCAL_DIR" "local"check_plugin_health "$CHECKMK_PLUGIN_DIR" "plugins"
# Crea deployment status JSONcreate_deployment_statuslog ""log "Ô£à Setup completed successfully!"log "­ƒÆí Run '$CACHE_DIR/check-status.sh' to verify status"log "­ƒöä Run '$CACHE_DIR/update-all.sh' to manually update all scripts"
echo "­ƒöä Aggiornamento manuale script CheckMK..."for info_file in *.info; do    [ -f "$info_file" ] || continue    script_name=$(basename "$info_file" .info)    
echo "­ƒôÑ Aggiornando $script_name..."        
# Forza update eseguendo il wrapper    if /usr/lib/check_mk_agent/local/"$script_name" >/dev/null 2>&1; then        
echo "Ô£à $script_name aggiornato"    else        
echo "ÔÜá´©Å  $script_name: problema nell'aggiornamento"    fidone
echo "­ƒÄë Aggiornamento completato!"EOFchmod +x "$CACHE_DIR/update-all.sh"
# =====================================================
# RIEPILOGO
# =====================================================log "­ƒÄë Deploy completato!"log ""log "­ƒôè RIEPILOGO:"log "   ÔÇó Environment: $ENV_TYPE"log "   ÔÇó Script deployati: ${
#SCRIPTS[@]}"log "   ÔÇó Cache directory: $CACHE_DIR"log "   ÔÇó Directories usate:"log "     - Local checks: $CHECKMK_LOCAL_DIR"if [ "$ENV_TYPE" = "OMD Server" ]; then    log "     - Notifications: $CHECKMK_NOTIFICATION_DIR"filog ""log "­ƒÆí FUNZIONAMENTO:"log "   ÔÇó Gli script si auto-aggiornano da GitHub ad ogni esecuzione"log "   ÔÇó In caso di problemi di rete, usano la cache locale"log "   ÔÇó Aggiornamento manuale: $CACHE_DIR/update-all.sh"log ""log "­ƒº¬ TEST:"log "   ls -la $CHECKMK_LOCAL_DIR/"if [ -f "$CHECKMK_LOCAL_DIR/check_cockpit_sessions" ]; then    log "   $CHECKMK_LOCAL_DIR/check_cockpit_sessions"filog "   
DEBUG=1 $CHECKMK_LOCAL_DIR/check_cockpit_sessions  
# debug mode"
