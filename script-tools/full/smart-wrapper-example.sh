#!/usr/bin/env bash
# Smart CheckMK Script Wrapper - ESEMPIO (fixed)
# Esempio didattico di wrapper ibrido (auto-update + cache)

set -euo pipefail

SCRIPT_NAME="check_cockpit_sessions"
SCRIPT_TYPE="local"
GITHUB_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ns7/check_cockpit_sessions.sh"
TIMEOUT_SECONDS=5
EXEC_TIMEOUT_SECONDS=30
DEBUG=${DEBUG:-0}

log_debug() {
    [[ "$DEBUG" == "1" ]] && echo "# Wrapper[$SCRIPT_NAME] $*" >&2 || true
}

download_to() {
    local url="$1" out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time "$TIMEOUT_SECONDS" "$url" -o "$out"
        return
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -T "$TIMEOUT_SECONDS" -O "$out" "$url"
        return
    fi
    return 1
}

detect_env() {
    if [[ -d /omd/sites ]]; then
        local site
        site="$(ls /omd/sites 2>/dev/null | head -n1)"
        echo "/omd/sites/${site:-monitoring}"
    else
        echo ""
    fi
}

main() {
    local omd_root
    omd_root="$(detect_env)"
    local cache_dir
    if [[ -n "$omd_root" ]]; then
        cache_dir="$omd_root/var/cache/checkmk-scripts"
    else
        cache_dir="/var/cache/checkmk-scripts"
    fi
    local cache_file="$cache_dir/${SCRIPT_NAME}.sh"
    mkdir -p "$cache_dir" 2>/dev/null || true

    local tmp="$cache_file.tmp"
    if download_to "$GITHUB_URL" "$tmp" 2>/dev/null; then
        if head -n 1 "$tmp" | grep -qE '^#!/.*bash'; then
            mv -f "$tmp" "$cache_file"
            chmod +x "$cache_file"
            log_debug "Updated cache from GitHub"
        else
            rm -f "$tmp" 2>/dev/null || true
            log_debug "Downloaded file invalid"
        fi
    else
        rm -f "$tmp" 2>/dev/null || true
        log_debug "Download failed"
    fi

    if [[ -x "$cache_file" ]]; then
        log_debug "Executing cached script"
        if command -v timeout >/dev/null 2>&1; then
            timeout "$EXEC_TIMEOUT_SECONDS" "$cache_file" "$@"
        else
            "$cache_file" "$@"
        fi
        exit $?
    fi

    echo "2 ${SCRIPT_NAME} - CRITICAL: No script available (cache miss, GitHub unreachable)"
    exit 2
}

main "$@"

: <<'__CORRUPTED_ORIGINAL_CONTENT__'
# NON usare direttamente - usa smart-deploy-hybrid.sh per l'installazione
#
# Logica: Prova a scaricare la versione fresca, usa cache locale come fallback
# Gestisce automaticamente i path CheckMK corretti
# =====================================================
# CONFIGURAZIONE
# =====================================================
SCRIPT_NAME="check_cockpit_sessions"
SCRIPT_TYPE="local"  
# local, spool, plugin, notification
GITHUB_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ns7/check_cockpit_sessions.sh"
TIMEOUT=5
# =====================================================
# CONFIGURAZIONE PATH CHECKMK
# =====================================================
# Auto-detection del tipo di environment CheckMK
if [ -d "/omd/sites" ]; then    
# Ambiente CheckMK Server (OMD)    
SITE_NAME=$(ls /omd/sites/ 2>/dev/null | head -n1)    
OMD_ROOT="/omd/sites/${SITE_NAME:-monitoring}"        case "$SCRIPT_TYPE" in        "local")        
TARGET_DIR="/usr/lib/check_mk_agent/local" ;;        "spool")        
TARGET_DIR="/usr/lib/check_mk_agent/spool" ;;        "plugin")       
TARGET_DIR="/usr/lib/check_mk_agent/plugins" ;;        "notification") 
TARGET_DIR="$OMD_ROOT/local/share/check_mk/notifications" ;;        "bin")          
TARGET_DIR="$OMD_ROOT/local/bin" ;;        *)              
TARGET_DIR="/usr/lib/check_mk_agent/local" ;;    esac    
CACHE_DIR="$OMD_ROOT/var/cache/checkmk-scripts"
else    
# Ambiente CheckMK Agent (client)    case "$SCRIPT_TYPE" in        "local")        
TARGET_DIR="/usr/lib/check_mk_agent/local" ;;        "spool")        
TARGET_DIR="/usr/lib/check_mk_agent/spool" ;;        "plugin")       
TARGET_DIR="/usr/lib/check_mk_agent/plugins" ;;        *)              
TARGET_DIR="/usr/lib/check_mk_agent/local" ;;    esac    
CACHE_DIR="/var/cache/checkmk-scripts"
fi CACHE_FILE="$CACHE_DIR/$SCRIPT_NAME.sh"
# =====================================================
# SETUP CACHE DIRECTORY
# =====================================================mkdir -p "$CACHE_DIR" 2>/dev/null || true
# =====================================================
# FUNZIONE DI UPDATE
# =====================================================update_script() {    local temp_file="$CACHE_FILE.tmp"        
# Prova download con timeout    if curl -s --max-time "$TIMEOUT" --fail "$GITHUB_URL" -o "$temp_file" 2>/dev/null; then        
# Verifica che il file sia vali
do (contiene shebang bash)        if head -n 1 "$temp_file" | grep -q "^
#!/.*bash"; then            mv "$temp_file" "$CACHE_FILE"            chmod +x "$CACHE_FILE"            
echo "
# Script updated from GitHub $(date)" > "$CACHE_FILE.info"            return 0        else            rm -f "$temp_file"            return 1        fi
else        rm -f "$temp_file" 2>/dev/null        return 1    fi}
# =====================================================
# LOGICA PRINCIPALE
# =====================================================
# Verifica environment CheckMKlog_info() {    
# Log solo se DEBUG ├¿ abilitato    [ "${DEBUG:-0}" = "1" ] && 
echo "
# CheckMK Wrapper [$SCRIPT_NAME]: $1" >&2}log_info "Environment: $([ -d "/omd/sites" ] && 
echo "OMD Server" || 
echo "Agent Client")"log_info "Script Type: $SCRIPT_TYPE"log_info "Target Dir: $TARGET_DIR" log_info "Cache Dir: $CACHE_DIR"
# Prova aggiornamento (silenzioso)update_script >/dev/null 2>&1
# Esegui script cached
if [ -f "$CACHE_FILE" ] && [ -x "$CACHE_FILE" ]; then    log_info "Executing cached script"    "$CACHE_FILE"
else    
# Fallback: nessun script disponibile    
echo "2 ${SCRIPT_NAME} - CRITICAL: No script available (cache miss, GitHub unreachable)"    log_info "CRITICAL: No cached script available"
    exit 2
fi 

__CORRUPTED_ORIGINAL_CONTENT__